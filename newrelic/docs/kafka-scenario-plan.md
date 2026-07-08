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

## Current New Relic coverage in this repo

On this branch there is **no Kafka-specific New Relic coverage**:

- No Kafka/messaging alerts in [newrelic/terraform/nr_resources/metric_alerts.tf](../terraform/nr_resources/metric_alerts.tf).
- No Kafka SLOs in [newrelic/terraform/nr_resources/slos.tf](../terraform/nr_resources/slos.tf).
- No Kafka tile in [newrelic/dashboards/service_baselines.json](../dashboards/service_baselines.json).
- The OTel collector ([src/otel-collector/otelcol-config.yml](../../src/otel-collector/otelcol-config.yml)) has no `kafkametrics` or `jmx` receiver, so broker-side consumer-lag metrics are not being collected today.

The demo currently emits Kafka producer/consumer **spans** (from checkout, fraud-detection, accounting auto-instrumentation) but **not** broker-side metrics like consumer lag.

## Proposed subtasks

1. **Enable Kafka broker metrics**
   Add the `kafkametrics` receiver (and/or `jmx` receiver) to [src/otel-collector/otelcol-config-extras.yml](../../src/otel-collector/otelcol-config-extras.yml) so `kafka.consumer_group.lag`, `kafka.partition.current_offset`, etc. are exported to New Relic.
   *This is the gate: without broker-side metrics, the dashboard tiles (#2), the alerts (#3), and the SLO (#4) have nothing to query.*

2. **Add a Kafka section to the service-baselines dashboard**
   Producer rate (checkout), consumer rate and lag (fraud-detection vs accounting consumer groups), per-topic message rate, error rate on the `orders` topic.
   File: [newrelic/dashboards/service_baselines.json](../dashboards/service_baselines.json).

3. **Add Kafka alerts in terraform**
   At minimum:
   - Consumer-lag threshold alert for the `fraud-detection` group on the `orders` topic.
   - (Optional) Producer-rate-spike alert on `checkout` (catches the burst when the flag flips on).
   Depends on #1 (lag metrics must be collected first), ideally after #2 (alert on what's visualised).
   File: [newrelic/terraform/nr_resources/metric_alerts.tf](../terraform/nr_resources/metric_alerts.tf).

4. **(Optional) Kafka SLO**
   e.g. "fraud-detection consumer lag ≤ N for X% of the period."
   Depends on #1.
   File: [newrelic/terraform/nr_resources/slos.tf](../terraform/nr_resources/slos.tf).

5. **Document the scenario**
   In [newrelic/README.md](../README.md): how to enable the flag in the flagd UI, what to look for in New Relic, expected dashboard/alert behaviour, how to recover.

6. **Validate end-to-end**
   Turn on `kafkaQueueProblems`, confirm the dashboard shows lag, confirm the alert fires, then disable and confirm recovery.

## Suggested order

Start with **#1** — without broker-side metrics, the dashboard tiles and alerts in #2/#3 have nothing to query. Then #2 (visualise), #3 (alert on what's visualised), #4 (formalise as SLO), #5 (docs), #6 (validate the whole chain).
