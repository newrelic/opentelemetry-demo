## Span Alert Policy
resource "newrelic_alert_policy" "span_alert_policy" {
  name = "Astronomy Service Span Health"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

##############################
## Span Threshold Alerts
## 

# Low Throughput
resource "newrelic_nrql_alert_condition" "span_service_low_throughput" {
  for_each    = var.span_alert_map
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.span_alert_policy.id

  type = "static"
  name = "${each.value.service_title_name} Low Throughput"
  enabled = var.low_throughput_alert_enabled
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT count(*) FROM Span WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "below"
    threshold = each.value.throughput_lower_threshold
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  
  fill_option = "none"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = "[{{conditionName}}] {{priority}}"
}  

# High Throughput
resource "newrelic_nrql_alert_condition" "span_service_high_throughput" {
  for_each    = var.span_alert_map
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.span_alert_policy.id

  type = "static"
  name = "${each.value.service_title_name} High Throughput"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT count(*) FROM Span WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = each.value.throughput_upper_threshold
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = "[{{conditionName}}] {{priority}}"
} 

# Latency
resource "newrelic_nrql_alert_condition" "span_service_latency" {
  for_each    = var.span_alert_map
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.span_alert_policy.id
  
  type = "static"
  name = "${each.value.service_title_name} Latency"
  enabled = true
  violation_time_limit_seconds = 259200


  nrql {
    query = "SELECT percentile(duration.ms, 95) FROM Span WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = each.value.latency_threshold
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = "[{{conditionName}}] {{priority}}"
}   

# Errors
resource "newrelic_nrql_alert_condition" "span_service_error_percent" {
  for_each    = var.span_alert_map
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.span_alert_policy.id
  type = "static"
  name = "${each.value.service_title_name} High Error Percent"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentage(count(*), WHERE error = true) FROM Span WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = each.value.error_percent_threshold
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = "[{{conditionName}}] {{priority}}"
}
 

##
## Tags
##


resource "newrelic_entity_tags" "tag_span_service_error_rate" {
  for_each    = var.span_alert_map
  guid = newrelic_nrql_alert_condition.span_service_error_percent[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["span"]
  }
  tag {
    key    = "golden-signal"
    values = ["errors"]
  }
}

resource "newrelic_entity_tags" "tag_span_service_latency" {
  for_each    = var.span_alert_map
  guid = newrelic_nrql_alert_condition.span_service_latency[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["span"]
  }
  tag {
    key    = "golden-signal"
    values = ["latency"]
  }
}

resource "newrelic_entity_tags" "tag_span_service_low_throughput" {
  for_each    = var.span_alert_map
  guid = newrelic_nrql_alert_condition.span_service_low_throughput[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["span"]
  }
  tag {
    key    = "golden-signal"
    values = ["throughput"]
  }
}

resource "newrelic_entity_tags" "tag_span_service_high_throughput" {
  for_each    = var.span_alert_map
  guid = newrelic_nrql_alert_condition.span_service_high_throughput[each.key].entity_guid


  tag {
    key    = "data-type"
    values = ["span"]
  }
  tag {
    key    = "golden-signal"
    values = ["throughput"]
  }
}