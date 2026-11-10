using System.Security.Claims;
using RestaurantApi.Data;
using RestaurantApi.Models;
using RestaurantApi.Services;

namespace RestaurantApi.Endpoints;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Аутентификация");

        group.MapPost("/login", async (
            LoginRequest request,
            RestaurantRepository repository,
            PasswordHasher hasher,
            TokenService tokens,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var login = Validation.RequireString(request.Login, "Логин", 40);
            if (string.IsNullOrEmpty(request.Password))
                throw new ApiException("VALIDATION", "Пароль обязателен", StatusCodes.Status400BadRequest);

            var user = await repository.GetUserByLoginAsync(login, cancellationToken);
            if (user is null || !hasher.Verify(request.Password, user.PasswordHash, user.PasswordSalt))
            {
                await repository.WriteAuditAsync(null, login, "LOGIN_FAILED", "AppUser", null,
                    context.GetIp(), "Неверный логин или пароль", cancellationToken);
                throw new ApiException("INVALID_CREDENTIALS", "Неверный логин или пароль",
                    StatusCodes.Status401Unauthorized);
            }

            if (!user.IsActive)
                throw new ApiException("USER_DISABLED", "Учётная запись отключена",
                    StatusCodes.Status403Forbidden);

            var info = new UserInfo(user.UserId, user.Login, user.RoleName, user.EmployeeId, user.EmployeeName);
            var (token, expiresAt) = tokens.Create(info);

            await repository.UpdateLastLoginAsync(user.UserId, cancellationToken);
            await repository.WriteAuditAsync(user.UserId, user.Login, "LOGIN", "AppUser",
                user.UserId.ToString(), context.GetIp(), "Успешный вход", cancellationToken);

            return Results.Ok(new LoginResponse(token, expiresAt, info));
        }).RequireRateLimiting("public").AllowAnonymous();

        group.MapGet("/me", (ClaimsPrincipal user) =>
        {
            var info = new UserInfo(
                user.GetUserId(),
                user.GetLogin(),
                user.FindFirstValue(ClaimTypes.Role) ?? string.Empty,
                user.GetEmployeeId(),
                user.FindFirstValue("employeeName"));
            return Results.Ok(info);
        }).RequireAuthorization();

        group.MapPost("/change-password", async (
            ChangePasswordRequest request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            PasswordHasher hasher,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var user = await repository.GetUserByLoginAsync(principal.GetLogin(), cancellationToken)
                ?? throw new ApiException("NOT_FOUND", "Пользователь не найден", StatusCodes.Status404NotFound);

            if (!hasher.Verify(request.CurrentPassword, user.PasswordHash, user.PasswordSalt))
                throw new ApiException("INVALID_PASSWORD", "Текущий пароль указан неверно",
                    StatusCodes.Status400BadRequest);

            var (hash, salt) = hasher.Hash(request.NewPassword);
            await repository.ChangePasswordAsync(user.UserId, hash, salt, cancellationToken);
            await repository.WriteAuditAsync(user.UserId, user.Login, "PASSWORD_CHANGED", "AppUser",
                user.UserId.ToString(), context.GetIp(), "Пароль изменён", cancellationToken);

            return Results.Ok(new { message = "Пароль изменён" });
        }).RequireAuthorization();

        return app;
    }
}
