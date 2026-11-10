namespace RestaurantApi.Services;

public sealed class ReportsClient
{
    private readonly HttpClient _httpClient;

    public ReportsClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<(int StatusCode, string Body, string ContentType)> GetAsync(
        string pathAndQuery,
        CancellationToken cancellationToken)
    {
        try
        {
            using var response = await _httpClient.GetAsync(pathAndQuery, cancellationToken);
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            var contentType = response.Content.Headers.ContentType?.MediaType ?? "application/json";
            return ((int)response.StatusCode, body, contentType);
        }
        catch (HttpRequestException exception)
        {
            return (StatusCodes.Status503ServiceUnavailable,
                $"{{\"error\":\"REPORTS_UNAVAILABLE\",\"message\":\"Сервис отчётности недоступен: {exception.Message}\"}}",
                "application/json");
        }
    }
}
