# Provider configuration variables
variable "newrelic_api_key" {
  description = "New Relic User API Key with Organization Manager permissions, and which is part of `admin_group_name`"
  type        = string
  sensitive   = true
}

variable "newrelic_parent_account_id" {
  description = "Parent account ID for creating sub-accounts"
  type        = string
}

variable "newrelic_region" {
  description = "New Relic region (US, EU, or JP)"
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU", "JP"], upper(var.newrelic_region))
    error_message = "Region must be 'US', 'EU', or 'JP'."
  }
}

# Module variables
variable "subaccount_name" {
  description = "Name of the sub-account to create"
  type        = string
}

variable "admin_authentication_domain_name" {
  description = "Authentication domain containing `admin_group_name` group"
  type        = string
  default     = "Default"
}

variable "admin_group_name" {
  description = "Name of an existing group to grant `admin_role_name` in the new account"
  type        = string
}

variable "admin_role_name" {
  description = "Role to grant `admin_group_name`; must have permissions to create license keys"
  type        = string
  default     = "all_product_admin"
}

variable "readonly_authentication_domain_name" {
  description = "Authentication domain for creating the read-only user (only basic auth supported)"
  type        = string
  default     = "Default"
}

variable "readonly_role_name" {
  description = "Role to grant the readonly group in the new account"
  type        = string
  default     = "read_only"
}

variable "readonly_user_email" {
  description = "Email address of the read-only user to create. When null, user and group membership creation are skipped and the readonly group is created empty."
  type        = string
  default     = null
}

variable "readonly_user_name" {
  description = "Display name of the read-only user. Required when readonly_user_email is set."
  type        = string
  default     = null
}
