# Define the Services targeted by the 5 Feature Flags
locals {
  services = {
    # feature flags: productCatalogFailure
    "product-catalog" = { latency_ms = 200 }
    # feature flags: paymentUnreachable, paymentFailure
    "payment" = { latency_ms = 500 }
    # feature flags: loadGeneratorFloodHomepage, imageSlowLoad
    "frontend" = { latency_ms = 1000 }
    # feature flags: cartFailure
    "cart" = { latency_ms = 200 }
  }
}

# Look up the entities dynamically
data "newrelic_entity" "services" {
  for_each = local.services
  name     = each.key
}

# Create Throughput SLOs (Successful Throughput / Total Throughput)
resource "newrelic_service_level" "throughput_slo" {
  for_each    = local.services
  guid        = data.newrelic_entity.services[each.key].guid
  name        = "${each.key} - Throughput"
  description = "Throughput SLO for ${each.key} measuring successful request processing."

  events {
    account_id = var.newrelic_account_id
    valid_events {
      from  = "Span"
      where = "entity.guid = '${data.newrelic_entity.services[each.key].guid}' AND span.kind = 'server'"
    }
    bad_events {
      from  = "Span"
      where = "entity.guid = '${data.newrelic_entity.services[each.key].guid}' AND span.kind = 'server' AND otel.status_code = 'ERROR'"
    }
  }

  objective {
    target = 99.5
    time_window {
      rolling {
        count = 1
        unit  = "DAY"
      }
    }
  }
}

# Create Latency SLOs
resource "newrelic_service_level" "latency_slo" {
  for_each    = local.services
  guid        = data.newrelic_entity.services[each.key].guid
  name        = "${each.key} - Latency (< ${each.value.latency_ms}ms)"
  description = "Latency SLO for ${each.key} catching load spikes and slow resources."

  events {
    account_id = var.newrelic_account_id
    valid_events {
      from  = "Span"
      where = "entity.guid = '${data.newrelic_entity.services[each.key].guid}' AND span.kind = 'server'"
    }
    good_events {
      from  = "Span"
      where = "entity.guid = '${data.newrelic_entity.services[each.key].guid}' AND span.kind = 'server' AND duration.ms < ${each.value.latency_ms}"
    }
  }

  objective {
    target = 95.0
    time_window {
      rolling {
        count = 1
        unit  = "DAY"
      }
    }
  }
}

