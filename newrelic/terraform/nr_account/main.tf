provider "newrelic" {
  api_key    = var.newrelic_api_key
  account_id = var.newrelic_parent_account_id
  region     = upper(var.newrelic_region)
}

# Create a New Relic sub-account
resource "newrelic_account_management" "subaccount" {
  name   = var.subaccount_name
  region = upper(var.newrelic_region) == "US" ? "us01" : "eu01"
}

# Get admin authentication domain
data "newrelic_authentication_domain" "admin_auth_domain" {
  name = var.admin_authentication_domain_name
}

# Get admin group
data "newrelic_group" "admin_group" {
  authentication_domain_id = data.newrelic_authentication_domain.admin_auth_domain.id
  name                     = var.admin_group_name
}

# Grant admin group access to the sub-account
resource "terraform_data" "admin_access_grant" {
  triggers_replace = {
    account_id = newrelic_account_management.subaccount.id
    api_key    = var.newrelic_api_key
    region     = upper(var.newrelic_region) == "US" ? "newrelic" : "eu.newrelic"
    group_id   = data.newrelic_group.admin_group.id
    role_name  = var.admin_role_name
  }

  provisioner "local-exec" {
    command = "${path.module}/group_role_grant.sh '${self.triggers_replace.api_key}' '${self.triggers_replace.region}' '${self.triggers_replace.group_id}' '${self.triggers_replace.role_name}' ${self.triggers_replace.account_id}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/group_role_revoke.sh '${self.triggers_replace.api_key}' '${self.triggers_replace.region}' '${self.triggers_replace.group_id}' '${self.triggers_replace.role_name}' ${self.triggers_replace.account_id}"
  }
}

# Get user authentication domain
data "newrelic_authentication_domain" "user_auth_domain" {
  name = var.user_authentication_domain_name
}

# Create user
resource "newrelic_user" "user" {
  authentication_domain_id = data.newrelic_authentication_domain.user_auth_domain.id
  email_id                 = var.user_email
  name                     = var.user_name
  user_type                = "FULL_USER_TIER"
}

# Create user group with user
resource "newrelic_group" "user_group" {
  authentication_domain_id = data.newrelic_authentication_domain.user_auth_domain.id
  name                     = "${var.subaccount_name} - User"
  user_ids                 = [newrelic_user.user.id]
}

# Grant user group access to the sub-account
resource "terraform_data" "user_access_grant" {
  triggers_replace = {
    account_id = newrelic_account_management.subaccount.id
    api_key    = var.newrelic_api_key
    region     = upper(var.newrelic_region) == "US" ? "newrelic" : "eu.newrelic"
    group_id   = newrelic_group.user_group.id
    role_name  = var.user_role_name
  }

  provisioner "local-exec" {
    command = "${path.module}/group_role_grant.sh '${self.triggers_replace.api_key}' '${self.triggers_replace.region}' '${self.triggers_replace.group_id}' '${self.triggers_replace.role_name}' ${self.triggers_replace.account_id}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/group_role_revoke.sh '${self.triggers_replace.api_key}' '${self.triggers_replace.region}' '${self.triggers_replace.group_id}' '${self.triggers_replace.role_name}' ${self.triggers_replace.account_id}"
  }

  depends_on = [
    newrelic_group.user_group
  ]
}

# Create a license key for the sub-account
resource "newrelic_api_access_key" "license_key" {
  account_id  = newrelic_account_management.subaccount.id
  key_type    = "INGEST"
  ingest_type = "LICENSE"
  name        = "OpenTelemetry Demo License Key"
  notes       = "License key for OpenTelemetry Demo deployment"

  depends_on = [
    terraform_data.admin_access_grant
  ]
}
