#!/usr/bin/env bash
# Variables et fonctions partagées par les scripts d'orchestration des agents.
# Attendu en entrée (variables d'environnement définies par la pipeline) :
#   AZURE_DEVOPS_ORG_URL  ex: https://dev.azure.com/monorg
#   AZURE_DEVOPS_PROJECT  ex: jalex-agents-poc
#   AZURE_DEVOPS_PAT      Personal Access Token (Work Items R/W, Code R/W, Build R/W)
#   WORK_ITEM_ID          Id du ticket déclencheur
set -euo pipefail

: "${AZURE_DEVOPS_ORG_URL:?AZURE_DEVOPS_ORG_URL is required}"
: "${AZURE_DEVOPS_PROJECT:?AZURE_DEVOPS_PROJECT is required}"
: "${AZURE_DEVOPS_PAT:?AZURE_DEVOPS_PAT is required}"
: "${WORK_ITEM_ID:?WORK_ITEM_ID is required}"

ADO_API_VERSION="7.1"
ADO_AUTH_HEADER="Authorization: Basic $(printf '%s' ":${AZURE_DEVOPS_PAT}" | base64 -w0)"

ado_api() {
  # ado_api <method> <url-suffix-a-partir-de-org-url> [data-file]
  local method="$1"
  local url_suffix="$2"
  local data_file="${3:-}"
  local url="${AZURE_DEVOPS_ORG_URL}${url_suffix}"

  if [[ -n "$data_file" ]]; then
    curl -sS -f -X "$method" "$url" \
      -H "$ADO_AUTH_HEADER" \
      -H "Content-Type: application/json" \
      --data @"$data_file"
  else
    curl -sS -f -X "$method" "$url" -H "$ADO_AUTH_HEADER"
  fi
}
