#!/usr/bin/env bash
# Crée la Pull Request pour la branche de l'agent et la lie au work item.
# Nécessite en plus de common.sh : AZURE_DEVOPS_REPOSITORY, SOURCE_BRANCH.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

: "${AZURE_DEVOPS_REPOSITORY:?AZURE_DEVOPS_REPOSITORY is required}"
: "${SOURCE_BRANCH:?SOURCE_BRANCH is required}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"

SUMMARY=$(python3 -c "
import json
with open('plan.json', encoding='utf-8') as f:
    print(json.load(f).get('summary', ''))
")
TITLE=$(python3 -c "
import json
with open('workitem.json', encoding='utf-8') as f:
    wi = json.load(f)
print(f\"[Agent] #{wi['id']} {wi['title']}\")
")

cat > pr-body.json <<EOF
{
  "sourceRefName": "refs/heads/${SOURCE_BRANCH}",
  "targetRefName": "refs/heads/${TARGET_BRANCH}",
  "title": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$TITLE"),
  "description": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "Généré automatiquement par les agents (Planner/Backend/Frontend/Reviewer-Fixer).

${SUMMARY}

Résout le ticket #${WORK_ITEM_ID}.")
}
EOF

PR_RESPONSE=$(ado_api POST \
  "/${AZURE_DEVOPS_PROJECT}/_apis/git/repositories/${AZURE_DEVOPS_REPOSITORY}/pullrequests?api-version=${ADO_API_VERSION}" \
  pr-body.json)

echo "$PR_RESPONSE" > pr-response.json
PR_ID=$(python3 -c "import json; print(json.load(open('pr-response.json', encoding='utf-8'))['pullRequestId'])")
echo "Pull Request créée : #${PR_ID}"

# Lie la PR au work item.
ado_api PUT \
  "/${AZURE_DEVOPS_PROJECT}/_apis/git/repositories/${AZURE_DEVOPS_REPOSITORY}/pullrequests/${PR_ID}/workitems/${WORK_ITEM_ID}?api-version=${ADO_API_VERSION}-preview.1" \
  <(echo '{}') > /dev/null

echo "$PR_ID" > pr-id.txt
