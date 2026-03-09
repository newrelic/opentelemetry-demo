provider "newrelic" {
  api_key    = var.newrelic_api_key
  account_id = var.newrelic_account_id
  region     = upper(var.newrelic_region)
}

## Reusable variables
locals {
   service_metric_filter = "FROM Metric WHERE (service.name IN ('ad','frontend','shipping')) AND (transactionType = 'Web') FACET service.name, entity.guid"
   service_span_filter = "FROM Span WHERE service.name NOT IN ('ad','cart','checkout', 'frontend','product-catalog', 'shipping', 'load-generator', 'flagd') FACET service.name"
   anomaly_title_template = "{{tags.service.name}} [{{conditionName}}] {{priority}}"
   service_title_template = "{{tags.service.name}} [{{conditionName}}] {{priority}}"
   specific_service_title_template = "[{{conditionName}}] {{priority}}"
   web_title_template = "{{tags.appName}} [{{conditionName}}] {{priority}}"
   aggregation_window = 60
   aggregation_delay = 60
   threshold_duration = 120
}

