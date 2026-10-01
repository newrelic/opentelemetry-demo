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

Broker-side Kafka metrics (notably `kafka.consumer_group.lag`) are collected by the `kafkametrics`/`kafka_metrics` receiver added to the collector, faceted by `group` and `topic`.

- **Dashboard** — the _Kafka_ section of the **Astronomy Services Baselines** dashboard: the _Consumer Group Lag_ tile shows `fraud-detection` climbing (to ~1000–1500+ at demo volume) while `accounting` stays flat near 0. Producer rate and consumer throughput tiles show the flood.
- **Alerts** — two conditions on the _Astronomy Service Metric Health_ policy open critical incidents:
  - **Kafka Consumer Lag (fraud-detection / orders)** — lag above `var.kafka_consumer_lag_threshold` (default 100).
  - **Kafka Producer Rate Spike (orders topic)** — production rate above `var.kafka_producer_rate_threshold` (default 60/min).
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
| Kubernetes (`nr-otel-cli install k8s`, used for Gamedays/Instruqt) | [`newrelic/k8s/helm/nr-k8s-otel-collector.yaml`](../../k8s/helm/nr-k8s-otel-collector.yaml) — receiver id `kafka_metrics` (contrib 0.153.0) |
| Docker (`nr-otel-cli install docker`) | [`newrelic/docker/config/otel-config-docker.yaml`](../../docker/config/otel-config-docker.yaml) — receiver id `kafkametrics` (contrib 0.142.0) |

The alerts and SLO are defined in [`newrelic/terraform/nr_resources`](../../terraform/nr_resources) (`metric_alerts.tf`, `slos.tf`) and apply the same on both paths.
