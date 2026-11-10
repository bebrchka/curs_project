namespace RestaurantApi.Models;

public record LoginRequest(string Login, string Password);

public record UserInfo(
    int UserId,
    string Login,
    string Role,
    int? EmployeeId,
    string? EmployeeName);

public record LoginResponse(string Token, DateTime ExpiresAt, UserInfo User);

public record MenuItem(
    int DishId,
    int CategoryId,
    string CategoryName,
    string DishName,
    decimal Price,
    decimal? WeightGr,
    string? Description,
    bool IsAvailable);

public record DishInfo(
    int DishId,
    int CategoryId,
    string CategoryName,
    string DishName,
    decimal Price,
    decimal? WeightGr,
    string? Description,
    bool IsAvailable);

public record CategoryInfo(
    int CategoryId,
    string CategoryName,
    string? Description,
    int SortOrder,
    int DishesCount);

public record TableInfo(
    int TableId,
    string TableNumber,
    int Seats,
    string Hall,
    string TableStatus);

public record OrderLine(
    int OrderItemId,
    string DishName,
    int Quantity,
    decimal PriceAtOrder,
    decimal LineTotal,
    string? ItemComment);

public record OrderHeader(
    int OrderId,
    DateTime OrderDate,
    string OrderStatus,
    string OrderType,
    decimal TotalAmount,
    decimal DiscountPercent,
    string? Notes,
    int? TableId,
    int? CustomerId,
    int? EmployeeId,
    string? TableNumber,
    string? CustomerFullName,
    string? CustomerPhone,
    string? EmployeeFullName);

public record OrderDetails(OrderHeader Header, IReadOnlyList<OrderLine> Items);

public record CustomerInfo(
    int CustomerId,
    string LastName,
    string FirstName,
    string? MiddleName,
    string? Phone,
    string? Email,
    DateTime RegistrationDate,
    int LoyaltyPoints);

public record CustomerRequest(
    string LastName,
    string FirstName,
    string? MiddleName,
    string Phone,
    string? Email);

public record OrderItemRequest(int DishId, int Quantity, string? Comment);

public record CreateOrderRequest(
    int? TableId,
    int? CustomerId,
    string OrderType,
    string? Notes,
    List<OrderItemRequest>? Items);

public record PublicOrderRequest(
    CustomerRequest Customer,
    string OrderType,
    string? Notes,
    List<OrderItemRequest> Items);

public record ReservationInfo(
    int ReservationId,
    DateTime ReservationDate,
    int GuestsCount,
    string ReservationStatus,
    string TableNumber,
    string Hall,
    string Customer,
    string Phone,
    string Manager,
    string? Notes);

public record ReservationRequest(
    int? CustomerId,
    int? TableId,
    DateTime ReservationDate,
    int GuestsCount,
    string? Notes,
    CustomerRequest? Customer);

public record PublicReservationRequest(
    CustomerRequest Customer,
    int GuestsCount,
    DateTime ReservationDate,
    int? TableId,
    string? Notes);

public record PaymentRequest(string PaymentMethod);

public record StatusRequest(string Status, string? Comment);

public record UserSettingDto(
    string Theme,
    string DateFormat,
    string NumberFormat,
    int PageSize,
    string? SavedFilters);

public record ChangePasswordRequest(string CurrentPassword, string NewPassword);

public record DishRequest(
    int CategoryId,
    string DishName,
    decimal Price,
    decimal? WeightGr,
    string? Description,
    bool IsAvailable);

public record TableStatusRequest(string Status);

public record AuditEntry(
    long LogId,
    int? UserId,
    string? LoginName,
    DateTime ActionTime,
    string ActionType,
    string ObjectName,
    string? ObjectId,
    string? IpAddress,
    string? Details,
    string? OldValue,
    string? NewValue);

public record EmployeeInfo(
    int EmployeeId,
    string LastName,
    string FirstName,
    string? MiddleName,
    string? Phone,
    string Post,
    int RoleId,
    string RoleName,
    DateTime HireDate,
    bool IsActive);

public record ImportResult(int Imported, int Skipped, IReadOnlyList<string> Errors);
