using System.Net.Http.Json;
using BlazorApp.Models;

namespace BlazorApp.Services;

public class ItemsApiClient(HttpClient httpClient)
{
    public async Task<IReadOnlyList<Item>> GetItemsAsync(CancellationToken cancellationToken = default)
    {
        var items = await httpClient.GetFromJsonAsync<IReadOnlyList<Item>>("api/items", cancellationToken);
        return items ?? [];
    }

    public async Task<Item?> GetItemAsync(int id, CancellationToken cancellationToken = default)
    {
        var response = await httpClient.GetAsync($"api/items/{id}", cancellationToken);
        return response.IsSuccessStatusCode
            ? await response.Content.ReadFromJsonAsync<Item>(cancellationToken)
            : null;
    }
}
