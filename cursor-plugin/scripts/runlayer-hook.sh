#!/bin/bash
# Runlayer Cursor Hook - MCP execution validation + file read blocking
#
# sessionStart: checks for ~/.runlayer/config.yaml, warns if missing (non-blocking)
# beforeMCPExecution: reads credentials from ~/.runlayer/config.yaml at runtime
# beforeReadFile: local pattern matching only (no config needed)
#
# Security: This hook uses fail-closed behavior. If any error occurs
# (network failure, invalid response, etc.), the action is blocked.

set -euo pipefail

CONFIG_FILE="${HOME}/.runlayer/config.yaml"

deny_response() {
  local message="${1:-Hook failed - blocked for security}"
  echo "{\"permission\":\"deny\",\"user_message\":\"${message}\"}"
  exit 0
}

# --- Read hook input ---
input=$(cat) || deny_response "Failed to read hook input"
hook_type=$(echo "$input" | jq -r '.hook_event_name // empty') || deny_response "Failed to parse hook input"

case "$hook_type" in
  sessionStart)
    if [[ ! -f "$CONFIG_FILE" ]]; then
      echo "{\"agent_message\":\"Runlayer plugin active but not configured. The user should run: uvx runlayer login --host https://YOUR-TENANT.runlayer.com\"}"
    else
      echo "{}"
    fi
    ;;

  beforeMCPExecution)
    if [[ ! -f "$CONFIG_FILE" ]]; then
      deny_response "Runlayer config not found. Run 'uvx runlayer login --host https://YOUR-TENANT.runlayer.com' first."
    fi

    RUNLAYER_API_HOST=$(grep '^default_host:' "$CONFIG_FILE" \
      | sed 's/^default_host:[[:space:]]*//' | tr -d '[:space:]' \
      | sed "s/^['\"]//; s/['\"]$//") \
      || deny_response "No default_host in Runlayer config"
    [[ -z "$RUNLAYER_API_HOST" ]] && deny_response "No default_host in Runlayer config"

    local_host=$(echo "$RUNLAYER_API_HOST" | tr '[:upper:]' '[:lower:]')
    host_key=$(echo "$local_host" | sed -E 's|^https?://||' | sed 's|/.*||')
    [[ "$local_host" == https://* ]] && host_key=$(echo "$host_key" | sed 's|:443$||')
    [[ "$local_host" == http://* ]] && host_key=$(echo "$host_key" | sed 's|:80$||')
    RUNLAYER_API_KEY=$(awk -v host="  ${host_key}:" '
      $0 == host { found=1; next }
      found && /^[[:space:]]*secret:/ { sub(/^[[:space:]]*secret:[[:space:]]*/, ""); gsub(/^[\x27"]|[\x27"]$/, ""); print; exit }
      found && /^  [^ ]/ { exit }
    ' "$CONFIG_FILE") || deny_response "Failed to read API key from config"
    [[ -z "$RUNLAYER_API_KEY" ]] && deny_response "No API key for ${host_key} in Runlayer config"

    if echo "$input" | jq -e '.tool_input | type == "object"' > /dev/null 2>&1; then
      input=$(echo "$input" | jq '.tool_input = (.tool_input | tojson)') || deny_response "Failed to transform tool_input"
    fi

    response=$(curl -sf --max-time 30 -X POST "${RUNLAYER_API_HOST}/api/v1/hooks/cursor" \
      -H "Content-Type: application/json" \
      -H "x-runlayer-api-key: ${RUNLAYER_API_KEY}" \
      -d "$input" 2>/dev/null) || deny_response "Failed to contact Runlayer API"

    if ! echo "$response" | jq -e 'has("permission")' > /dev/null 2>&1; then
      deny_response "Invalid response from Runlayer API"
    fi

    echo "$response"
    ;;

  beforeReadFile)
    file_path=$(echo "$input" | jq -r '.file_path // empty') || deny_response "Failed to parse file path"
    basename=$(basename "$file_path")

    case "$basename" in
      .env|.env.*)
        deny_response "Runlayer: access to environment files is restricted"
        ;;
      mcp.json|mcp_config.json|.mcp.json)
        deny_response "Runlayer: access to MCP configuration files is restricted"
        ;;
    esac

    echo '{"permission":"allow"}'
    ;;

  *)
    echo "{}"
    ;;
esac
