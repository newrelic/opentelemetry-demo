## Metric Alert Policy
resource "newrelic_alert_policy" "metric_alert_policy" {
  name = "Astronomy Service Metric Health"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

##############################
## Anomaly Alerts
## 

# Errors
resource "newrelic_nrql_alert_condition" "metric_error_rate_anomaly" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "baseline"
  name = "Service ErrorRate Anomaly"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.error.count['count']) / count(apm.service.transaction.duration) ${local.service_metric_filter}"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 3
    threshold_duration = 120
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = 60
  baseline_direction = "upper_only"
  signal_seasonality = "none"
  title_template = local.title_template
}

## Throughput
resource "newrelic_nrql_alert_condition" "metric_throughput_anomaly" {
    account_id = var.newrelic_account_id
    policy_id = newrelic_alert_policy.metric_alert_policy.id
    type = "baseline"
    name = "Service Throughput Anomaly"
    enabled = true
    violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.transaction.duration['count']) ${local.service_metric_filter}"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 3
    threshold_duration = 120
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = 60
  baseline_direction = "upper_and_lower"
  signal_seasonality = "none"
  title_template = local.title_template
}  

## Latency
resource "newrelic_nrql_alert_condition" "metric_latency_anomaly" {
    account_id = var.newrelic_account_id
    policy_id = newrelic_alert_policy.metric_alert_policy.id
    type = "baseline"
    name = "Service Latency Anomaly"
    enabled = true
    violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentile(apm.service.transaction.duration, 95) ${local.service_metric_filter}"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 3
    threshold_duration = 120
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = 60
  baseline_direction = "upper_and_lower"
  signal_seasonality = "none"
  title_template = local.title_template
}   

##############################
## Threshold Alerts 
##

## Errors
resource "newrelic_nrql_alert_condition" "service_error_rate_threshold" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "static"
  name = "Service Error Rate Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.error.count['count']) / count(apm.service.transaction.duration) ${local.service_metric_filter}"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 0.1
    threshold_duration = 120
    threshold_occurrences = "all"
  }
  fill_option = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = 60
  title_template = local.title_template
}


resource "newrelic_entity_tags" "tag_metric_error_rate_anomaly" {
  guid = newrelic_nrql_alert_condition.metric_error_rate_anomaly.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}
resource "newrelic_entity_tags" "tag_metric_throughput_anomaly" {
  guid = newrelic_nrql_alert_condition.metric_throughput_anomaly.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}
resource "newrelic_entity_tags" "tag_metric_latency_anomaly" {
  guid = newrelic_nrql_alert_condition.metric_latency_anomaly.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}
resource "newrelic_entity_tags" "tag_service_error_rate_threshold" {
  guid = newrelic_nrql_alert_condition.service_error_rate_threshold.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}