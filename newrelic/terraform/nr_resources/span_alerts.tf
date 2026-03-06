## Span Alert Policy
resource "newrelic_alert_policy" "span_alert_policy" {
  name = "Astronomy Service Span Health"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

##############################
## Anomaly Alerts
## 

# Errors
resource "newrelic_nrql_alert_condition" "span_error_rate_anomaly" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.span_alert_policy.id
  type = "baseline"
  name = "Service ErrorRate Anomaly"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentage(count(*), WHERE error = true) ${local.service_span_filter}"
    data_account_id = var.newrelic_account_id
  }

  warning {
    operator = "above"
    threshold = 3
    threshold_duration = 180
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = 120
  baseline_direction = "upper_only"
  signal_seasonality = "none"
  title_template = local.title_template
}
 
# Throughput
resource "newrelic_nrql_alert_condition" "span_throughput_anomaly" {
    account_id = var.newrelic_account_id
    policy_id = newrelic_alert_policy.span_alert_policy.id
 type = "baseline"
  name = "Service Throughput Anomaly"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT count(*) ${local.service_span_filter}"
    data_account_id = var.newrelic_account_id
  }

  warning {
    operator = "above"
    threshold = 3
    threshold_duration = 300
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = 120
  baseline_direction = "upper_and_lower"
  signal_seasonality = "none"
  title_template = local.title_template
}   

# Latency
resource "newrelic_nrql_alert_condition" "span_latency_anomaly" {
    account_id = var.newrelic_account_id
    policy_id = newrelic_alert_policy.span_alert_policy.id
 type = "baseline"
  name = "Service Latency Anomaly"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentile(duration.ms, 95) ${local.service_span_filter}"
    data_account_id = var.newrelic_account_id
  }

  warning {
    operator = "above"
    threshold = 3
    threshold_duration = 300
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = 120
  baseline_direction = "upper_and_lower"
  signal_seasonality = "none"
  title_template = local.title_template
}   

##
## Threshold Alerts - Errors
##

# Span based
resource "newrelic_nrql_alert_condition" "span_error_rate_threshold" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.span_alert_policy.id
  type = "static"
  name = "Service ErrorRate Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentage(count(*), WHERE error = true) ${local.service_span_filter}"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 0.01
    threshold_duration = 180
    threshold_occurrences = "all"
  }
  fill_option = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = 120
  title_template = local.title_template
}

resource "newrelic_entity_tags" "tag_span_error_rate_anomaly" {
  guid = newrelic_nrql_alert_condition.span_error_rate_anomaly.entity_guid

  tag {
    key    = "data-type"
    values = ["span"]
  }
}
resource "newrelic_entity_tags" "tag_span_throughput_anomaly" {
  guid = newrelic_nrql_alert_condition.span_throughput_anomaly.entity_guid

  tag {
    key    = "data-type"
    values = ["span"]
  }
}
resource "newrelic_entity_tags" "tag_span_latency_anomaly" {
  guid = newrelic_nrql_alert_condition.span_latency_anomaly.entity_guid

  tag {
    key    = "data-type"
    values = ["span"]
  }
}
resource "newrelic_entity_tags" "tag_span_error_rate_threshold" {
  guid = newrelic_nrql_alert_condition.span_error_rate_threshold.entity_guid

  tag {
    key    = "data-type"
    values = ["span"]
  }
}