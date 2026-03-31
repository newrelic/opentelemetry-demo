provider "newrelic" {
  api_key    = var.newrelic_api_key
  account_id = var.newrelic_account_id
  region     = upper(var.newrelic_region)
}

## Reusable variables
locals {
   web_title_template = "{{tags.appName}} [{{conditionName}}] {{priority}}"
   aggregation_window = 30
   aggregation_delay = 30
   threshold_duration = 60
}
