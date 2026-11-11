# Kafka Consumer Lag (`kafkaQueueProblems`)

Overloads the Kafka `orders` topic while slowing one consumer, producing a consumer-lag spike.

- **Producer** — `checkout` publishes to the `orders` topic. When the flag is on it fires an extra burst of duplicate messages per checkout, flooding the topic.
- **Slow consumer** — `fraud-detection` sleeps ~1s per record, so it cannot keep up with the flood and its consumer-group lag climbs.
- **Baseline consumer** — `accounting` reads the same topic without the delay, so its lag stays flat. It is the control that shows the problem is consumer-specific, not a broker outage.

`kafkaQueueProblems` is an **integer** flag: `on = 100` (the number of extra messages per checkout), `off = 0`.

## Enable

1. Open the Flagd UI (see [Accessing the Flagd UI](../../README.md#accessing-the-flagd-ui)) and set **`kafkaQueueProblems`** to **`on`**.
2. Generate checkout traffic so orders flow — either let the load generator run, or place orders through the web store. The lag builds as checkouts complete.

> **Note (Kubernetes):** the `checkout` and `fraud-detection` services read the flag at startup, so after toggling it you may need to restart them to pick up the change:
>
> ```bash
> kubectl -n opentelemetry-demo rollout restart deploy/checkout deploy/fraud-detection
> ```

## What to look for in New Relic

Broker-side Kafka metrics (notably `kafka.consumer_group.lag`) are collected by the `kafka_metrics` receiver added to the collector, faceted by `group` and `topic`.

- **Topics and broker** — both deployment paths follow the New Relic self-hosted Kafka setup.
  - The `kafka_metrics` receiver skips internal topics (names starting with `_`, such as `__consumer_offsets`), emits `kafka.topic.min_insync_replicas` and `kafka.topic.replication_factor`, and has the partition offset and replica metrics turned off. A collector filter also drops internal-topic datapoints that the broker's JMX metrics report.
  - The broker sets `broker.id` (from `KAFKA_NODE_ID`) and `kafka.cluster.name` as resource attributes, which lets New Relic create the Kafka broker entity. It loads a custom JMX rules file (from the New Relic self-hosted Kafka example) that adds the `kafka.cluster.*`, `kafka.broker.*` and `jvm.*` metrics the Kafka dashboards expect, and runs with the G1 garbage collector so the GC widgets match.
  - The collector sums the per-partition `kafka.partition.replicas_in_sync` into a per-topic `kafka.partition.replicas_in_sync.total`, which the Topics tab uses for in-sync and under-replicated counts. Cluster-wide broker metrics (`kafka.cluster.*`, offline partitions, leader election rates, fenced brokers) go through their own pipeline and are reported once per cluster, without `broker.id`.
  - For the broker's metrics, the collector also clears metric descriptions and units and removes `process.*`, `telemetry.*` and `cloud.*` resource attributes, as the docs do. These steps are New Relic specific: they cut payload size and attribute cardinality for New Relic ingest. They go against OpenTelemetry conventions, so don't copy them as general practice.
  - The Clusters tab counts every topic the broker reports, including `__consumer_offsets`, so it shows one more topic than the Topics tab.
  - `fraud-detection` also sets `kafka.cluster.name` and Kafka producer propagation, as the docs describe for Java applications. Unlike the docs, it keeps Java runtime telemetry on, so its JVM page in APM has data.
  - The cluster name is the `KAFKA_CLUSTER_NAME` environment variable (default `otel-demo-kafka`) on the collector, the broker and `fraud-detection`. Set it consistently in all three. On Kubernetes it is set in the `default.env` of [`newrelic/k8s/helm/opentelemetry-demo.yaml`](../../k8s/helm/opentelemetry-demo.yaml) (broker and `fraud-detection`) and in the `deployment.envs` of [`newrelic/k8s/helm/nr-k8s-otel-collector.yaml`](../../k8s/helm/nr-k8s-otel-collector.yaml) (collector). On Docker, set `KAFKA_CLUSTER_NAME` in the environment or `.env` file used by `docker compose`.
  - Deliberate differences from the docs: the receiver scrapes every 15s instead of 30s, the demo's shared metrics pipeline is used instead of dedicated broker pipelines, and the optional broker log forwarding is not set up because broker logs already arrive from the container output.
- **Expected empty widgets** — the demo runs a single broker with replication factor 1, so some Kafka dashboard widgets stay at 0 or empty: ISR shrink and expand, under-min-ISR, replica fetcher lag, follower fetch latency, and leader elections (`kafka.leader.election.rate` is only emitted when an election happens). The Producers tab is also empty because `checkout` is a Go service and the Kafka client dashboards only support Java clients.
- **Alerts** — two conditions on the _Astronomy Service Metric Health_ policy open critical incidents:
  - **Kafka Consumer Lag (fraud-detection / orders)** — lag above `var.kafka_consumer_lag_threshold` (default 100).
  - **Kafka Producer Rate Spike (orders topic)** — production rate (`kafka.prod.msg.count`, from the broker JMX rules) above `var.kafka_producer_rate_threshold` (default 60/min).
- **SLO** — the _fraud-detection - Kafka Consumer Lag_ service level burns error budget while lag exceeds the threshold.

Quick NRQL check:

```sql
SELECT latest(kafka.consumer_group.lag) FROM Metric
WHERE topic = 'orders' FACET `group` TIMESERIES
```

## Recover

1. Set **`kafkaQueueProblems`** back to **`off`** in the Flagd UI.
2. On Kubernetes, restart the services again so they stop producing the burst / re-read the flag:

   ```bash
   kubectl -n opentelemetry-demo rollout restart deploy/checkout deploy/fraud-detection
   ```

3. `fraud-detection` drains the backlog and lag returns to ~0 (about a minute at demo volume); the alert incidents auto-close.

## Deployment-path notes

The broker-metrics receiver lives in a different place per deployment path (they use different collectors):

| Path | Collector config |
| :--- | :--- |
| Kubernetes (`nr-otel-cli install k8s`, used for Gamedays/Instruqt) | [`newrelic/k8s/helm/nr-k8s-otel-collector.yaml`](../../k8s/helm/nr-k8s-otel-collector.yaml) — receiver id `kafka_metrics` |
| Docker (`nr-otel-cli install docker`) | [`newrelic/docker/config/otel-config-docker.yaml`](../../docker/config/otel-config-docker.yaml) — receiver id `kafka_metrics` |

Both paths apply the same settings. On Kubernetes the broker settings live on the Kafka component in [`newrelic/k8s/helm/opentelemetry-demo.yaml`](../../k8s/helm/opentelemetry-demo.yaml). On Docker they are added to the Kafka service by [`newrelic/scripts/update-docker.sh`](../../scripts/update-docker.sh), and the JMX rules file is [`newrelic/docker/config/kafka-jmx-custom-config.yaml`](../../docker/config/kafka-jmx-custom-config.yaml). Keep that file and the copy embedded in the Kubernetes values in sync.

The alerts and SLO are defined in [`newrelic/terraform/nr_resources`](../../terraform/nr_resources) (`metric_alerts.tf`, `slos.tf`) and apply the same on both paths.
