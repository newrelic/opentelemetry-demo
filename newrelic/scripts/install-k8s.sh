#!/bin/bash
# -----------------------------------------------------------------------------
# install-k8s.sh
#
# Purpose:
#   Installs the OpenTelemetry Demo and New Relic Kubernetes instrumentation
#   into a Kubernetes cluster using Helm charts.
#
# How to run:
#   ./install-k8s.sh
#   (Run from the newrelic/scripts directory)
#
# Dependencies:
#   - kubectl
#   - helm
#   - Access to the target Kubernetes cluster
#   - NEW_RELIC_LICENSE_KEY (will prompt if not set)
#   - NEW_RELIC_REGION (optional, defaults to us; set to eu or jp for other regions)
# -----------------------------------------------------------------------------
set -euo pipefail

source "$(dirname "$0")/common.sh"

check_tool_installed helm
check_tool_installed kubectl

prompt_for_license_key
prompt_for_region
prompt_for_openshift

install_or_upgrade_chart() {
  local release_name=$1
  local chart=$2
  local version=$3
  local values_file=$4
  local namespace=$5
  local is_openshift=${6:-}
  local provider_value=""
  local helm_args=("$release_name" "$chart" --version "$version" -f "$values_file")

  if [ "$is_openshift" = "y" ] && [ "$release_name" = "otel-demo" ]; then
    helm_args+=(--set "serviceAccount.create=false" --set "serviceAccount.name=opentelemetry-demo")
  elif [ "$is_openshift" = "y" ] && [ "$release_name" = "nr-k8s-otel-collector" ]; then
    provider_value="OPEN_SHIFT"
    helm_args+=(--set "provider=$provider_value")
  fi

  # Add any additional --set commands passed as remaining arguments
  # Shift away the first 5 required arguments, then check if 6th exists before shifting it
  shift 5
  if [ $# -gt 0 ]; then
    shift  # Shift away the 6th argument (is_openshift) if it exists
  fi
  # Now process any remaining arguments as additional --set commands
  while [ $# -gt 0 ]; do
    helm_args+=(--set "$1")
    shift
  done

  helm_args+=(-n "$namespace" --install)

  if ! helm upgrade "${helm_args[@]}"; then
    echo "Error: Failed to install or upgrade $release_name ($chart) to version $version."
    exit 1
  fi
}

# Set up the NR collector postgresql receiver's monitoring access, per
# https://docs.newrelic.com/docs/opentelemetry/database/postgresql/hosted/.
# The chart's init.sql already creates $POSTGRES_MONITOR_USER with pg_monitor
# and enables pg_stat_statements in both astronomy_db and postgres, but it
# doesn't grant access to the app's catalog/accounting schemas, which
# top_query's EXPLAIN needs to read. ALTER DEFAULT PRIVILEGES covers tables
# services create after this script runs.
# All statements are idempotent (no-op if already applied) and require no DB
# restart, since shared_preload_libraries is set via the chart's postgresql
# command override.
setup_pg_monitoring() {
  echo "Setting up postgresql receiver monitoring access for $POSTGRES_MONITOR_USER..."
  if ! kubectl rollout status deployment/astronomy-db -n "$OTEL_DEMO_NAMESPACE" --timeout=120s; then
    echo "Warning: astronomy-db deployment not ready; skipping monitoring setup. Run manually later."
    return
  fi
  local app_db_ddl="GRANT USAGE ON SCHEMA catalog TO $POSTGRES_MONITOR_USER; GRANT SELECT ON ALL TABLES IN SCHEMA catalog TO $POSTGRES_MONITOR_USER; ALTER DEFAULT PRIVILEGES IN SCHEMA catalog GRANT SELECT ON TABLES TO $POSTGRES_MONITOR_USER; GRANT USAGE ON SCHEMA accounting TO $POSTGRES_MONITOR_USER; GRANT SELECT ON ALL TABLES IN SCHEMA accounting TO $POSTGRES_MONITOR_USER; ALTER DEFAULT PRIVILEGES IN SCHEMA accounting GRANT SELECT ON TABLES TO $POSTGRES_MONITOR_USER;"
  if kubectl exec -n "$OTEL_DEMO_NAMESPACE" deployment/astronomy-db -- \
      sh -c "psql -v ON_ERROR_STOP=1 -U postgres -d astronomy_db -c '$app_db_ddl'"; then
    echo "postgresql monitoring configured for $POSTGRES_MONITOR_USER."
  else
    echo "Warning: failed to configure postgresql monitoring for $POSTGRES_MONITOR_USER. Run manually with:"
    echo "  kubectl exec -n $OTEL_DEMO_NAMESPACE deployment/astronomy-db -- sh -c 'psql -U postgres -d astronomy_db -c \"$app_db_ddl\"'"
  fi
}

# Create namespace if it doesn't exist
if kubectl get ns "$OTEL_DEMO_NAMESPACE" &> /dev/null; then
  echo "Namespace '$OTEL_DEMO_NAMESPACE' already exists."
else
  kubectl create ns "$OTEL_DEMO_NAMESPACE"
fi

# Create or update New Relic license secret
kubectl create secret generic "$NR_LICENSE_SECRET" --from-literal=license-key="$NEW_RELIC_LICENSE_KEY" -n "$OTEL_DEMO_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install New Relic K8s OpenTelemetry Collector
ensure_helm_repo "newrelic" "https://helm-charts.newrelic.com"
install_or_upgrade_chart "$NR_K8S_RELEASE_NAME" "newrelic/nr-k8s-otel-collector" "$NR_K8S_CHART_VERSION" "../k8s/helm/nr-k8s-otel-collector.yaml" "$OTEL_DEMO_NAMESPACE" "$IS_OPENSHIFT_CLUSTER" "global.region=$NEW_RELIC_REGION"

# Install OpenTelemetry Demo
ensure_helm_repo "open-telemetry" "https://open-telemetry.github.io/opentelemetry-helm-charts"
install_or_upgrade_chart "$OTEL_DEMO_RELEASE_NAME" "open-telemetry/opentelemetry-demo" "$OTEL_DEMO_CHART_VERSION" "../k8s/helm/opentelemetry-demo.yaml" "$OTEL_DEMO_NAMESPACE" "$IS_OPENSHIFT_CLUSTER"

# Set up postgres db grants
setup_pg_monitoring

echo "OpenTelemetry Demo installation completed successfully!"
