#!/bin/bash
set -e

REGION="$1"
GUID="$2"

: "${NEW_RELIC_API_KEY:?NEW_RELIC_API_KEY must be set}"

API_ENDPOINT="https://api.${REGION}.com/graphql"

MUTATION="mutation { agentApplicationSettingsUpdate(guid: \\\"${GUID}\\\", settings: {sessionReplay: {enabled: true, samplingRate: 10, errorSamplingRate: 100}}) { browserSettings { sessionReplay { enabled samplingRate errorSamplingRate } } errors { description } } }"

command -v jq >/dev/null || { echo "Error: jq is required"; exit 1; }

RESPONSE=$(curl -sS --fail-with-body -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "API-Key: $NEW_RELIC_API_KEY" \
  -d "{\"query\": \"${MUTATION}\"}")

ERRORS=$(echo "$RESPONSE" | jq -r '(.errors // []) + (.data.agentApplicationSettingsUpdate.errors // []) | if length > 0 then . else empty end')
[ -n "$ERRORS" ] && echo "Error: failed to enable Session Replay" && echo "$ERRORS" && exit 1

ENABLED=$(echo "$RESPONSE" | jq -r '.data.agentApplicationSettingsUpdate.browserSettings.sessionReplay.enabled')
[ "$ENABLED" != "true" ] && echo "Error: Session Replay not enabled, response: $RESPONSE" && exit 1

echo "Session Replay enabled for $GUID"
