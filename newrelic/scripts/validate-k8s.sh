#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# validate-k8s.sh
#
# Purpose:
#   Validate the OpenTelemetry Demo using the rendered OpenTelemetry and New
#   Relic K8s Helm charts.
#
# How to run:
#   ./validate-k8s.sh
#   (Run from the newrelic/scripts directory)
#
# Environment variables:
#   NEW_RELIC_REGION        Your New Relic region (will prompt if not set,
#                           default: US)
#                           (used by CLI install k8s, validate-newrelic.sh, and
#                           CLI uninstall k8s)
#   NEW_RELIC_LICENSE_KEY   Your New Relic license key (will prompt if not set)
#                           (used by CLI install k8s and CLI uninstall k8s)
#   NEW_RELIC_API_KEY       Your New Relic User API key (will prompt if not set)
#                           (used by validate-newrelic.sh)
#   NEW_RELIC_ACCOUNT_ID    Your New Relic Account ID (will prompt if not set)
#                           (used by validate-newrelic.sh)
#
# Dependencies:
#   - kubectl (used by CLI install k8s and CLI uninstall k8s)
#   - helm (used by CLI install k8s and CLI uninstall k8s)
#   - python3 (used by validate-newrelic.sh)
#   - Access to the target Kubernetes cluster
# -----------------------------------------------------------------------------
set -euo pipefail

# Source the common functions and variables
source "$(dirname "$0")/common.sh"

# Make sure required tools are installed
# Note: The CLI install k8s command will check for kubectl and helm, so we don't
# need to do that here, but we do need to check for python3 since it's required
# by the validate-newrelic.sh script.
check_tool_installed python3

# Load environment variables from .env if it exists
if [ -f "$SCRIPT_DIR/.env" ]; then
  source "$SCRIPT_DIR/.env"
fi

# Ensure environment variables required for all scripts are set, prompting
# the user if necessary
prompt_for_region
prompt_for_license_key
prompt_for_api_key
prompt_for_account_id

# Run the install script
echo "Installing OpenTelemetry Demo and New Relic Collector Kubernetes resources..."
cd "$SCRIPT_DIR/../cli" && \
  NEW_RELIC_REGION="$NEW_RELIC_REGION" \
  NEW_RELIC_LICENSE_KEY="$NEW_RELIC_LICENSE_KEY" \
  NEW_RELIC_ENABLE_BROWSER=false \
  go run . install k8s

# Begin validation
echo "Validating OpenTelemetry Demo and New Relic Collector Kubernetes installation..."

# Wait up to 5 minutes for all pods to be in Running state
echo "Waiting for all pods to be in Running state..."
kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all \
  -n opentelemetry-demo --timeout=300s
echo "All pods are in Running state!"

# Pause briefly to allow data to propagate to New Relic
echo "Pausing to allow data to propagate to New Relic..."
sleep 30

# Run the New Relic validation script
echo "Running New Relic validation script..."
EXIT_CODE=0
NEW_RELIC_REGION="$NEW_RELIC_REGION" \
  NEW_RELIC_API_KEY="$NEW_RELIC_API_KEY" \
  NEW_RELIC_ACCOUNT_ID="$NEW_RELIC_ACCOUNT_ID" \
  $SCRIPT_DIR/validate-newrelic.sh || EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "New Relic validation failed: Issues detected in OpenTelemetry Demo New Relic validation."
  echo "Try running ./validate-k8s.sh again or run ./validate-newrelic.sh to manually run the New Relic validation."
  exit 1
fi

# Validation succeeded, maybe cleanup K8s resources
if [ "${K8S_CLEANUP_ENABLED:-true}" = "true" ]; then
  echo "Validation succeeded! Cleaning up Kubernetes resources..."
  cd "$SCRIPT_DIR/../cli" && \
    go run . uninstall k8s
fi
