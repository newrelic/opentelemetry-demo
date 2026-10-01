#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# validate-docker.sh
#
# Purpose:
#   Validate the OpenTelemetry Demo running on Docker.
#
# How to run:
#   ./validate-docker.sh
#   (Run from the newrelic/scripts directory)
#
# Environment variables:
#   NEW_RELIC_REGION        Your New Relic region (will prompt if not set,
#                           default: US)
#                           (used by CLI install docker, validate-newrelic.sh,
#                           and CLI uninstall docker)
#   NEW_RELIC_LICENSE_KEY   Your New Relic license key (will prompt if not set)
#                           (used by CLI install docker, docker compose
#                           commands, and CLI uninstall docker)
#   NEW_RELIC_API_KEY       Your New Relic User API key (will prompt if not set)
#                           (used by validate-newrelic.sh)
#   NEW_RELIC_ACCOUNT_ID    Your New Relic Account ID (will prompt if not set)
#                           (used by validate-newrelic.sh)
#
# Dependencies:
#   - Docker (used by CLI install docker, docker compose commands,
#     and CLI uninstall docker)
#   - Docker Compose v2+ (used by CLI install docker, docker compose commands,
#     and CLI uninstall docker)
#   - .env and .env.override files in the project root
#   - python3 (used by validate-newrelic.sh)
# -----------------------------------------------------------------------------
set -euo pipefail

# Source the common functions and variables
source "$(dirname "$0")/common.sh"

# Make sure tools required by all scripts are installed
# Note: The CLI install docker command will check for Docker so we don't need
# to do that here, but we do need to check for python3 since it's required by
# the validate-newrelic.sh script.
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
echo "Installing OpenTelemetry Demo on Docker..."
cd "$SCRIPT_DIR/../cli" && \
  NEW_RELIC_REGION="$NEW_RELIC_REGION" \
  NEW_RELIC_LICENSE_KEY="$NEW_RELIC_LICENSE_KEY" \
  NEW_RELIC_ENABLE_BROWSER=false \
  go run . install docker

# Begin validation
echo "Validating OpenTelemetry Demo Docker installation..."

# Wait up to a minute for all containers to be in Running state
echo "Waiting for all containers to be in Running state..."

TOTAL_COUNT=$(NEW_RELIC_LICENSE_KEY="$NEW_RELIC_LICENSE_KEY" docker compose --env-file ../../.env --env-file ../../.env.override --file ../docker/docker-compose.yml config --services | wc -l)
RETRY_COUNT=0
MAX_RETRIES=30
DONE=0

until [ $DONE -eq 1 ]; do
  RUNNING=$(NEW_RELIC_LICENSE_KEY="$NEW_RELIC_LICENSE_KEY" docker compose --env-file ../../.env --env-file ../../.env.override --file ../docker/docker-compose.yml ps --filter "status=running" -q | wc -l)
  if [ $RUNNING -eq $TOTAL_COUNT ]; then
    DONE=1
    break
  fi

  echo "$RUNNING out of $TOTAL_COUNT containers are running..."

  sleep 2
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "Timeout waiting for containers to be in Running state."
    exit 1
  fi
done

echo "All containers are in Running state!"

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
  echo "Try running ./validate-docker.sh again or run ./validate-newrelic.sh to manually run the New Relic validation."
  exit 1
fi

# Validation succeeded, maybe cleanup Docker objects
if [ "${DOCKER_CLEANUP_ENABLED:-true}" = "true" ]; then
  echo "Validation succeeded! Cleaning up Docker objects..."
  cd "$SCRIPT_DIR/../cli" && \
    go run . uninstall docker
fi
