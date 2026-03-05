provider "newrelic" {
  api_key    = var.newrelic_api_key
  account_id = var.newrelic_account_id
  region     = upper(var.newrelic_region)
}

## Reusable variables
locals {
   service_metric_filter = "FROM Metric WHERE (service.name IN ('ad','cart','checkout',  'frontend','product-catalog', 'shipping')) AND (transactionType = 'Web') FACET service.name, entity.guid"
   service_span_filter = "FROM Span WHERE service.name NOT IN ('ad','cart','checkout',  'frontend','product-catalog', 'shipping') FACET service.name"
   title_template = "{{conditionName}} Affecting {{tags.service.name}} - {{priority}}"
}

