# Provider configuration variables
variable "newrelic_api_key" {
  description = "New Relic User API Key"
  type        = string
  sensitive   = true
}

variable "newrelic_region" {
  description = "New Relic region (US or EU)"
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU"], upper(var.newrelic_region))
    error_message = "Region must be either 'US' or 'EU'."
  }
}

# Module variables
variable "newrelic_account_id" {
  description = "The New Relic account ID where the OpenTelemetry Demo is deployed"
  type        = string
}