#!/usr/bin/env bash
# Exécute un agent spécialisé (backend ou frontend) sur les tâches issues de plan.json,
# puis vérifie que seuls les fichiers de son périmètre ont été modifiés.
# Usage: run-scoped-agent.sh <backend|frontend>
set -euo pipefail
ROLE="${1:?Usage: run-scoped-agent.sh <backend|frontend>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${SCRIPT_DIR}/../agent-prompts"

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required}"

case "$ROLE" in
  backend)
    TASKS_KEY="backendTasks"
    ALLOWED_PATHS_REGEX='^(src/Api/|tests/Api\.Tests/)'
    ;;
  frontend)
    TASKS_KEY="frontendTasks"
    ALLOWED_PATHS_REGEX='^src/BlazorApp/'
    ;;
  *)
    echo "Rôle inconnu: $ROLE (attendu: backend|frontend)" >&2
    exit 1
    ;;
esac

TASKS=$(python3 -c "
import json
with open('plan.json', encoding='utf-8') as f:
    plan = json.load(f)
tasks = plan.get('$TASKS_KEY', [])
print('\n'.join(f'- {t}' for t in tasks))
")

if [[ -z "$TASKS" ]]; then
  echo "Aucune tâche $TASKS_KEY dans le plan, agent $ROLE ignoré."
  exit 0
fi

WORKITEM_CONTEXT=$(python3 -c "
import json
with open('workitem.json', encoding='utf-8') as f:
    wi = json.load(f)
print(f\"## Ticket #{wi['id']} ({wi['type']}) — {wi['title']}\")
")

FULL_PROMPT="$(cat "${PROMPTS_DIR}/${ROLE}.md")

---

${WORKITEM_CONTEXT}

## Tâches à implémenter

${TASKS}"

git status --porcelain > "before-${ROLE}.txt"

# NOTE: vérifier les flags exacts avec `claude --help` pour la version installée.
claude -p "$FULL_PROMPT" \
  --output-format json \
  --allowedTools "Read,Edit,Write,Bash(dotnet *),Bash(git status)" \
  --permission-mode acceptEdits \
  > "${ROLE}-raw-output.json"

git status --porcelain > "after-${ROLE}.txt"

CHANGED_FILES=$(comm -13 <(sort "before-${ROLE}.txt") <(sort "after-${ROLE}.txt") | awk '{print $2}')
OUT_OF_SCOPE=$(echo "$CHANGED_FILES" | grep -vE "$ALLOWED_PATHS_REGEX" || true)

if [[ -n "$OUT_OF_SCOPE" ]]; then
  echo "L'agent $ROLE a modifié des fichiers hors de son périmètre, annulation :" >&2
  echo "$OUT_OF_SCOPE" >&2
  echo "$OUT_OF_SCOPE" | xargs -r git checkout --
  echo "$OUT_OF_SCOPE" | xargs -r git clean -f --
  exit 1
fi

echo "Agent $ROLE terminé, fichiers modifiés :"
echo "$CHANGED_FILES"
