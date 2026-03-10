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

variable "checkout_service_name" {
  description = "Name of the checkout service entity in New Relic"
  type        = string
  default     = "checkout"
}

variable "product_catalog_service_name" {
  description = "Name of the product catalog service entity in New Relic"
  type        = string
  default     = "product-catalog"
}

variable "cart_service_name" {
  description = "Name of the checkout service entity in New Relic"
  type        = string
  default     = "cart"
}

variable "web_app_name" {
  description = "Name of the frontend web application in New Relic"
  type        = string
  default     = "astroshop-frontend"
}

## 
## Maps services to expected thresholds
##
variable "metric_alert_map" {
    type = map(object({
            service_name = string
            service_title_name = string
            throughput_lower_threshold = number
            throughput_upper_threshold = number
            latency_threshold = number
            error_rate_threshold = number
    })) 
    default = {
        key1 = {
            service_name = "ad"
            service_title_name = "Ad Service"
            throughput_lower_threshold = 100
            throughput_upper_threshold = 400
            latency_threshold = 10
            error_rate_threshold = 0.01
        }
        key2 = {
            service_name = "cart"
            service_title_name = "Cart Service"
            throughput_lower_threshold = 300
            throughput_upper_threshold = 600
            latency_threshold = 10
            error_rate_threshold = 0.01
        }
        key3 = {
            service_name = "checkout"
            service_title_name = "Checkout Service"
            throughput_lower_threshold = 1
            throughput_upper_threshold = 30
            latency_threshold = 1000
            error_rate_threshold = 0.55
        }
        key4 = {
            service_name = "frontend"
            service_title_name = "Frontend Service"
            throughput_lower_threshold = 1000
            throughput_upper_threshold = 4000
            latency_threshold = 50
            error_rate_threshold = 0.1
        }
        key5 = {
            service_name = "product-catalog"
            service_title_name = "Product Catalog Service"
            throughput_lower_threshold = 150
            throughput_upper_threshold = 600
            latency_threshold = 50
            error_rate_threshold = 0.1
        }
        key6 = {
            service_name = "shipping"
            service_title_name = "Shipping Service"
            throughput_lower_threshold = 15000
            throughput_upper_threshold = 25000
            latency_threshold = 2000
            error_rate_threshold = 0.1
        }
    }
} 