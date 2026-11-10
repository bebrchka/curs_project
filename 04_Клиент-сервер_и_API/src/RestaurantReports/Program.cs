using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.SqlClient;
using RestaurantReports;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<ReportsRepository>();

var serviceKey = builder.Configuration["ServiceKey"]
    ?? throw new InvalidOperationException("Не задан ServiceKey");

var app = builder.Build();

app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";

    if (context.Request.Path.StartsWithSegments("/api/reports"))
    {
        var provided = context.Request.Headers["X-Service-Key"].ToString();
        if (!FixedTimeEquals(provided, serviceKey))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new
            {
                error = "INVALID_SERVICE_KEY",
                message = "Неверный ключ сервиса отчётности"
            });
            return;
        }
    }

    await next();
});

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "RestaurantReports" }))
    .AllowAnonymous();

app.MapGet("/api/reports/dashboard", async (
    DateTime? from,
    DateTime? to,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
    Results.Ok(await repository.GetDashboardAsync(from, to, cancellationToken)));

app.MapGet("/api/reports/revenue", async (
    DateTime? from,
    DateTime? to,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
    Results.Ok(await repository.GetRevenueAsync(from, to, cancellationToken)));

app.MapGet("/api/reports/popular-dishes", async (
    DateTime? from,
    DateTime? to,
    int? top,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
    Results.Ok(await repository.GetPopularDishesAsync(from, to, top ?? 10, cancellationToken)));

app.MapGet("/api/reports/waiters", async (
    DateTime? from,
    DateTime? to,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
    Results.Ok(await repository.GetWaitersAsync(from, to, cancellationToken)));

app.MapGet("/api/reports/table-load", async (
    DateTime? from,
    DateTime? to,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
    Results.Ok(await repository.GetTableLoadAsync(from, to, cancellationToken)));

app.MapGet("/api/reports/hourly", async (
    DateTime? from,
    DateTime? to,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
    Results.Ok(await repository.GetHourlyAsync(from, to, cancellationToken)));

app.MapGet("/api/reports/reservations", async (
    DateTime? from,
    DateTime? to,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
    Results.Ok(await repository.GetReservationsAsync(from, to, cancellationToken)));

app.MapGet("/api/reports/order-status", async (
    DateTime? from,
    DateTime? to,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
    Results.Ok(await repository.GetOrderStatusAsync(from, to, cancellationToken)));

app.MapGet("/api/reports/export/{report}.csv", async (
    string report,
    DateTime? from,
    DateTime? to,
    ReportsRepository repository,
    CancellationToken cancellationToken) =>
{
    try
    {
        var csv = await repository.ExportCsvAsync(report, from, to, cancellationToken);
        var preamble = Encoding.UTF8.GetPreamble();
        var body = Encoding.UTF8.GetBytes(csv);
        var bytes = new byte[preamble.Length + body.Length];
        preamble.CopyTo(bytes, 0);
        body.CopyTo(bytes, preamble.Length);
        return Results.File(bytes, "text/csv; charset=utf-8", $"{report}.csv");
    }
    catch (ArgumentException exception)
    {
        return Results.BadRequest(new { error = "UNKNOWN_REPORT", message = exception.Message });
    }
});

app.MapGet("/api/health/db", async (
    IConfiguration configuration,
    CancellationToken cancellationToken) =>
{
    var connectionString = configuration.GetConnectionString("RestaurantDB_ReadOnly")
        ?? configuration.GetConnectionString("RestaurantDB");
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync(cancellationToken);
    await using var command = new SqlCommand("SELECT 1", connection);
    await command.ExecuteScalarAsync(cancellationToken);
    return Results.Ok(new { status = "ok", database = "RestaurantDB" });
}).AllowAnonymous();

app.Run();

static bool FixedTimeEquals(string provided, string expected)
{
    var left = Encoding.UTF8.GetBytes(provided);
    var right = Encoding.UTF8.GetBytes(expected);
    return left.Length == right.Length &&
           CryptographicOperations.FixedTimeEquals(left, right);
}
