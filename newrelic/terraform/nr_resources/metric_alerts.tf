## Metric Alert Policy
resource "newrelic_alert_policy" "metric_alert_policy" {
  name                = "Astronomy Service Metric Health"
  incident_preference = "PER_CONDITION_AND_TARGET"
}


##############################
## Metric Threshold Alerts 
##

## Errors
resource "newrelic_nrql_alert_condition" "service_error_rate" {
  for_each   = var.metric_alert_map
  account_id = var.newrelic_account_id
  policy_id  = newrelic_alert_policy.metric_alert_policy.id

  type                         = "static"
  name                         = "${each.value.service_title_name} Error Rate"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT (sum(apm.service.error.count['count']) / count(apm.service.transaction.duration)) * 100 FROM Metric WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "above"
    threshold             = each.value.error_rate_threshold
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "at_least_once"
  }
  fill_option        = "none"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

## Latency
resource "newrelic_nrql_alert_condition" "service_latency" {
  for_each                     = var.metric_alert_map
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.metric_alert_policy.id
  type                         = "static"
  name                         = "${each.value.service_title_name} Latency"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT percentile(convert(apm.service.transaction.duration, unit, 'ms'), 95) FROM Metric WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "above"
    threshold             = each.value.latency_threshold
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "at_least_once"
  }
  fill_option        = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

## Low Throughput
resource "newrelic_nrql_alert_condition" "service_low_throughput" {
  for_each                     = var.metric_alert_map
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.metric_alert_policy.id
  type                         = "static"
  name                         = "${each.value.service_title_name} Low Throughput"
  enabled                      = var.low_throughput_alert_enabled
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT sum(apm.service.transaction.duration['count']) FROM Metric WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "below"
    threshold             = each.value.throughput_lower_threshold
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "at_least_once"
  }
  fill_option        = "none"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

## High Throughput
resource "newrelic_nrql_alert_condition" "service_high_throughput" {
  for_each                     = var.metric_alert_map
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.metric_alert_policy.id
  type                         = "static"
  name                         = "${each.value.service_title_name} High Throughput"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT sum(apm.service.transaction.duration['count']) FROM Metric WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "above"
    threshold             = each.value.throughput_upper_threshold
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "at_least_once"
  }
  fill_option        = "none"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

##############################
## Kafka scenario alerts (ENTERPRISE-31843)
##
## Broker-side alerts for the kafkaQueueProblems scenario. Requires the
## kafkametrics/kafka_metrics receiver (ENTERPRISE-31101 Docker, ENTERPRISE-31847 k8s)
## so kafka.consumer_group.lag and kafka.partition.current_offset are collected.
##
## Thresholds come from live validation on k3s: fraud-detection lag sits at 0 at
## rest and spikes to ~1000-1500 under the scenario, so a threshold well above 0
## (default 100, sustained) cleanly separates scenario from baseline without noise.
##
## Consumer-lag alert (the cause-level signal): fraud-detection lags on the orders
## topic because it consumes 1s/record while checkout floods the topic.
resource "newrelic_nrql_alert_condition" "kafka_consumer_lag" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.metric_alert_policy.id
  type                         = "static"
  name                         = "Kafka Consumer Lag (fraud-detection / orders)"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT latest(kafka.consumer_group.lag) FROM Metric WHERE topic = 'orders' AND `group` = 'fraud-detection' FACET `group`, topic"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "above"
    threshold             = var.kafka_consumer_lag_threshold
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "at_least_once"
  }
  fill_option        = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

## Producer-rate-spike alert: checkout floods the orders topic when the flag is on.
## current_offset is a monotonic gauge, so the production rate is its derivative;
## baseline is a few msgs/min, the scenario bursts ~100 messages per checkout.
resource "newrelic_nrql_alert_condition" "kafka_producer_rate_spike" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.metric_alert_policy.id
  type                         = "static"
  name                         = "Kafka Producer Rate Spike (orders topic)"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT derivative(kafka.partition.current_offset, 1 minute) FROM Metric WHERE topic = 'orders' FACET topic"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "above"
    threshold             = var.kafka_producer_rate_threshold
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "at_least_once"
  }
  fill_option        = "none"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

##
## Tags for Metric Alert Conditions
##

resource "newrelic_entity_tags" "tag_metric_service_error_rate" {
  for_each = var.metric_alert_map
  guid     = newrelic_nrql_alert_condition.service_error_rate[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
  tag {
    key    = "golden-signal"
    values = ["errors"]
  }
}

resource "newrelic_entity_tags" "tag_metric_service_latency" {
  for_each = var.metric_alert_map
  guid     = newrelic_nrql_alert_condition.service_latency[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
  tag {
    key    = "golden-signal"
    values = ["latency"]
  }
}

resource "newrelic_entity_tags" "tag_metric_service_low_throughput" {
  for_each = var.metric_alert_map
  guid     = newrelic_nrql_alert_condition.service_low_throughput[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
  tag {
    key    = "golden-signal"
    values = ["throughput"]
  }
}

resource "newrelic_entity_tags" "tag_metric_service_high_throughput" {
  for_each = var.metric_alert_map
  guid     = newrelic_nrql_alert_condition.service_high_throughput[each.key].entity_guid


  tag {
    key    = "data-type"
    values = ["metric"]
  }
  tag {
    key    = "golden-signal"
    values = ["throughput"]
  }
}