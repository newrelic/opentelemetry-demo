# Kafka Dead Consumer Group (`kafkaConsumerDead`)

Removes a consumer from the `orders` group entirely while the producer keeps running, so the group empties (`members` → 0) and lag climbs against a zero-member group. This is the "consumer is _gone_" scenario, distinct from `kafkaQueueProblems` (consumer is _falling behind_): same topic and group, different root cause.

- **Producer** — `checkout` keeps publishing to the `orders` topic at its normal rate; no burst is needed. Every message it produces increases lag while the group has no members.
- **Departed consumer** — when the flag is on, `fraud-detection` calls `consumer.unsubscribe()` and stops polling, so it leaves the group. The broker reports the group `Empty` (`kafka.consumer_group.members` = 0), but its committed offsets persist, so `kafka.consumer_group.lag` stays computable and climbs.
- **Baseline consumer** — `accounting` keeps reading the topic, so its group stays at `members` = 1 with flat lag. It is the control that shows the broker and topic are healthy and the problem is specific to `fraud-detection`.

`kafkaConsumerDead` is a **boolean** flag: `on = true`, `off = false`. Because `fraud-detection` re-`subscribe()`s when the flag goes back to `off`, the whole scenario is reversible with a single flag toggle.

This is the demo counterpart to the SRE Agent's `detect_consumer_liveness` detector, which fires **critical** on `members == 0 AND lag_present`. Keeping the producer running is what supplies the `lag_present` half — a zero-member group with no lag reads as merely idle/deprovisioned, not dead.

## Enable

1. Open the Flagd UI (see [Accessing the Flagd UI](../../README.md#accessing-the-flagd-ui)) and set **`kafkaConsumerDead`** to **`on`**.
2. Generate checkout traffic so orders keep flowing — either let the load generator run, or place orders through the web store. Lag builds as soon as `fraud-detection` leaves the group.

> **Note (Kubernetes):** `fraud-detection` reads the flag on each poll loop, so it picks up the toggle without a restart. `checkout` only needs to be producing (normal traffic is enough); no restart is required for this scenario.

## What to look for in New Relic

The same broker-side Kafka metrics collected by the `kafkametrics`/`kafka_metrics` receiver drive this scenario — here the key signal is `kafka.consumer_group.members`, faceted by `group`.

- **Dashboard** — the _Kafka — Dead Consumer Group Scenario_ section of the **Astronomy Services Baselines** dashboard: the _Consumer Group Members_ tile shows `fraud-detection` dropping from 1 to 0 while `accounting` stays at 1. The _Consumer Group Lag_ tile in the section above shows `fraud-detection` lag climbing at the same time — together they are the `members == 0 AND lag_present` signature.
- **Alert** — the **Kafka Dead Consumer Group (orders)** condition on the _Astronomy Service Metric Health_ policy opens a critical incident when any group's `members` drops below `var.kafka_dead_consumer_members_threshold` (default 1, i.e. fires at 0 members).

Quick NRQL check:

```sql
SELECT latest(kafka.consumer_group.members) FROM Metric
WHERE kafka.cluster.name = 'otel-demo-kafka' FACET `group` TIMESERIES
```

> **Note:** demo telemetry is intermittent — if `members` or `lag` reads as unavailable, widen the query window to at least 1 day.

## Recover

1. Set **`kafkaConsumerDead`** back to **`off`** in the Flagd UI.
2. `fraud-detection` re-subscribes to `orders`, rejoins the group (`members` returns to 1), and drains the backlog; lag returns to ~0 (about a minute at demo volume) and the alert incident auto-closes.
