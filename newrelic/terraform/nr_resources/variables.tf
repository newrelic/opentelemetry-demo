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

variable "web_app_name" {
  description = "Name of the frontend web application in New Relic"
  type        = string
  default     = "astroshop-frontend"
}

##
## Whether or not Service low throughput alerts are enabled.
## By default this is off as it can be noisy for a gameday environment.
##
variable "low_throughput_alert_enabled" {
  description = "Whether the low throughput alert is enabled"
  type        = bool
  default     = false
}


## 
## Maps services to thresholds for alerts are defined using metric values.
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

## 
## Maps services to  thresholds for alerts are defined using span values.

variable "span_alert_map" {
    type = map(object({
            service_name = string
            service_title_name = string
            throughput_lower_threshold = number
            throughput_upper_threshold = number
            latency_threshold = number
            error_percent_threshold = number
    })) 
    default = {

        key1 = {
            service_name = "accounting"
            service_title_name = "Accounting Service"
            throughput_lower_threshold = 0
            throughput_upper_threshold = 200
            latency_threshold = 150000
            error_percent_threshold = 20
        }
        key2 = {
            service_name = "currency"
            service_title_name = "Currency Service"
            throughput_lower_threshold = 50
            throughput_upper_threshold = 300
            latency_threshold = 50
            error_percent_threshold = 0.1
        }
        key3 = {
            service_name = "email"
            service_title_name = "Email Service"
            throughput_lower_threshold = 0
            throughput_upper_threshold = 100
            latency_threshold = 50
            error_percent_threshold = 0.1
        }
        key4 = {
            service_name = "fraud-detection"
            service_title_name = "Fraud Detection Service"
            throughput_lower_threshold = 0
            throughput_upper_threshold = 50
            latency_threshold = 700000
            error_percent_threshold = 30
        }
        key5 = {
            service_name = "frontend-proxy"
            service_title_name = "Frontend Proxy Service"
            throughput_lower_threshold = 4000
            throughput_upper_threshold = 10000
            latency_threshold = 50
            error_percent_threshold = 5
        }
        key6 = {
            service_name = "image-provider"
            service_title_name = "Image Provider Service"
            throughput_lower_threshold = 200
            throughput_upper_threshold = 800
            latency_threshold = 10
            error_percent_threshold = 0.01
        }
        key7 = {
            service_name = "payment"
            service_title_name = "Payment Service"
            throughput_lower_threshold = 40
            throughput_upper_threshold = 160
            latency_threshold = 600
            error_percent_threshold = 10
        }
        key8 = {
            service_name = "product-reviews"
            service_title_name = "Product Reviews Service"
            throughput_lower_threshold = 0
            throughput_upper_threshold = 5
            latency_threshold = 80000
            error_percent_threshold = 100
        }
        key9 = {
            service_name = "quote"
            service_title_name = "Quote Service"
            throughput_lower_threshold = 1
            throughput_upper_threshold = 100
            latency_threshold = 50
            error_percent_threshold = 1
        }
        key10 = {
            service_name = "recommendation"
            service_title_name = "Recommendation Service"
            throughput_lower_threshold = 100
            throughput_upper_threshold = 800
            latency_threshold = 20
            error_percent_threshold = 1
        }
    }
} 