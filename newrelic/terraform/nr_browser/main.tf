terraform {
  required_version = ">= 1.0.0"
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = ">= 3.0.0"
    }
  }
}

provider "newrelic" {
  api_key    = var.newrelic_api_key
  account_id = var.newrelic_account_id
  region     = upper(var.newrelic_region)
}

resource "newrelic_browser_application" "otel_demo" {
  name        = var.web_app_name
  account_id  = var.newrelic_account_id
  loader_type = "SPA"
}

# [NEW] Create a Browser License Key (Ingest Type)
# This is required because the browser_application resource doesn't output a key directly.
resource "newrelic_api_access_key" "browser_key" {
  account_id  = var.newrelic_account_id
  key_type    = "INGEST"
  ingest_type = "BROWSER"
  name        = "Browser Key - ${var.web_app_name}"
}