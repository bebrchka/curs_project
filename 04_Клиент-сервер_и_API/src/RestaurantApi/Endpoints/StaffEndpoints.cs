using System.Security.Claims;
using System.Text.Json;
using RestaurantApi.Data;
using RestaurantApi.Models;
using RestaurantApi.Services;

namespace RestaurantApi.Endpoints;

public static class StaffEndpoints
{
    public static IEndpointRouteBuilder MapStaffEndpoints(this IEndpointRouteBuilder app)
    {
        MapOrders(app);
        MapReservations(app);
        MapTables(app);
        MapDishes(app);
        MapReferenceData(app);
        return app;
    }

    private static void MapOrders(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/orders").WithTags("Заказы").RequireAuthorization("Staff");

        group.MapGet("/active", async (
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
            Results.Ok(await repository.GetActiveOrdersAsync(cancellationToken)));

        group.MapGet("/", async (
            DateTime? from,
            DateTime? to,
            string? status,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
            Results.Ok(await repository.GetOrdersAsync(from, to, status, cancellationToken)));

        group.MapGet("/{id:int}", async (
            int id,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            var order = await repository.GetOrderByIdAsync(id, cancellationToken)
                ?? throw new ApiException("NOT_FOUND", "Заказ не найден", StatusCodes.Status404NotFound);
            return Results.Ok(order);
        });

        group.MapPost("/", async (
            CreateOrderRequest request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var employeeId = principal.GetEmployeeId()
                ?? throw new ApiException("NO_EMPLOYEE", "У пользователя нет привязки к сотруднику",
                    StatusCodes.Status400BadRequest);
            if (request.OrderType is not ("В зале" or "На вынос" or "Доставка"))
                throw new ApiException("VALIDATION", "Недопустимый тип заказа", StatusCodes.Status400BadRequest);

            var itemsJson = request.Items is { Count: > 0 }
                ? JsonSerializer.Serialize(request.Items.Select(item => new
                {
                    dishId = item.DishId,
                    quantity = item.Quantity
                }))
                : null;

            var (orderId, total) = await repository.CreateOrderAsync(
                request.TableId,
                request.CustomerId,
                employeeId,
                request.OrderType,
                Validation.OptionalString(request.Notes, 200),
                itemsJson,
                cancellationToken);

            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "ORDER_CREATED",
                "Order", orderId.ToString(), context.GetIp(), $"Сумма {total:F2}", cancellationToken);

            return Results.Created($"/api/orders/{orderId}", new { orderId, total });
        });

        group.MapPost("/{id:int}/items", async (
            int id,
            OrderItemRequest request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (request.Quantity is < 1 or > 99)
                throw new ApiException("VALIDATION", "Количество должно быть от 1 до 99",
                    StatusCodes.Status400BadRequest);

            var (itemId, total) = await repository.AddOrderItemAsync(
                id, request.DishId, request.Quantity,
                Validation.OptionalString(request.Comment, 150), cancellationToken);

            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "ORDER_ITEM_ADDED",
                "OrderItem", itemId.ToString(), context.GetIp(), $"Заказ {id}, сумма {total:F2}", cancellationToken);

            return Results.Ok(new { orderItemId = itemId, totalAmount = total });
        });

        group.MapDelete("/{id:int}/items/{itemId:int}", async (
            int id,
            int itemId,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var total = await repository.DeleteOrderItemAsync(itemId, cancellationToken);
            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "ORDER_ITEM_DELETED",
                "OrderItem", itemId.ToString(), context.GetIp(), $"Заказ {id}, сумма {total:F2}", cancellationToken);
            return Results.Ok(new { totalAmount = total });
        });

