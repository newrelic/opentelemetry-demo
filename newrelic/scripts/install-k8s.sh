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

# Set up the NR collector postgresql receiver's monitoring access:
#   - GRANT pg_monitor to the receiver's user (init.sql creates it without
#     monitoring privileges; needed for query_sample/top_query).
#   - CREATE EXTENSION pg_stat_statements in both the app database and
#     "postgres". The receiver's top_query collection always connects to the
#     hardcoded "postgres" database regardless of the configured `databases`
#     list (see postgresqlreceiver's defaultPostgreSQLDatabase), and Postgres
#     extensions are per-database, so the extension must exist in "postgres"
#     too or top_query fails with `relation "pg_stat_statements" does not
#     exist` even though it works fine against the app database.
# All statements are idempotent (no-op if already applied) and require no DB
# restart, since shared_preload_libraries is set via the chart's postgresql
# command override.
setup_pg_monitoring() {
  echo "Setting up postgresql receiver monitoring access for $POSTGRES_MONITOR_USER..."
  if ! kubectl rollout status deployment/postgresql -n "$OTEL_DEMO_NAMESPACE" --timeout=120s; then
    echo "Warning: postgresql deployment not ready; skipping monitoring setup. Run manually later."
    return
  fi
  # Use the superuser and database configured on the pod rather than hard-coding.
  # Two separate psql invocations, since `-c` runs one SQL statement string
  # against a single connection and can't switch databases mid-session (that's
  # the psql meta-command \c, not SQL).
  local app_db_ddl="CREATE EXTENSION IF NOT EXISTS pg_stat_statements; GRANT pg_monitor TO $POSTGRES_MONITOR_USER;"
  local postgres_db_ddl="CREATE EXTENSION IF NOT EXISTS pg_stat_statements; GRANT CONNECT ON DATABASE postgres TO $POSTGRES_MONITOR_USER;"
  if kubectl exec -n "$OTEL_DEMO_NAMESPACE" deployment/postgresql -- \
      sh -c "psql -v ON_ERROR_STOP=1 -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -c '$app_db_ddl'" \
    && kubectl exec -n "$OTEL_DEMO_NAMESPACE" deployment/postgresql -- \
      sh -c "psql -v ON_ERROR_STOP=1 -U \"\$POSTGRES_USER\" -d postgres -c '$postgres_db_ddl'"; then
    echo "postgresql monitoring configured for $POSTGRES_MONITOR_USER."
  else
    echo "Warning: failed to configure postgresql monitoring for $POSTGRES_MONITOR_USER. Run manually with:"
    echo "  kubectl exec -n $OTEL_DEMO_NAMESPACE deployment/postgresql -- sh -c 'psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -c \"$app_db_ddl\"'"
    echo "  kubectl exec -n $OTEL_DEMO_NAMESPACE deployment/postgresql -- sh -c 'psql -U \"\$POSTGRES_USER\" -d postgres -c \"$postgres_db_ddl\"'"
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
