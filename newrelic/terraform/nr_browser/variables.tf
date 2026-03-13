variable "newrelic_api_key" {
  description = "New Relic User API Key"
  type        = string
  sensitive   = true
}

variable "newrelic_account_id" {
  description = "New Relic Account ID"
  type        = string
}

variable "newrelic_region" {
  description = "New Relic Region (US or EU)"
  type        = string
  default     = "US"
}

variable "web_app_name" {
  description = "Name of the Browser Application"
  type        = string
  default     = "frontend"
}