# POC — Agents IA pilotés par tickets Azure DevOps

Application Blazor + API implémentée automatiquement par des agents Claude
Code déclenchés à la création de tickets Azure DevOps (architecture
Planner → Backend → Frontend → Reviewer-Fixer, voir `pipelines/agent-run.yml`).

## Structure

- `src/Api` — Web API ASP.NET Core (.NET 10), endpoint `GET /api/items`.
- `src/BlazorApp` — Blazor Web App (.NET 10, render mode Server), consomme l'API.
- `tests/Api.Tests` — tests xUnit de l'API.
- `infra/main.bicep` — Resource Group App Service (2 apps) + Application Insights.
- `pipelines/` — pipelines Azure DevOps (`ci.yml`, `cd.yml`, `agent-run.yml`).
- `tools/agent-prompts/` — prompts système des agents (Planner, Backend, Frontend, Reviewer-Fixer).
- `tools/agent-scripts/` — scripts bash orchestrant les agents dans `agent-run.yml`.
- `tools/agent-webhook/` — Azure Function (isolated worker, .NET 8) qui reçoit le Service Hook Azure DevOps et déclenche `agent-run.yml`.

## Lancer l'application en local

```bash
dotnet run --project src/Api
dotnet run --project src/BlazorApp
```

Le Blazor App (`https://localhost:7070`) appelle l'API (`https://localhost:7082`)
via `ApiBaseUrl` (voir `appsettings.Development.json`). Page de démo : `/items`.

```bash
dotnet test
```

## Mise en place Azure DevOps

1. **Projet et dépôt** : créer un projet Azure DevOps, pousser ce dépôt dans
   Azure Repos (`git remote add origin <url>` puis `git push -u origin main`).
2. **PAT** : créer un Personal Access Token avec les scopes Work Items
   (Read & Write), Code (Read & Write), Build (Read & Execute).
3. **Convention de tag** : seuls les work items portant le tag `agent-ready`
   déclenchent l'automatisation (évite de lancer un agent sur chaque ticket).
4. **Branch policy sur `main`** : exiger la réussite de `ci.yml` + au moins
   un reviewer avant de pouvoir merger une PR.
5. **Variable group `agents-secrets`** (Pipelines → Library) contenant en
   secret : `ANTHROPIC_API_KEY`, `AZURE_DEVOPS_PAT` (le PAT créé ci-dessus).
6. **Pipelines** à créer dans Azure DevOps à partir des fichiers YAML :
   - `pipelines/ci.yml` (trigger PR)
   - `pipelines/cd.yml` (trigger sur `main`, nécessite la Service Connection Azure ci-dessous)
   - `pipelines/agent-run.yml` (pas de trigger, exécutée via API — noter son `pipelineId`)
   - Adapter dans `agent-run.yml` : `AZURE_DEVOPS_ORG_URL`, `AZURE_DEVOPS_PROJECT`, `AZURE_DEVOPS_REPOSITORY`.
7. **Service Connection Azure** (Project Settings → Service connections) de
   type ARM, utilisée par `cd.yml`. Nom attendu : `jalex-agents-poc-azure`
   (ou adapter la variable `azureServiceConnection` dans `cd.yml`).

## Provisionner l'infra Azure (une fois)

```bash
az group create -n rg-jalex-agents-poc -l westeurope
az deployment group create -g rg-jalex-agents-poc -f infra/main.bicep
```

Note les URLs de sortie (`apiUrl`, `blazorUrl`) et mets à jour si besoin
`AllowedOrigins` (Api) / `ApiBaseUrl` (BlazorApp) dans `infra/main.bicep`
si tu changes les noms d'App Service.

## Déployer l'Azure Function webhook

```bash
az group create -n rg-jalex-agents-webhook -l westeurope
az storage account create -n stjalexwebhook -g rg-jalex-agents-webhook -l westeurope --sku Standard_LRS
az functionapp create -g rg-jalex-agents-webhook --consumption-plan-location westeurope \
  --runtime dotnet-isolated --functions-version 4 --name func-jalex-agent-webhook \
  --storage-account stjalexwebhook

func azure functionapp publish func-jalex-agent-webhook --dotnet-isolated
```

Configurer les App Settings (Azure Portal ou `az functionapp config appsettings set`) :
`AzureDevOpsOrgUrl`, `AzureDevOpsProject`, `AzureDevOpsPat` (via Key Vault
reference de préférence), `AgentRunPipelineId` (id numérique de la pipeline
`agent-run.yml` dans Azure DevOps), `WebhookSharedSecret` (valeur secrète
que le Service Hook devra envoyer dans l'en-tête `X-Webhook-Secret`).

## Configurer le Service Hook Azure DevOps

Project Settings → Service Hooks → nouvelle souscription :

- Événement déclencheur : **Work item created**.
- Action : **Web Hook**, URL = URL de la Function (`.../api/workitem-created?code=<function-key>`).
- Ajouter l'en-tête `X-Webhook-Secret: <WebhookSharedSecret>` dans la configuration du Web Hook (section "Detailed").

## Test de bout en bout

1. Créer un ticket Feature avec le tag `agent-ready`, description claire.
2. Vérifier dans Azure DevOps → Pipelines qu'un run de `agent-run.yml` démarre.
3. À la fin du run : une PR liée au ticket doit apparaître (ou un commentaire d'échec sur le ticket après 3 tentatives de correction infructueuses).
4. Merger la PR → vérifier que `cd.yml` se déclenche et que les deux App Services sont à jour.

## Notes

- Les flags exacts de la CLI `claude` (`--allowedTools`, `--permission-mode`,
  `--output-format`) sont à vérifier avec `claude --help` selon la version
  installée sur les agents de build — ils sont susceptibles d'évoluer.
- `tools/agent-webhook` cible `net8.0` (LTS) car c'est la version .NET
  supportée par Azure Functions ; le reste de la solution cible `net10.0`.
