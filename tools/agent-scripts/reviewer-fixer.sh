#!/usr/bin/env bash
# Boucle build/test + correction automatique via l'agent Reviewer-Fixer.
# Sort avec le code 0 si build+tests finissent par passer, 1 sinon (après MAX_ATTEMPTS).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${SCRIPT_DIR}/../agent-prompts"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required}"

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "=== Reviewer-Fixer : tentative de build/test $attempt/$MAX_ATTEMPTS ==="

  if dotnet build --configuration Release > build-output.txt 2>&1 \
      && dotnet test --configuration Release --no-build > test-output.txt 2>&1; then
    echo "Build et tests OK."
    exit 0
  fi

  echo "Échec détecté, appel de l'agent Reviewer-Fixer (tentative $attempt)."

  ERROR_OUTPUT=$(tail -c 8000 build-output.txt test-output.txt 2>/dev/null || true)

  FULL_PROMPT="$(cat "${PROMPTS_DIR}/reviewer-fixer.md")

---

## Sortie d'erreur (tentative ${attempt}/${MAX_ATTEMPTS})

\`\`\`
${ERROR_OUTPUT}
\`\`\`"

  # NOTE: vérifier les flags exacts avec `claude --help` pour la version installée.
  claude -p "$FULL_PROMPT" \
    --output-format json \
    --allowedTools "Read,Edit,Write,Bash(dotnet *)" \
    --permission-mode acceptEdits \
    > "reviewer-fixer-attempt-${attempt}.json"
done

echo "Abandon après $MAX_ATTEMPTS tentatives de correction automatique." >&2
exit 1
