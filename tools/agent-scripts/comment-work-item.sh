#!/usr/bin/env bash
# Ajoute un commentaire au work item déclencheur.
# Usage: comment-work-item.sh <fichier-texte-du-commentaire>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

COMMENT_FILE="${1:?Usage: comment-work-item.sh <fichier-texte-du-commentaire>}"

python3 -c "import json,sys; print(json.dumps({'text': open(sys.argv[1], encoding='utf-8').read()}))" \
  "$COMMENT_FILE" > comment-body.json

ado_api POST \
  "/${AZURE_DEVOPS_PROJECT}/_apis/wit/workItems/${WORK_ITEM_ID}/comments?api-version=${ADO_API_VERSION}-preview.3" \
  comment-body.json > /dev/null

echo "Commentaire ajouté au work item ${WORK_ITEM_ID}."
