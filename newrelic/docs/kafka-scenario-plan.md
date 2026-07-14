# Kafka Scenario — Implementation Plan

Tracking: [ENTERPRISE-31017](https://new-relic.atlassian.net/browse/ENTERPRISE-31017)

> **Branch note:** This work lives on its own `kafka-scenario` branch, based on `main`.
> It is self-contained — everything the scenario needs is (or will be) built on this branch.

## What the scenario does

Driven by the `kafkaQueueProblems` feature flag in [src/flagd/demo.flagd.json](../../src/flagd/demo.flagd.json) (lines 67–75): "Overloads Kafka queue while simultaneously introducing a consumer side delay leading to a lag spike."

The flag is an **integer** flag, not a boolean: `on: 100`, `off: 0`. The `on` value (100) is read directly as the number of extra producer goroutines to spawn, so the overload magnitude is data-driven off the flag value.

- **Producer side** — `checkout` service ([src/checkout/main.go:664-674](../../src/checkout/main.go#L664-L674)): when the flag value > 0, after a real checkout it fires off that many (`ffValue`, i.e. 100) extra goroutines publishing duplicate `orders` messages to overload the topic.
- **Slow consumer** — `fraud-detection` (Kotlin, [src/fraud-detection/src/main/kotlin/frauddetection/main.kt:60-63](../../src/fraud-detection/src/main/kotlin/frauddetection/main.kt#L60-L63)): adds `Thread.sleep(1000)` per record, so the consumer drains far slower than the producer fills.
- **Comparison consumer** — `accounting` ([src/accounting/Consumer.cs](../../src/accounting/Consumer.cs)) reads the same topic but isn't slowed. Useful as a baseline consumer group.
- **Net effect** — consumer lag spike on the `orders` topic for the fraud-detection group, slow processing, and producer-side bursts visible in messaging spans.

## Deployment surfaces — IMPORTANT

This scenario must work across **three** deployment paths, each with a **different collector
configuration**. The original plan only considered the first; the MARS Gamedays run on the k8s
path via Instruqt. Any "enable broker metrics" work must cover all three (or explicitly defer some):

| # | Path | Deployed by | Collector config | Telemetry flow |
|---|------|-------------|------------------|----------------|
| A | Upstream Docker Compose | `docker compose up` at repo root | [src/otel-collector/otelcol-config-extras.yml](../../src/otel-collector/otelcol-config-extras.yml) (merged into `otelcol-config.yml`) | demo collector → Prometheus/Jaeger/OpenSearch — **not New Relic** |
| B | **nr-otel-cli → Docker** | `nr-otel-cli install docker` | [newrelic/docker/config/otel-config-docker.yaml](../docker/config/otel-config-docker.yaml) (single `--config`, no extras merge) | demo collector → `otlphttp/newrelic` |
| C | **nr-otel-cli → K8s** (MARS/Instruqt) | `nr-otel-cli install k8s` (Helm) | [newrelic/k8s/helm/nr-k8s-otel-collector.yaml](../k8s/helm/nr-k8s-otel-collector.yaml) — **the demo's own collector is `enabled: false`** ([opentelemetry-demo.yaml](../k8s/helm/opentelemetry-demo.yaml)) | demo services push OTLP → `nr-k8s-otel-collector` → New Relic |

**Generator relationship — don't hand-edit upstream files.** The Path B compose
[newrelic/docker/docker-compose.yml](../docker/docker-compose.yml) is **generated** from the
pristine root `docker-compose.yml` by [newrelic/scripts/update-docker.sh](../scripts/update-docker.sh)
(`cp` + `yq` edits: strips the bundled backends, repoints the collector to
`otel-config-docker.yaml`, appends NR env vars). Colleagues never modify the upstream
`docker-compose.yml` / `otelcol-config*.yml` so upstream stays pull-clean. Therefore Kafka wiring for
Path B lives in **two** NR-owned places, not the upstream files:
- the receiver → hand-maintained [otel-config-docker.yaml](../docker/config/otel-config-docker.yaml);
- the collector's `KAFKA_ADDR` env → an `environment +=` line in `update-docker.sh` (so it survives
  regeneration), mirrored into the committed generated compose.

Path A only sends to Prometheus/Jaeger/OpenSearch (never New Relic), so it is **not** used for the NR
scenario and is intentionally left pristine.

**Key architectural gotcha for path C (k8s):** the `nr-k8s-otel-collector` is **push-only** — its
metrics pipelines have an `otlp` receiver and nothing that scrapes. Broker-side Kafka metrics
(`kafka.consumer_group.lag`) can't be *pushed* by the demo services; they must be *scraped* from the
broker. So path C needs a `kafkametrics` **scraping** receiver added to that chart's config, with
in-cluster network reach to the `kafka` service. This is genuine design work, not a config mirror of
the Docker path.

## Current New Relic coverage in this repo

- **Path A (upstream compose):** intentionally **left pristine** — it doesn't send to New Relic, so it's not part of the NR scenario. (An earlier attempt edited it directly; reverted in favour of the NR-native approach below.)
- **Path B (nr-docker):** `kafkametrics` receiver **added** to [otel-config-docker.yaml](../docker/config/otel-config-docker.yaml) and into the metrics pipeline; `KAFKA_ADDR` wired via [update-docker.sh](../scripts/update-docker.sh) + the committed generated compose. Verified structurally (YAML + receiver fields vs v0.142.0 contrib README). Live validation: see #6.
- **Path C (nr-k8s):** no `kafkametrics` receiver yet; needs the scraping-receiver design above.
- No Kafka/messaging alerts in [newrelic/terraform/nr_resources/metric_alerts.tf](../terraform/nr_resources/metric_alerts.tf).
- No Kafka SLOs in [newrelic/terraform/nr_resources/slos.tf](../terraform/nr_resources/slos.tf).
- No Kafka tile in [newrelic/dashboards/service_baselines.json](../dashboards/service_baselines.json).

The demo emits Kafka producer/consumer **spans** (checkout, fraud-detection, accounting
auto-instrumentation) on all paths, but **not** broker-side metrics like consumer lag until the
receiver above is enabled per path.

> **Metric-name caveat for #2/#3/#4:** dashboards, alerts, and SLOs query New Relic and are largely
> deployment-agnostic — *provided* the metric/attribute names arrive identically on all paths.
> Different collectors attach different resource attributes (e.g. k8s adds `k8s.*`), so the exact
> facets must be confirmed against live data from each path before the queries are trusted.

## Proposed subtasks (replanned for the 3 deployment surfaces)

Broker-metrics work is now split by deployment path, because each is a separate config and the k8s
path is a separate design. Jira mapping and sprint disposition are in the table at the bottom.

1. **Enable Kafka broker metrics — Path A (upstream Docker Compose)** — *DONE this sprint*
   `kafkametrics` receiver in [src/otel-collector/otelcol-config-extras.yml](../../src/otel-collector/otelcol-config-extras.yml); `KAFKA_ADDR` + `depends_on: kafka` wired in `docker-compose.yml`. Verified structurally; live-scrape confirmation folded into #6.

1b. **Enable Kafka broker metrics — Path B (nr-otel-cli Docker)**
   Add the `kafkametrics` receiver to [newrelic/docker/config/otel-config-docker.yaml](../docker/config/otel-config-docker.yaml) (single-config, no merge) and ensure `KAFKA_ADDR` reaches that collector. Validate with `nr-otel-cli install docker` + Rancher.

1c. **Enable Kafka broker metrics — Path C (nr-otel-cli K8s / Instruqt)**
   Add a `kafkametrics` **scraping** receiver + metrics pipeline to [newrelic/k8s/helm/nr-k8s-otel-collector.yaml](../k8s/helm/nr-k8s-otel-collector.yaml), with in-cluster reach to the `kafka` service. This is the MARS Gameday path and the one that matters most. Design work, not a mirror. Validate on k3s (Rancher) via `nr-otel-cli install k8s`.

2. **Add a Kafka section to the service-baselines dashboard**
   Producer rate (checkout), consumer rate and lag (fraud-detection vs accounting groups), per-topic message rate, error rate on `orders`.
   File: [newrelic/dashboards/service_baselines.json](../dashboards/service_baselines.json). Depends on ≥1 path emitting metrics; confirm facet names per path (see metric-name caveat).

3. **Add Kafka alerts in terraform**
   - Consumer-lag threshold alert for `fraud-detection` on `orders`.
   - (Optional) Producer-rate-spike alert on `checkout`.
   File: [newrelic/terraform/nr_resources/metric_alerts.tf](../terraform/nr_resources/metric_alerts.tf). Depends on #1x + ideally #2.

4. **(Optional) Kafka SLO**
   e.g. "fraud-detection consumer lag ≤ N for X% of the period."
   File: [newrelic/terraform/nr_resources/slos.tf](../terraform/nr_resources/slos.tf). Depends on #1x.

5. **Document the scenario**
   In [newrelic/README.md](../README.md): enabling `kafkaQueueProblems`, what to look for in NR, expected behaviour, recovery — **per deployment path**.

6. **Validate end-to-end (per path)**
   Enable the flag, confirm the dashboard shows the fraud-detection lag spike (accounting keeps up), confirm the alert fires, disable and confirm recovery — on each path that's in scope.

7. **Instruqt / MARS Gameday integration** *(new — was missing from the original breakdown)*
   Incorporate the scenario into the Instruqt track used for MARS Gamedays: track setup/steps, participant instructions, enabling the flag within the Gameday flow, and any ancillary Gameday docs/material. Depends on Path C (#1c) working on k8s. This is its own workstream with its own supporting content.

## Sprint disposition & Jira mapping

Today is the last day of Sprint 3. Delivered / proposed split:

| Plan item | Jira | Sprint 3 (today) | Sprint 4 (ENTERPRISE-31828) |
|-----------|------|------------------|------------------------------|
| #1 Path A broker metrics | ENTERPRISE-31101 | reverted (not NR path) | — |
| #1b Path B (nr-docker) | ENTERPRISE-31101 | ✅ config done; live-validating | — |
| #1c Path C (nr-k8s/Instruqt) | *new subtask under 31828* | — | yes (design + cluster validation) |
| #2 Dashboard | ENTERPRISE-31102 | stretch | likely |
| #3 Alerts | ENTERPRISE-31105 | — | yes |
| #4 SLO (optional) | ENTERPRISE-31103 | — | yes |
| #5 Docs (per path) | ENTERPRISE-31106 | — | yes |
| #6 Validate (per path) | ENTERPRISE-31104 | Path A partial | yes |
| #7 Instruqt/Gameday | *new subtask under 31828* | — | yes |

**Continuation story:** [ENTERPRISE-31828](https://new-relic.atlassian.net/browse/ENTERPRISE-31828) — *Kafka Scenario - Continued*. New subtasks needed there: Path B metrics, Path C (k8s) metrics, and Instruqt/Gameday integration, plus whichever of #2–#6 don't land today.

## Suggested order

Path A (done) → **Path C (#1c)** is the priority since Gamedays run on k8s → Path B (#1b) for local NR-docker parity → #2 visualise → #3 alert → #4 SLO → #5 docs → #6 validate per path → #7 Instruqt integration.
