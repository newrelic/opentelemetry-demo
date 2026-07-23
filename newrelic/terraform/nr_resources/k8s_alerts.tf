##############################
## Kubernetes Alerts
##
## Based on OpenTelemetry metrics scraped by the nr-k8s-otel-collector chart's
## kube-state-metrics (kube_*) and kubeletstats receivers, faceted with
## OTel semconv resource attributes (k8s.pod.name, k8s.namespace.name, etc.)
## rather than the New Relic Infrastructure agent's proprietary K8s metrics.
##

## Kubernetes Alert Policy
resource "newrelic_alert_policy" "k8s_alert_policy" {
  name                = "Astronomy Kubernetes Health"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

## Pod Not Ready
## kube_pod_status_ready is a per-condition gauge (condition = 'true' | 'false' | 'unknown');
## the series where condition = 'false' is 1 while the pod is not ready.
resource "newrelic_nrql_alert_condition" "k8s_pod_not_ready" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.k8s_alert_policy.id
  type                         = "static"
  name                         = "Pod Not Ready"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT latest(kube_pod_status_ready) FROM Metric WHERE metricName = 'kube_pod_status_ready' AND condition = 'false' FACET k8s.pod.name, k8s.namespace.name, k8s.cluster.name"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option        = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

## Deployment Replicas Unavailable
resource "newrelic_nrql_alert_condition" "k8s_deployment_replicas_unavailable" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.k8s_alert_policy.id
  type                         = "static"
  name                         = "Deployment Replicas Unavailable"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT latest(kube_deployment_status_replicas_unavailable) FROM Metric WHERE metricName = 'kube_deployment_status_replicas_unavailable' FACET k8s.deployment.name, k8s.namespace.name, k8s.cluster.name"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option        = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

## Container OOMKilled
## kube_pod_container_status_last_terminated_reason is a labeled gauge that reports
## 1 for whichever reason was last recorded for the container; alert when that
## reason is OOMKilled.
resource "newrelic_nrql_alert_condition" "k8s_container_oom_killed" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.k8s_alert_policy.id
  type                         = "static"
  name                         = "Container OOMKilled"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT latest(kube_pod_container_status_last_terminated_reason) FROM Metric WHERE metricName = 'kube_pod_container_status_last_terminated_reason' AND reason = 'OOMKilled' FACET k8s.pod.name, k8s.container.name, k8s.namespace.name, k8s.cluster.name"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "at_least_once"
  }
  fill_option        = "none"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

## Readiness Probe Failing
## kube_pod_container_status_ready is a per-container gauge; 0 while the
## container's readiness probe is failing.
resource "newrelic_nrql_alert_condition" "k8s_readiness_probe_failing" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.k8s_alert_policy.id
  type                         = "static"
  name                         = "Readiness Probe Failing"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query           = "SELECT latest(kube_pod_container_status_ready) FROM Metric WHERE metricName = 'kube_pod_container_status_ready' FACET k8s.pod.name, k8s.container.name, k8s.namespace.name, k8s.cluster.name"
    data_account_id = var.newrelic_account_id
  }

  critical {
    operator              = "below"
    threshold             = 1
    threshold_duration    = local.threshold_duration
    threshold_occurrences = "all"
  }
  fill_option        = "last_value"
  aggregation_window = local.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = local.aggregation_delay
  title_template     = "[{{conditionName}}] {{priority}}"
}

##
## Tags for Kubernetes Alert Conditions
##

resource "newrelic_entity_tags" "tag_k8s_pod_not_ready" {
  guid = newrelic_nrql_alert_condition.k8s_pod_not_ready.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
  tag {
    key    = "golden-signal"
    values = ["availability"]
  }
}

resource "newrelic_entity_tags" "tag_k8s_deployment_replicas_unavailable" {
  guid = newrelic_nrql_alert_condition.k8s_deployment_replicas_unavailable.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
  tag {
    key    = "golden-signal"
    values = ["availability"]
  }
}

resource "newrelic_entity_tags" "tag_k8s_container_oom_killed" {
  guid = newrelic_nrql_alert_condition.k8s_container_oom_killed.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
  tag {
    key    = "golden-signal"
    values = ["saturation"]
  }
}

resource "newrelic_entity_tags" "tag_k8s_readiness_probe_failing" {
  guid = newrelic_nrql_alert_condition.k8s_readiness_probe_failing.entity_guid

  tag {
    key    = "data-type"
    values = ["metric"]
  }
  tag {
    key    = "golden-signal"
    values = ["availability"]
  }
}
