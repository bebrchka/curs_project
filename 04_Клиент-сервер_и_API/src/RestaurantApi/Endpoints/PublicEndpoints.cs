using System.Text.Json;
using RestaurantApi.Data;
using RestaurantApi.Models;
using RestaurantApi.Services;

namespace RestaurantApi.Endpoints;

public static class PublicEndpoints
{
    public static IEndpointRouteBuilder MapPublicEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api").WithTags("Публичный сайт");

        group.MapGet("/menu", async (
            int? categoryId,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            var menu = await repository.GetMenuAsync(categoryId, onlyAvailable: true, cancellationToken);
            return Results.Ok(menu);
        }).AllowAnonymous().RequireRateLimiting("public");

        group.MapGet("/categories", async (
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            var categories = await repository.GetCategoriesAsync(cancellationToken);
            return Results.Ok(categories);
        }).AllowAnonymous().RequireRateLimiting("public");

        group.MapGet("/tables/available", async (
            DateTime date,
            int guests,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            if (guests is < 1 or > 20)
                throw new ApiException("VALIDATION", "Количество гостей должно быть от 1 до 20",
                    StatusCodes.Status400BadRequest);
            if (date < DateTime.Now)
                throw new ApiException("VALIDATION", "Нельзя выбрать прошедшую дату",
                    StatusCodes.Status400BadRequest);

            var tables = await repository.GetTableAvailabilityAsync(date, guests, cancellationToken);
            return Results.Ok(tables);
        }).AllowAnonymous().RequireRateLimiting("public");

        group.MapPost("/public/orders", async (
            PublicOrderRequest request,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (request.Items is null || request.Items.Count == 0)
                throw new ApiException("VALIDATION", "Добавьте хотя бы одно блюдо",
                    StatusCodes.Status400BadRequest);
            if (request.OrderType is not ("На вынос" or "Доставка"))
                throw new ApiException("VALIDATION", "Для онлайн-заказа доступны «На вынос» и «Доставка»",
                    StatusCodes.Status400BadRequest);

            var customer = NormalizeCustomer(request.Customer);
            var customerId = await repository.FindOrCreateCustomerAsync(customer, cancellationToken);

            var items = request.Items.Select(item => new { dishId = item.DishId, quantity = item.Quantity }).ToList();
            var itemsJson = JsonSerializer.Serialize(items);

            var employeeId = await ResolveOnlineEmployeeAsync(repository, cancellationToken);
            var (orderId, total) = await repository.CreateOrderAsync(
                tableId: null,
                customerId,
                employeeId,
                request.OrderType,
                Validation.OptionalString(request.Notes, 200),
                itemsJson,
                cancellationToken);

            await repository.WriteAuditAsync(customerId, customer.Phone, "PUBLIC_ORDER_CREATED",
                "Order", orderId.ToString(), context.GetIp(),
                $"Онлайн-заказ на сумму {total:F2}", cancellationToken);

            return Results.Ok(new { orderId, total, message = "Заказ принят" });
        }).AllowAnonymous().RequireRateLimiting("public");

        group.MapPost("/public/reservations", async (
            PublicReservationRequest request,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (request.GuestsCount is < 1 or > 20)
                throw new ApiException("VALIDATION", "Количество гостей должно быть от 1 до 20",
                    StatusCodes.Status400BadRequest);
            if (request.ReservationDate < DateTime.Now.AddMinutes(30))
                throw new ApiException("VALIDATION", "Бронирование возможно не ранее чем через 30 минут",
                    StatusCodes.Status400BadRequest);

            var customer = NormalizeCustomer(request.Customer);
            var customerId = await repository.FindOrCreateCustomerAsync(customer, cancellationToken);

            var tableId = request.TableId;
            if (tableId is null)
            {
                var available = await repository.GetTableAvailabilityAsync(
                    request.ReservationDate, request.GuestsCount, cancellationToken);
                tableId = available.FirstOrDefault()?.TableId
                    ?? throw new ApiException("NO_TABLE", "Нет свободных столиков на выбранное время",
                        StatusCodes.Status409Conflict);
            }

            var employeeId = await ResolveOnlineEmployeeAsync(repository, cancellationToken);
            var reservationId = await repository.CreateReservationAsync(
                customerId,
                tableId.Value,
                employeeId,
                request.ReservationDate,
                request.GuestsCount,
                Validation.OptionalString(request.Notes, 200),
                cancellationToken);

            await repository.WriteAuditAsync(customerId, customer.Phone, "PUBLIC_RESERVATION_CREATED",
                "Reservation", reservationId.ToString(), context.GetIp(),
                $"Бронирование на {request.ReservationDate:dd.MM.yyyy HH:mm}", cancellationToken);

            return Results.Ok(new { reservationId, message = "Столик забронирован" });
        }).AllowAnonymous().RequireRateLimiting("public");

        return app;
    }

    private static CustomerRequest NormalizeCustomer(CustomerRequest request) => new(
        Validation.RequireString(request.LastName, "Фамилия", 50),
        Validation.RequireString(request.FirstName, "Имя", 50),
        Validation.OptionalString(request.MiddleName, 50),
        ValidatePhone(request.Phone),
        ValidateEmail(request.Email));

    private static string ValidatePhone(string? phone)
    {
        if (!Validation.IsValidPhone(phone))
            throw new ApiException("VALIDATION", "Укажите корректный телефон", StatusCodes.Status400BadRequest);
        return phone!.Trim();
    }

    private static string? ValidateEmail(string? email)
    {
        if (!Validation.IsValidEmail(email))
            throw new ApiException("VALIDATION", "Укажите корректный e-mail", StatusCodes.Status400BadRequest);
        return Validation.OptionalString(email, 80);
    }

    private static async Task<int> ResolveOnlineEmployeeAsync(
        RestaurantRepository repository,
        CancellationToken cancellationToken)
    {
        var employees = await repository.GetEmployeesAsync(onlyActive: true, cancellationToken);
        return employees.FirstOrDefault(employee => employee.EmployeeId == 8)?.EmployeeId
            ?? employees.FirstOrDefault()?.EmployeeId
            ?? throw new ApiException("NO_EMPLOYEE", "Нет активных сотрудников для оформления заказа",
                StatusCodes.Status503ServiceUnavailable);
    }
}