        group.MapPost("/{id:int}/status", async (
            int id,
            StatusRequest request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (request.Status is not ("Готовится" or "Готов"))
                throw new ApiException("VALIDATION", "Допустимые статусы: «Готовится», «Готов»",
                    StatusCodes.Status400BadRequest);

            await repository.UpdateOrderStatusAsync(id, request.Status, principal.GetEmployeeId(),
                Validation.OptionalString(request.Comment, 250), cancellationToken);
            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "ORDER_STATUS_CHANGED",
                "Order", id.ToString(), context.GetIp(), $"Новый статус: {request.Status}", cancellationToken);
            return Results.Ok(new { message = "Статус обновлён" });
        }).RequireAuthorization("KitchenOrManager");

        group.MapPost("/{id:int}/pay", async (
            int id,
            PaymentRequest request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (request.PaymentMethod is not ("Наличные" or "Карта" or "Онлайн"))
                throw new ApiException("VALIDATION", "Недопустимый способ оплаты", StatusCodes.Status400BadRequest);
            var employeeId = principal.GetEmployeeId()
                ?? throw new ApiException("NO_EMPLOYEE", "У пользователя нет привязки к сотруднику",
                    StatusCodes.Status400BadRequest);

            var (paymentId, amount) = await repository.CloseOrderAsync(
                id, employeeId, request.PaymentMethod, cancellationToken);
            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "ORDER_PAID",
                "Payment", paymentId.ToString(), context.GetIp(),
                $"Заказ {id}, оплачено {amount:F2}", cancellationToken);
            return Results.Ok(new { paymentId, amount });
        }).RequireAuthorization("CashierOrManager");

        group.MapPost("/{id:int}/cancel", async (
            int id,
            StatusRequest request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            await repository.CancelOrderAsync(id, Validation.OptionalString(request.Comment, 250), cancellationToken);
            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "ORDER_CANCELLED",
                "Order", id.ToString(), context.GetIp(), request.Comment, cancellationToken);
            return Results.Ok(new { message = "Заказ отменён" });
        }).RequireAuthorization("ManagerOrWaiter");
    }

    private static void MapReservations(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/reservations").WithTags("Бронирования").RequireAuthorization("Staff");

        group.MapGet("/", async (
            DateTime? from,
            DateTime? to,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
            Results.Ok(await repository.GetReservationsAsync(from, to, cancellationToken)));

        group.MapPost("/", async (
            ReservationRequest request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (request.GuestsCount is < 1 or > 20)
                throw new ApiException("VALIDATION", "Количество гостей должно быть от 1 до 20",
                    StatusCodes.Status400BadRequest);
            if (request.TableId is null)
                throw new ApiException("VALIDATION", "Укажите столик", StatusCodes.Status400BadRequest);
            if (request.ReservationDate < DateTime.Now)
                throw new ApiException("VALIDATION", "Нельзя бронировать на прошедшее время",
                    StatusCodes.Status400BadRequest);

            var employeeId = principal.GetEmployeeId()
                ?? throw new ApiException("NO_EMPLOYEE", "У пользователя нет привязки к сотруднику",
                    StatusCodes.Status400BadRequest);

            var customerId = request.CustomerId;
            if (customerId is null && request.Customer is not null)
            {
                var customer = request.Customer;
                customerId = await repository.FindOrCreateCustomerAsync(new CustomerRequest(
                    Validation.RequireString(customer.LastName, "Фамилия", 50),
                    Validation.RequireString(customer.FirstName, "Имя", 50),
                    Validation.OptionalString(customer.MiddleName, 50),
                    customer.Phone,
                    Validation.OptionalString(customer.Email, 80)), cancellationToken);
            }

            if (customerId is null)
                throw new ApiException("VALIDATION", "Укажите клиента", StatusCodes.Status400BadRequest);

            var reservationId = await repository.CreateReservationAsync(
                customerId.Value, request.TableId.Value, employeeId,
                request.ReservationDate, request.GuestsCount,
                Validation.OptionalString(request.Notes, 200), cancellationToken);

            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "RESERVATION_CREATED",
                "Reservation", reservationId.ToString(), context.GetIp(), null, cancellationToken);
            return Results.Created($"/api/reservations/{reservationId}", new { reservationId });
        });

        group.MapPost("/{id:int}/cancel", async (
            int id,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            await repository.CancelReservationAsync(id, cancellationToken);
            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "RESERVATION_CANCELLED",
                "Reservation", id.ToString(), context.GetIp(), null, cancellationToken);
            return Results.Ok(new { message = "Бронирование отменено" });
        });

        group.MapPost("/{id:int}/status", async (
            int id,
            StatusRequest request,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (request.Status is not ("Выполнена" or "Отменена"))
                throw new ApiException("VALIDATION", "Допустимые статусы: «Выполнена», «Отменена»",
                    StatusCodes.Status400BadRequest);
            await repository.UpdateReservationStatusAsync(id, request.Status, cancellationToken);
            await repository.WriteAuditAsync(principal.GetUserId(), principal.GetLogin(), "RESERVATION_STATUS_CHANGED",
                "Reservation", id.ToString(), context.GetIp(), request.Status, cancellationToken);
            return Results.Ok(new { message = "Статус обновлён" });
        }).RequireAuthorization("ManagerOrDirector");
    }

    private static void MapTables(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tables").WithTags("Столики").RequireAuthorization("Staff");

        group.MapGet("/", async (
            bool? onlyFree,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
            Results.Ok(await repository.GetTablesAsync(onlyFree ?? false, cancellationToken)));

        group.MapPut("/{id:int}/status", async (
            int id,
            TableStatusRequest request,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            if (request.Status is not ("Свободен" or "Занят" or "Забронирован" or "Неактивен"))
                throw new ApiException("VALIDATION", "Недопустимый статус столика", StatusCodes.Status400BadRequest);
            await repository.UpdateTableStatusAsync(id, request.Status, cancellationToken);
            return Results.Ok(new { message = "Статус столика обновлён" });
        });
    }

    private static void MapDishes(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/dishes").WithTags("Меню").RequireAuthorization("Staff");

        group.MapGet("/", async (
            int? categoryId,
            bool? onlyAvailable,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
            Results.Ok(await repository.GetDishesAsync(categoryId, onlyAvailable ?? false, cancellationToken)));

        group.MapPost("/", async (
            DishRequest request,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            ValidateDish(request);
            var id = await repository.InsertDishAsync(request, cancellationToken);
            return Results.Created($"/api/dishes/{id}", new { dishId = id });
        }).RequireAuthorization("ManagerOrDirector");

        group.MapPut("/{id:int}", async (
            int id,
            DishRequest request,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            ValidateDish(request);
            await repository.UpdateDishAsync(id, request, cancellationToken);
            return Results.Ok(new { message = "Блюдо обновлено" });
        }).RequireAuthorization("ManagerOrDirector");

        group.MapDelete("/{id:int}", async (
            int id,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            await repository.DeleteDishAsync(id, cancellationToken);
            return Results.Ok(new { message = "Блюдо снято с продажи" });
        }).RequireAuthorization("ManagerOrDirector");
    }

    private static void MapReferenceData(IEndpointRouteBuilder app)
    {
        app.MapGet("/api/customers", async (
            string? search,
            ClaimsPrincipal principal,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            var masked = !principal.IsInRole("Director");
            return Results.Ok(await repository.GetCustomersAsync(search, masked, cancellationToken));
        }).RequireAuthorization("ManagerOrDirector").WithTags("Клиенты");

        app.MapGet("/api/employees", async (
            bool? onlyActive,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
            Results.Ok(await repository.GetEmployeesAsync(onlyActive ?? false, cancellationToken)))
            .RequireAuthorization("ManagerOrDirector").WithTags("Сотрудники");

        app.MapGet("/api/audit", async (
            DateTime? from,
            DateTime? to,
            string? login,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
            Results.Ok(await repository.GetAuditLogAsync(from, to, login, cancellationToken)))
            .RequireAuthorization("DirectorOnly").WithTags("Аудит");
    }

    private static void ValidateDish(DishRequest request)
    {
        Validation.RequireString(request.DishName, "Название блюда", 120);
        if (request.CategoryId <= 0)
            throw new ApiException("VALIDATION", "Выберите категорию", StatusCodes.Status400BadRequest);
        if (request.Price <= 0)
            throw new ApiException("VALIDATION", "Цена должна быть больше нуля", StatusCodes.Status400BadRequest);
        if (request.WeightGr is < 0)
            throw new ApiException("VALIDATION", "Вес не может быть отрицательным", StatusCodes.Status400BadRequest);
    }
}
