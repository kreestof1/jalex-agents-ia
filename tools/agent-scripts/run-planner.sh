#!/usr/bin/env bash
# Exécute l'agent Planner en mode headless et produit plan.json (répertoire courant).
# Nécessite : workitem.json (voir get-work-item.sh), ANTHROPIC_API_KEY, claude CLI installé.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${SCRIPT_DIR}/../agent-prompts"

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required}"

WORKITEM_CONTEXT=$(python3 -c "
import json
with open('workitem.json', encoding='utf-8') as f:
    wi = json.load(f)
print(f\"## Ticket #{wi['id']} ({wi['type']})\n\nTitre: {wi['title']}\n\nDescription:\n{wi['description']}\n\nCriteres d'acceptation:\n{wi['acceptanceCriteria']}\")
")

FULL_PROMPT="$(cat "${PROMPTS_DIR}/planner.md")

---

${WORKITEM_CONTEXT}"

echo "$FULL_PROMPT" > planner-prompt.txt

# NOTE: vérifier les flags exacts avec `claude --help` pour la version installée.
claude -p "$(cat planner-prompt.txt)" \
  --output-format json \
  --allowedTools "Read" \
  --permission-mode plan \
  > planner-raw-output.json

python3 - <<'PY'
import json

with open("planner-raw-output.json", encoding="utf-8") as f:
    raw = json.load(f)

result_text = raw["result"]
# Le planner doit répondre avec un JSON pur ; on tolère un fencing ```json ... ```.
result_text = result_text.strip()
if result_text.startswith("```"):
    result_text = result_text.split("```")[1]
    if result_text.startswith("json"):
        result_text = result_text[len("json"):]

plan = json.loads(result_text)

required_keys = {"summary", "needsBackend", "needsFrontend", "backendTasks", "frontendTasks"}
missing = required_keys - plan.keys()
if missing:
    raise SystemExit(f"Plan invalide, clés manquantes: {missing}")

with open("plan.json", "w", encoding="utf-8") as f:
    json.dump(plan, f, ensure_ascii=False, indent=2)
PY

echo "Plan écrit dans plan.json :"
cat plan.json