# Delete the "Service Levels default" alert policy that New Relic automatically
# creates whenever an SLO is created via the API. There is no API flag to suppress
# this behaviour — deletion after creation is the only workaround.
resource "null_resource" "delete_slo_default_alerts" {
  depends_on = [
    newrelic_service_level.throughput_slo,
    newrelic_service_level.latency_slo,
  ]

  # Re-trigger whenever the set of SLOs changes (e.g. SLOs are recreated).
  triggers = {
    sli_guids = jsonencode(merge(
      { for k, v in newrelic_service_level.throughput_slo : k => v.sli_guid },
      { for k, v in newrelic_service_level.latency_slo : k => v.sli_guid },
    ))
  }

  provisioner "local-exec" {
    environment = {
      NR_API_KEY    = var.newrelic_api_key
      NR_ACCOUNT_ID = var.newrelic_account_id
      NR_API_URL    = var.newrelic_region == "EU" ? "https://api.eu.newrelic.com/graphql" : "https://api.newrelic.com/graphql"
    }

    command = <<-EOT
      set -euo pipefail

      # New Relic creates the "Service Levels default" policy asynchronously after
      # the SLO API call. Poll until it appears (up to ~2 minutes) before deleting.
      MAX_ATTEMPTS=24
      SLEEP_SECONDS=5

      LIST_PAYLOAD=$(printf \
        '{"query":"{ actor { account(id: %s) { alerts { policiesSearch(searchCriteria: {}) { policies { id name } } } } } }"}' \
        "$NR_ACCOUNT_ID")

      POLICY_IDS=""
      for i in $(seq 1 $MAX_ATTEMPTS); do
        echo "Attempt $i/$MAX_ATTEMPTS: searching for 'Service Levels default' policy..."

        RESPONSE=$(curl -s -X POST "$NR_API_URL" \
          -H "Api-Key: $NR_API_KEY" \
          -H "Content-Type: application/json" \
          -d "$LIST_PAYLOAD")

        if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
          echo "ERROR: NerdGraph returned errors while listing policies: $RESPONSE" >&2
          exit 1
        fi

        POLICY_IDS=$(echo "$RESPONSE" | jq -r '
          .data.actor.account.alerts.policiesSearch.policies[]
          | select(.name | test("Service Levels default"; "i"))
          | .id
        ')

        if [ -n "$POLICY_IDS" ]; then
          echo "Policy found."
          break
        fi

        if [ "$i" -lt "$MAX_ATTEMPTS" ]; then
          echo "Not found yet, retrying in $${SLEEP_SECONDS}s..."
          sleep $SLEEP_SECONDS
        fi
      done

      if [ -z "$POLICY_IDS" ]; then
        echo "No 'Service Levels default' policy appeared after $((MAX_ATTEMPTS * SLEEP_SECONDS))s — nothing to delete."
        exit 0
      fi

      for ID in $POLICY_IDS; do
        echo "Deleting policy $ID..."
        DELETE_PAYLOAD=$(printf \
          '{"query":"mutation { alertsPolicyDelete(accountId: %s, id: %s) { id } }"}' \
          "$NR_ACCOUNT_ID" "$ID")
        DELETE_RESPONSE=$(curl -s -X POST "$NR_API_URL" \
          -H "Api-Key: $NR_API_KEY" \
          -H "Content-Type: application/json" \
          -d "$DELETE_PAYLOAD")

        if echo "$DELETE_RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
          echo "ERROR: Failed to delete policy $ID: $DELETE_RESPONSE" >&2
          exit 1
        fi

        echo "Successfully deleted policy $ID."
      done
    EOT
  }
}

# Alert Policy
## Disabling, will reevaluate at another date

# resource "newrelic_alert_policy" "gameday_policy" {
#   name                = "Gameday Service Level Alerts"
#   incident_preference = "PER_CONDITION"
# }

# # Burn Rate Alerts - Throughput
# data "newrelic_service_level_alert_helper" "throughput_fast_burn" {
#   for_each   = newrelic_service_level.throughput_slo
#   alert_type = "fast_burn"
#   sli_guid   = each.value.sli_guid
#   slo_target = 99.5
#   slo_period = 1
# }

# resource "newrelic_nrql_alert_condition" "throughput_burn_rate" {
#   for_each                     = newrelic_service_level.throughput_slo
#   account_id                   = var.newrelic_account_id
#   policy_id                    = newrelic_alert_policy.gameday_policy.id
#   type                         = "static"
#   name                         = "SL :${each.value.name} - Fast Burn"
#   description                  = "High failure rate in throughput detected. Check flagd for active failure flags."
#   enabled                      = true
#   violation_time_limit_seconds = 86400

#   nrql {
#     query = data.newrelic_service_level_alert_helper.throughput_fast_burn[each.key].nrql
#   }

#   critical {
#     operator              = "above"
#     threshold             = data.newrelic_service_level_alert_helper.throughput_fast_burn[each.key].threshold
#     threshold_duration    = data.newrelic_service_level_alert_helper.throughput_fast_burn[each.key].evaluation_period
#     threshold_occurrences = "all"
#   }
# }

# # Burn Rate Alerts - Latency
# data "newrelic_service_level_alert_helper" "latency_fast_burn" {
#   for_each   = newrelic_service_level.latency_slo
#   alert_type = "fast_burn"
#   sli_guid   = each.value.sli_guid
#   slo_target = 95.0
#   slo_period = 1
# }

# resource "newrelic_nrql_alert_condition" "latency_burn_rate" {
#   for_each                     = newrelic_service_level.latency_slo
#   account_id                   = var.newrelic_account_id
#   policy_id                    = newrelic_alert_policy.gameday_policy.id
#   type                         = "static"
#   name                         = "SL: ${each.value.name} - Fast Burn"
#   description                  = "High latency detected. Check flagd for active degradation flags."
#   enabled                      = true
#   violation_time_limit_seconds = 86400

#   nrql {
#     query = data.newrelic_service_level_alert_helper.latency_fast_burn[each.key].nrql
#   }

#   critical {
#     operator              = "above"
#     threshold             = data.newrelic_service_level_alert_helper.latency_fast_burn[each.key].threshold
#     threshold_duration    = data.newrelic_service_level_alert_helper.latency_fast_burn[each.key].evaluation_period
#     threshold_occurrences = "all"
#   }
# }