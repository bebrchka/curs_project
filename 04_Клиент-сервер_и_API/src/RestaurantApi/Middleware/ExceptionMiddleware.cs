using Microsoft.Data.SqlClient;
using RestaurantApi.Services;

namespace RestaurantApi.Middleware;

public sealed class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _logger;

    public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (ApiException exception)
        {
            await WriteErrorAsync(context, exception.StatusCode, exception.Code, exception.Message);
        }
        catch (SqlException exception) when (exception.Number is >= 50000 and < 60000)
        {
            await WriteErrorAsync(context, StatusCodes.Status400BadRequest,
                $"SQL_{exception.Number}", exception.Message);
        }
        catch (SqlException exception)
        {
            _logger.LogError(exception, "Ошибка SQL Server");
            await WriteErrorAsync(context, StatusCodes.Status503ServiceUnavailable,
                "DATABASE_UNAVAILABLE",
                "База данных временно недоступна. Проверьте подключение к SQL Server.");
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Необработанная ошибка");
            await WriteErrorAsync(context, StatusCodes.Status500InternalServerError,
                "INTERNAL_ERROR", "Внутренняя ошибка сервера.");
        }
    }

    private static async Task WriteErrorAsync(
        HttpContext context,
        int statusCode,
        string code,
        string message)
    {
        if (context.Response.HasStarted)
            return;

        context.Response.Clear();
        context.Response.StatusCode = statusCode;
        await context.Response.WriteAsJsonAsync(new
        {
            error = code,
            message
        });
    }
}
