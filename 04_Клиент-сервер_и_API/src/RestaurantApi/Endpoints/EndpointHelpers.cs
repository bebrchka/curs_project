using System.Security.Claims;
using RestaurantApi.Services;

namespace RestaurantApi.Endpoints;

public static class EndpointHelpers
{
    public static int GetUserId(this ClaimsPrincipal user) =>
        int.TryParse(user.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
            ? id
            : throw new ApiException("UNAUTHORIZED", "Требуется авторизация", StatusCodes.Status401Unauthorized);

    public static string GetLogin(this ClaimsPrincipal user) =>
        user.FindFirstValue(ClaimTypes.Name) ?? "anonymous";

    public static int? GetEmployeeId(this ClaimsPrincipal user) =>
        int.TryParse(user.FindFirstValue("employeeId"), out var id) ? id : null;

    public static string? GetIp(this HttpContext context) =>
        context.Connection.RemoteIpAddress?.ToString();

    public static void Ensure(
        bool condition,
        string message,
        string code = "VALIDATION")
    {
        if (!condition)
            throw new ApiException(code, message, StatusCodes.Status400BadRequest);
    }
}
