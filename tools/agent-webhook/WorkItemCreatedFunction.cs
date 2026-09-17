using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace AgentWebhook;

// Reçoit l'événement Azure DevOps "Work item created" (Service Hook -> Web Hook)
// et, si le ticket porte le tag configuré (par défaut "agent-ready"), déclenche
// la pipeline "agent-run" avec le workItemId en paramètre de template.
public class WorkItemCreatedFunction(IHttpClientFactory httpClientFactory, IConfiguration configuration, ILogger<WorkItemCreatedFunction> logger)
{
    [Function("WorkItemCreated")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "workitem-created")] HttpRequestData req,
        CancellationToken cancellationToken)
    {
        var expectedSecret = configuration["WebhookSharedSecret"];
        if (!string.IsNullOrEmpty(expectedSecret) && !IsAuthorized(req, expectedSecret))
        {
            logger.LogWarning("Requête webhook rejetée : secret partagé invalide ou manquant.");
            return req.CreateResponse(HttpStatusCode.Unauthorized);
        }

        var body = await req.ReadAsStringAsync() ?? string.Empty;
        ServiceHookPayload? payload;
        try
        {
            payload = JsonSerializer.Deserialize<ServiceHookPayload>(body, JsonOptions);
        }
        catch (JsonException ex)
        {
            logger.LogError(ex, "Payload de service hook invalide.");
            return req.CreateResponse(HttpStatusCode.BadRequest);
        }

        var workItemId = payload?.Resource?.Id;
        var tags = payload?.Resource?.Fields?.Tags ?? string.Empty;
        var agentReadyTag = configuration["AgentReadyTag"] ?? "agent-ready";

        if (workItemId is null)
        {
            logger.LogWarning("Payload sans workItemId, ignoré.");
            return req.CreateResponse(HttpStatusCode.BadRequest);
        }

        var hasAgentReadyTag = tags
            .Split(';', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .Any(tag => string.Equals(tag, agentReadyTag, StringComparison.OrdinalIgnoreCase));

        if (!hasAgentReadyTag)
        {
            logger.LogInformation("Work item {WorkItemId} sans le tag '{Tag}', aucune action.", workItemId, agentReadyTag);
            return req.CreateResponse(HttpStatusCode.NoContent);
        }

        await QueueAgentRunPipelineAsync(workItemId.Value, cancellationToken);

        var response = req.CreateResponse(HttpStatusCode.Accepted);
        await response.WriteStringAsync($"Pipeline agent-run déclenchée pour le work item {workItemId}.", cancellationToken);
        return response;
    }

    private static bool IsAuthorized(HttpRequestData req, string expectedSecret)
    {
        return req.Headers.TryGetValues("X-Webhook-Secret", out var values)
            && values.Contains(expectedSecret);
    }

    private async Task QueueAgentRunPipelineAsync(int workItemId, CancellationToken cancellationToken)
    {
        var orgUrl = configuration["AzureDevOpsOrgUrl"]!.TrimEnd('/');
        var project = configuration["AzureDevOpsProject"];
        var pat = configuration["AzureDevOpsPat"];
        var pipelineId = configuration["AgentRunPipelineId"];

        var client = httpClientFactory.CreateClient();
        var authToken = Convert.ToBase64String(Encoding.ASCII.GetBytes($":{pat}"));
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Basic", authToken);

        var requestBody = new
        {
            templateParameters = new Dictionary<string, string>
            {
                ["workItemId"] = workItemId.ToString()
            }
        };

        var url = $"{orgUrl}/{project}/_apis/pipelines/{pipelineId}/runs?api-version=7.1";
        var response = await client.PostAsJsonAsync(url, requestBody, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
            logger.LogError(
                "Échec du déclenchement de la pipeline agent-run pour le work item {WorkItemId} : {StatusCode} {Body}",
                workItemId, response.StatusCode, errorBody);
            throw new InvalidOperationException($"Échec du déclenchement de la pipeline : {response.StatusCode}");
        }

        logger.LogInformation("Pipeline agent-run déclenchée pour le work item {WorkItemId}.", workItemId);
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private class ServiceHookPayload
    {
        [JsonPropertyName("resource")]
        public ResourcePayload? Resource { get; set; }
    }

    private class ResourcePayload
    {
        [JsonPropertyName("id")]
        public int? Id { get; set; }

        [JsonPropertyName("fields")]
        public FieldsPayload? Fields { get; set; }
    }

    private class FieldsPayload
    {
        [JsonPropertyName("System.Tags")]
        public string? Tags { get; set; }
    }
}
