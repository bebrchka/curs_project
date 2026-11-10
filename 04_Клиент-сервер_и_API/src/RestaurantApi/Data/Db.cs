using Microsoft.Data.SqlClient;

namespace RestaurantApi.Data;

public sealed class Db
{
    private readonly string _connectionString;

    public Db(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("RestaurantDB")
            ?? throw new InvalidOperationException(
                "Не задана строка подключения ConnectionStrings:RestaurantDB");
    }

    public async Task<SqlConnection> OpenAsync(CancellationToken cancellationToken = default)
    {
        var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }
}
