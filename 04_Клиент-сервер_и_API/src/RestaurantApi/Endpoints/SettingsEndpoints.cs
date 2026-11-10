using System.Security.Claims;
using RestaurantApi.Data;
using RestaurantApi.Models;
using RestaurantApi.Services;

namespace RestaurantApi.Endpoints;

public static class SettingsEndpoints
{
    public static IEndpointRouteBuilder MapSettingsEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/settings").WithTags("Настройки пользователя").RequireAuthorization();

        group.MapGet("/", async (
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
            Results.Ok(await repository.GetUserSettingsAsync(principal.GetUserId(), cancellationToken)));

        group.MapPut("/", async (
            UserSettingDto request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            if (request.Theme is not ("light" or "dark" or "system"))
                throw new ApiException("VALIDATION", "Тема: light, dark или system", StatusCodes.Status400BadRequest);
            if (request.PageSize is < 5 or > 100)
                throw new ApiException("VALIDATION", "Размер страницы должен быть от 5 до 100",
                    StatusCodes.Status400BadRequest);
            if (string.IsNullOrWhiteSpace(request.DateFormat) || string.IsNullOrWhiteSpace(request.NumberFormat))
                throw new ApiException("VALIDATION", "Форматы даты и числа обязательны", StatusCodes.Status400BadRequest);

            await repository.SaveUserSettingsAsync(principal.GetUserId(), request, cancellationToken);
            return Results.Ok(new { message = "Настройки сохранены" });
        });

        return app;
    }
}
