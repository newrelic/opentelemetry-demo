##############################
## Threshold Alerts 
##

## Errors
resource "newrelic_nrql_alert_condition" "checkout_error_rate_threshold" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "static"
  name = "Checkout Service Error Rate Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.error.count['count']) / count(apm.service.transaction.duration) FROM Metric WHERE service.name = '${var.checkout_service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 0.3
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.specific_service_title_template
}

## Latency
resource "newrelic_nrql_alert_condition" "checkout_latency_threshold" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "static"
  name = "Checkout Service Latency Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentile(apm.service.transaction.duration, 95) FROM Metric WHERE service.name = '${var.checkout_service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 75
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.specific_service_title_template
}

## Throughput - Increased aggregation window and delay to 2 min each to account for lower volume and allow for more accurate alerting
resource "newrelic_nrql_alert_condition" "checkout_throughput_below_threshold" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "static"
  name = "Checkout Service Throughput Below Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.transaction.duration['count']) FROM Metric WHERE service.name = '${var.checkout_service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "below"
    threshold = 1
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "none"
  aggregation_window = 120
  aggregation_method = "event_flow"
  aggregation_delay = 120
  title_template = local.specific_service_title_template
}

resource "newrelic_nrql_alert_condition" "checkout_throughput_above_threshold" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "static"
  name = "Checkout Service Throughput Above Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.transaction.duration['count']) FROM Metric WHERE service.name = '${var.checkout_service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 30
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "none"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.specific_service_title_template
}


resource "newrelic_entity_tags" "tag_checkout_error_rate_threshold" {
  guid = newrelic_nrql_alert_condition.checkout_error_rate_threshold.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}

resource "newrelic_entity_tags" "tag_checkout_latency_threshold" {
  guid = newrelic_nrql_alert_condition.checkout_latency_threshold.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}

resource "newrelic_entity_tags" "tag_checkout_throughput_below_threshold" {
  guid = newrelic_nrql_alert_condition.checkout_throughput_below_threshold.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}

resource "newrelic_entity_tags" "tag_checkout_throughput_above_threshold" {
  guid = newrelic_nrql_alert_condition.checkout_throughput_above_threshold.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}
