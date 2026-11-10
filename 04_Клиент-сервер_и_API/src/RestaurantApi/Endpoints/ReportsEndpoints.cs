using RestaurantApi.Services;

namespace RestaurantApi.Endpoints;

public static class ReportsEndpoints
{
    public static IEndpointRouteBuilder MapReportsEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/reports/{**path}", async (
            string path,
            HttpContext context,
            ReportsClient reportsClient,
            CancellationToken cancellationToken) =>
        {
            var query = context.Request.QueryString.HasValue
                ? context.Request.QueryString.Value
                : string.Empty;
            var (status, body, contentType) = await reportsClient.GetAsync(
                $"/api/reports/{path}{query}", cancellationToken);
            return Results.Text(body, contentType, statusCode: status);
        }).RequireAuthorization("ManagerOrDirector").WithTags("Отчёты");

        return app;
    }
}
