#!/usr/bin/env bash
# Récupère titre, description et critères d'acceptation du work item déclencheur
# et les écrit dans workitem.json (répertoire courant).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ado_api GET "/${AZURE_DEVOPS_PROJECT}/_apis/wit/workitems/${WORK_ITEM_ID}?\$expand=all&api-version=${ADO_API_VERSION}" \
  > raw-workitem.json

python3 - <<'PY'
import json

with open("raw-workitem.json", encoding="utf-8") as f:
    raw = json.load(f)

fields = raw.get("fields", {})
workitem = {
    "id": raw["id"],
    "type": fields.get("System.WorkItemType", ""),
    "title": fields.get("System.Title", ""),
    "description": fields.get("System.Description", ""),
    "acceptanceCriteria": fields.get("Microsoft.VSTS.Common.AcceptanceCriteria", ""),
    "tags": fields.get("System.Tags", ""),
}

with open("workitem.json", "w", encoding="utf-8") as f:
    json.dump(workitem, f, ensure_ascii=False, indent=2)
PY

echo "Work item ${WORK_ITEM_ID} écrit dans workitem.json"
