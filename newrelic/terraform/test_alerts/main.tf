terraform {
  # Require Terraform version 1.0 (recommended)
  required_version = "~> 1.0"

  # Require the latest 2.x version of the New Relic provider
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
    }
  }
}

provider "newrelic" {
  api_key    = var.newrelic_api_key
  account_id = var.newrelic_account_id
  region     = upper(var.newrelic_region)
}

## Reusable variables
locals {
   service_metric_filter = "FROM Metric WHERE (service.name IN ('ad','cart','checkout',  'frontend','product-catalog', 'shipping')) AND (transactionType = 'Web') FACET service.name, entity.guid"
   service_span_filter = "FROM Span WHERE service.name NOT IN ('ad','cart','checkout',  'frontend','product-catalog', 'shipping') FACET service.name"
   metric_policy_id = 7181242
   span_policy_id = 7197063
}

