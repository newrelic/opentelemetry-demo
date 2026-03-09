##############################
## Web Alerts 
##

## Web Alert Policy
resource "newrelic_alert_policy" "web_alert_policy" {
  name = "Astronomy Web Health"
  incident_preference = "PER_CONDITION"
}

## LCP Threshold
resource "newrelic_nrql_alert_condition" "web_lcp_threshold" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.web_alert_policy.id
  type = "static"
  name = "LCP Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentile(largestContentfulPaint, 75) FROM PageViewTiming WHERE appName = '${var.web_app_name}' FACET appName"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 4.0
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.web_title_template
}

## INP Threshold
resource "newrelic_nrql_alert_condition" "web_inp_threshold" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.web_alert_policy.id
  type = "static"
  name = "INP Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentile(interactionToNextPaint, 75) FROM PageViewTiming WHERE appName = '${var.web_app_name}' FACET appName"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 4.0
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.web_title_template
}

## AJAX Image Latency
resource "newrelic_nrql_alert_condition" "web_ajax_image_latency" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.web_alert_policy.id
  type = "static"
  name = "AJAX Image Latency Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentile(timeToLoadEventStart, 75) FROM AjaxRequest WHERE appName = '${var.web_app_name}' AND requestUrl LIKE '%images%' FACET appName"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 1.0
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.web_title_template
}

## AJAX API Latency
resource "newrelic_nrql_alert_condition" "web_ajax_api_latency" {
  account_id = var.newrelic_account_id
  policy_id = newrelic_alert_policy.web_alert_policy.id
  type = "static"
  name = "AJAX API Latency Threshold"
  enabled = true
  violation_time_limit_seconds = 259200

  nrql {
    query = "SELECT percentile(timeToLoadEventStart, 75) FROM AjaxRequest WHERE appName = '${var.web_app_name}' AND requestUrl LIKE '%/api/%' FACET appName"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator = "above"
    threshold = 1.0
    threshold_duration = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay = local.aggregation_delay
  title_template = local.web_title_template
}
resource "newrelic_entity_tags" "tag_web_lcp_threshold" {
  guid = newrelic_nrql_alert_condition.web_lcp_threshold.entity_guid

  tag {
    key    = "data-type"
    values = ["webVital"]
  }
}

resource "newrelic_entity_tags" "tag_web_inp_threshold" {
  guid = newrelic_nrql_alert_condition.web_inp_threshold.entity_guid

  tag {
    key    = "data-type"
    values = ["webVital"]
  }
}

resource "newrelic_entity_tags" "tag_web_ajax_image_latency" {
  guid = newrelic_nrql_alert_condition.web_ajax_image_latency.entity_guid

  tag {
    key    = "data-type"
    values = ["ajaxRequest"]
  }
}

resource "newrelic_entity_tags" "tag_web_ajax_api_latency" {
  guid = newrelic_nrql_alert_condition.web_ajax_api_latency.entity_guid

  tag {
    key    = "data-type"
    values = ["ajaxRequest"]
  }
}