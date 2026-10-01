output "browser_js_config" {
  description = "The JSON configuration containing Trust Key and Agent ID"
  value       = newrelic_browser_application.otel_demo.js_config
}

output "browser_license_key" {
  value = newrelic_api_access_key.browser_key.key
}