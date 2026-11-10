using System.Data;
using Microsoft.Data.SqlClient;

namespace RestaurantApi.Data;

public static class SqlHelper
{
    public static SqlParameter P(string name, object? value) =>
        new(name, value ?? DBNull.Value);

    public static async Task<List<T>> QueryAsync<T>(
        SqlConnection connection,
        string sql,
        Func<SqlDataReader, T> map,
        CancellationToken cancellationToken,
        CommandType commandType = CommandType.Text,
        params SqlParameter[] parameters)
    {
        await using var command = new SqlCommand(sql, connection) { CommandType = commandType };
        if (parameters.Length > 0)
            command.Parameters.AddRange(parameters);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<T>();
        while (await reader.ReadAsync(cancellationToken))
            result.Add(map(reader));
        return result;
    }

    public static async Task<T?> ScalarAsync<T>(
        SqlConnection connection,
        string sql,
        CancellationToken cancellationToken,
        CommandType commandType = CommandType.Text,
        params SqlParameter[] parameters)
    {
        await using var command = new SqlCommand(sql, connection) { CommandType = commandType };
        if (parameters.Length > 0)
            command.Parameters.AddRange(parameters);

        var value = await command.ExecuteScalarAsync(cancellationToken);
        if (value is null || value is DBNull)
            return default;
        return (T)Convert.ChangeType(value, typeof(T));
    }

    public static async Task<int> ExecuteAsync(
        SqlConnection connection,
        string sql,
        CancellationToken cancellationToken,
        CommandType commandType = CommandType.Text,
        params SqlParameter[] parameters)
    {
        await using var command = new SqlCommand(sql, connection) { CommandType = commandType };
        if (parameters.Length > 0)
            command.Parameters.AddRange(parameters);

        return await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public static string? GetNullableString(SqlDataReader reader, string name)
    {
        var index = reader.GetOrdinal(name);
        return reader.IsDBNull(index) ? null : reader.GetString(index);
    }

    public static int? GetNullableInt(SqlDataReader reader, string name)
    {
        var index = reader.GetOrdinal(name);
        return reader.IsDBNull(index) ? null : reader.GetInt32(index);
    }

    public static decimal? GetNullableDecimal(SqlDataReader reader, string name)
    {
        var index = reader.GetOrdinal(name);
        return reader.IsDBNull(index) ? null : reader.GetDecimal(index);
    }

    public static DateTime? GetNullableDateTime(SqlDataReader reader, string name)
    {
        var index = reader.GetOrdinal(name);
        return reader.IsDBNull(index) ? null : reader.GetDateTime(index);
    }
}
