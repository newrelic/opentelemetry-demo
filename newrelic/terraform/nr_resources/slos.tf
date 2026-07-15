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

# Kafka consumer-lag SLO (ENTERPRISE-31844, optional)
#
# "fraud-detection consumer lag <= N for X% of the period." Unlike the span-based
# SLOs above, the signal is a broker-scraped Metric (kafka.consumer_group.lag from
# the kafkametrics/kafka_metrics receiver), so the event-based SLI counts scrape
# datapoints: valid = every lag datapoint for the fraud-detection group on the
# orders topic; good = those where lag <= var.kafka_consumer_lag_threshold.
#
# Bound to the fraud-detection service entity (its consumer is the one that lags),
# so the SLI surfaces on that service. The kafkaQueueProblems scenario drives lag
# well above the threshold, burning the budget; at rest lag is 0 (100% good).
data "newrelic_entity" "fraud_detection" {
  name   = "fraud-detection"
  domain = "EXT"
  type   = "SERVICE"
}

resource "newrelic_service_level" "kafka_consumer_lag_slo" {
  guid        = data.newrelic_entity.fraud_detection.guid
  name        = "fraud-detection - Kafka Consumer Lag (<= ${var.kafka_consumer_lag_threshold})"
  description = "Consumer-lag SLO for the fraud-detection group on the orders topic; degrades under the kafkaQueueProblems scenario."

  events {
    account_id = var.newrelic_account_id
    valid_events {
      from  = "Metric"
      where = "metricName = 'kafka.consumer_group.lag' AND `group` = 'fraud-detection' AND topic = 'orders'"
    }
    good_events {
      from  = "Metric"
      where = "metricName = 'kafka.consumer_group.lag' AND `group` = 'fraud-detection' AND topic = 'orders' AND `kafka.consumer_group.lag` <= ${var.kafka_consumer_lag_threshold}"
    }
  }

  objective {
    target = 99.0
    time_window {
      rolling {
        count = 1
        unit  = "DAY"
      }
    }
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