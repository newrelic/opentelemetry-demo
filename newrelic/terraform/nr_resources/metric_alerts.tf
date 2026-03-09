## Metric Alert Policy
resource "newrelic_alert_policy" "metric_alert_policy" {
  name = "Astronomy Service Metric Health"
  incident_preference = "PER_CONDITION_AND_TARGET"
}
 

##############################
## Threshold Alerts 
##

## Errors
resource "newrelic_nrql_alert_condition" "service_error_rate" {
  for_each    = var.metric_alert_map
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id

  type = "static"
  name = "${each.value.service_title_name} Error Rate"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.error.count['count']) / count(apm.service.transaction.duration) FROM Metric WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = each.value.error_rate_threshold
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.service_title_template
}

## Latency
resource "newrelic_nrql_alert_condition" "service_latency" {
  for_each    = var.metric_alert_map
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "static"
  name = "${each.value.service_title_name} Latency"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentile(convert(apm.service.transaction.duration, unit, 'ms'), 95) FROM Metric WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
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
  title_template = local.specific_service_title_template
}

## Throughput
resource "newrelic_nrql_alert_condition" "service_low_throughput" {
  for_each    = var.metric_alert_map
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "static"
  name = "${each.value.service_title_name} Throughput Below Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.transaction.duration['count']) FROM Metric WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
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
  title_template = local.specific_service_title_template
}

resource "newrelic_nrql_alert_condition" "service_high_throughput" {
  for_each    = var.metric_alert_map
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.metric_alert_policy.id
  type = "static"
  name = "${each.value.service_title_name} Throughput Above Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT sum(apm.service.transaction.duration['count']) FROM Metric WHERE service.name = '${each.value.service_name}' AND (transactionType = 'Web') FACET service.name, entity.guid"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = each.value.throughput_upper_threshold
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "none"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.specific_service_title_template
}

resource "newrelic_entity_tags" "tag_service_error_rate" {
  for_each    = var.metric_alert_map
  guid = newrelic_nrql_alert_condition.service_error_rate[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}

resource "newrelic_entity_tags" "tag_service_latency" {
  for_each    = var.metric_alert_map
  guid = newrelic_nrql_alert_condition.service_latency[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}

resource "newrelic_entity_tags" "tag_service_low_throughput" {
  for_each    = var.metric_alert_map
  guid = newrelic_nrql_alert_condition.service_low_throughput[each.key].entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
}

resource "newrelic_entity_tags" "tag_service_high_throughput" {
  for_each    = var.metric_alert_map
  guid = newrelic_nrql_alert_condition.service_high_throughput[each.key].entity_guid


  tag {
    key    = "data-type"
    values = ["metric"]
  }
}