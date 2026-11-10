using System.Data;
using Microsoft.Data.SqlClient;

namespace RestaurantReports;

public sealed class ReportsRepository
{
    private readonly string _connectionString;

    public ReportsRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("RestaurantDB_ReadOnly")
            ?? configuration.GetConnectionString("RestaurantDB")
            ?? throw new InvalidOperationException("Не задана строка подключения для отчётов");
    }

    public async Task<Dictionary<string, object?>> GetDashboardAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken)
    {
        var sets = await QueryMultipleAsync(
            "dbo.sp_Report_Dashboard",
            cancellationToken,
            new SqlParameter("@DateFrom", (object?)dateFrom?.Date ?? DBNull.Value),
            new SqlParameter("@DateTo", (object?)dateTo?.Date ?? DBNull.Value));

        return new Dictionary<string, object?>
        {
            ["summary"] = sets.ElementAtOrDefault(0)?.FirstOrDefault() ?? new Dictionary<string, object?>(),
            ["revenue"] = sets.ElementAtOrDefault(1) ?? [],
            ["popularDishes"] = sets.ElementAtOrDefault(2) ?? [],
            ["waiters"] = sets.ElementAtOrDefault(3) ?? [],
            ["tableLoad"] = sets.ElementAtOrDefault(4) ?? [],
            ["hourly"] = sets.ElementAtOrDefault(5) ?? []
        };
    }

    public Task<List<Dictionary<string, object?>>> GetRevenueAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_Report_Revenue", cancellationToken, DateParameters(dateFrom, dateTo));

    public Task<List<Dictionary<string, object?>>> GetPopularDishesAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        int top,
        CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_Report_PopularDishes", cancellationToken,
            DateParameters(dateFrom, dateTo).Append(new SqlParameter("@Top", top)).ToArray());

    public Task<List<Dictionary<string, object?>>> GetWaitersAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_Report_WaiterPerformance", cancellationToken, DateParameters(dateFrom, dateTo));

    public Task<List<Dictionary<string, object?>>> GetTableLoadAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_Report_TableLoad", cancellationToken, DateParameters(dateFrom, dateTo));

    public Task<List<Dictionary<string, object?>>> GetHourlyAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_Report_HourlyLoad", cancellationToken, DateParameters(dateFrom, dateTo));

    public Task<List<Dictionary<string, object?>>> GetReservationsAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_Report_ReservationStats", cancellationToken, DateParameters(dateFrom, dateTo));

    public Task<List<Dictionary<string, object?>>> GetOrderStatusAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_Report_OrderStatusSummary", cancellationToken, DateParameters(dateFrom, dateTo));

    public async Task<string> ExportCsvAsync(
        string report,
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken)
    {
        var (procedure, parameters) = report switch
        {
            "revenue" => ("dbo.sp_Report_Revenue", DateParameters(dateFrom, dateTo)),
            "popular-dishes" => ("dbo.sp_Report_PopularDishes", DateParameters(dateFrom, dateTo)),
            "waiters" => ("dbo.sp_Report_WaiterPerformance", DateParameters(dateFrom, dateTo)),
            "table-load" => ("dbo.sp_Report_TableLoad", DateParameters(dateFrom, dateTo)),
            "hourly" => ("dbo.sp_Report_HourlyLoad", DateParameters(dateFrom, dateTo)),
            "reservations" => ("dbo.sp_Report_ReservationStats", DateParameters(dateFrom, dateTo)),
            "order-status" => ("dbo.sp_Report_OrderStatusSummary", DateParameters(dateFrom, dateTo)),
            _ => throw new ArgumentException("Неизвестный отчёт", nameof(report))
        };

        var rows = await QueryAsync(procedure, cancellationToken, parameters);
        return BuildCsv(rows);
    }

    private async Task<List<Dictionary<string, object?>>> QueryAsync(
        string procedure,
        CancellationToken cancellationToken,
        params SqlParameter[] parameters)
    {
        var sets = await QueryMultipleAsync(procedure, cancellationToken, parameters);
        return sets.FirstOrDefault() ?? [];
    }

    private async Task<List<List<Dictionary<string, object?>>>> QueryMultipleAsync(
        string procedure,
        CancellationToken cancellationToken,
        params SqlParameter[] parameters)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(procedure, connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        if (parameters.Length > 0)
            command.Parameters.AddRange(parameters);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var sets = new List<List<Dictionary<string, object?>>>();
        do
        {
            var rows = new List<Dictionary<string, object?>>();
            while (await reader.ReadAsync(cancellationToken))
            {
                var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                for (var i = 0; i < reader.FieldCount; i++)
                    row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                rows.Add(row);
            }
            sets.Add(rows);
        } while (await reader.NextResultAsync(cancellationToken));

        return sets;
    }

    private static SqlParameter[] DateParameters(DateTime? dateFrom, DateTime? dateTo) =>
    [
        new SqlParameter("@DateFrom", (object?)dateFrom?.Date ?? DBNull.Value),
        new SqlParameter("@DateTo", (object?)dateTo?.Date ?? DBNull.Value)
    ];

    private static string BuildCsv(List<Dictionary<string, object?>> rows)
    {
        if (rows.Count == 0)
            return string.Empty;

        var headers = rows[0].Keys.ToList();
        var builder = new System.Text.StringBuilder();
        builder.AppendLine(string.Join(';', headers.Select(Escape)));
        foreach (var row in rows)
            builder.AppendLine(string.Join(';', headers.Select(header =>
                Escape(row.TryGetValue(header, out var value) ? Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture) : null))));
        return builder.ToString();
    }

    private static string Escape(string? value)
    {
        if (string.IsNullOrEmpty(value))
            return string.Empty;
        if (value.Contains(';') || value.Contains('"') || value.Contains('\n') || value.Contains('\r'))
            return $"\"{value.Replace("\"", "\"\"")}\"";
        return value;
    }
}
