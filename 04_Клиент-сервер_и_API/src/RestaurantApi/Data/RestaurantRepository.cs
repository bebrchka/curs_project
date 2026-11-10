using System.Data;
using Microsoft.Data.SqlClient;
using RestaurantApi.Models;

namespace RestaurantApi.Data;

public sealed class RestaurantRepository
{
    private readonly Db _db;

    public RestaurantRepository(Db db)
    {
        _db = db;
    }

    public async Task<List<MenuItem>> GetMenuAsync(
        int? categoryId,
        bool onlyAvailable,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_Dish_Get",
            MapMenuItem,
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@CategoryID", categoryId),
            SqlHelper.P("@OnlyAvailable", onlyAvailable));
    }

    public async Task<List<CategoryInfo>> GetCategoriesAsync(CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT c.CategoryID, c.CategoryName, c.Description, c.SortOrder,
                   COUNT(d.DishID) AS DishesCount
            FROM dbo.Category c
            LEFT JOIN dbo.Dish d ON d.CategoryID = c.CategoryID AND d.IsAvailable = 1
            GROUP BY c.CategoryID, c.CategoryName, c.Description, c.SortOrder
            ORDER BY c.SortOrder, c.CategoryName;
            """;
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(connection, sql, reader => new CategoryInfo(
            reader.GetInt32(reader.GetOrdinal("CategoryID")),
            reader.GetString(reader.GetOrdinal("CategoryName")),
            SqlHelper.GetNullableString(reader, "Description"),
            reader.GetInt32(reader.GetOrdinal("SortOrder")),
            reader.GetInt32(reader.GetOrdinal("DishesCount"))
        ), cancellationToken);
    }

    public async Task<List<TableInfo>> GetTablesAsync(
        bool onlyFree,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_Table_Get",
            MapTable,
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@OnlyFree", onlyFree));
    }

    public async Task<List<TableInfo>> GetTableAvailabilityAsync(
        DateTime reservationDate,
        int guestsCount,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_GetTableAvailability",
            MapTable,
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@ReservationDate", reservationDate),
            SqlHelper.P("@GuestsCount", guestsCount));
    }

    public async Task UpdateTableStatusAsync(
        int tableId,
        string status,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_Table_UpdateStatus",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@TableID", tableId),
            SqlHelper.P("@TableStatus", status));
    }

    public async Task<List<OrderHeader>> GetActiveOrdersAsync(CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT OrderID, OrderDate, OrderStatus, OrderType, TotalAmount, DiscountPercent,
                   Notes, TableID, CustomerID, EmployeeID, TableNumber, CustomerFullName,
                   CustomerPhone, EmployeeFullName
            FROM dbo.vw_OrderDetails
            WHERE OrderStatus IN (N'Оформлен', N'Готовится', N'Готов')
            ORDER BY OrderDate;
            """;
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(connection, sql, MapOrderHeader, cancellationToken);
    }

    public async Task<List<OrderHeader>> GetOrdersAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        string? status,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_Order_Get",
            MapOrderHeader,
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@DateFrom", dateFrom?.Date),
            SqlHelper.P("@DateTo", dateTo?.Date),
            SqlHelper.P("@Status", status));
    }

    public async Task<OrderDetails?> GetOrderByIdAsync(int orderId, CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await using var command = new SqlCommand("dbo.sp_Order_GetById", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add(SqlHelper.P("@OrderID", orderId));

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        OrderHeader? header = null;
        if (await reader.ReadAsync(cancellationToken))
            header = MapOrderHeader(reader);

        var items = new List<OrderLine>();
        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                items.Add(new OrderLine(
                    reader.GetInt32(reader.GetOrdinal("OrderItemID")),
                    reader.GetString(reader.GetOrdinal("DishName")),
                    reader.GetInt32(reader.GetOrdinal("Quantity")),
                    reader.GetDecimal(reader.GetOrdinal("PriceAtOrder")),
                    reader.GetDecimal(reader.GetOrdinal("LineTotal")),
                    null));
            }
        }

        return header is null ? null : new OrderDetails(header, items);
    }

    public async Task<(int OrderId, decimal TotalAmount)> CreateOrderAsync(
        int? tableId,
        int? customerId,
        int employeeId,
        string orderType,
        string? notes,
        string? itemsJson,
        CancellationToken cancellationToken)
    {
        var orderId = new SqlParameter("@OrderID", SqlDbType.Int) { Direction = ParameterDirection.Output };
        await using var connection = await _db.OpenAsync(cancellationToken);
        await using var command = new SqlCommand("dbo.sp_CreateOrder", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(
        [
            SqlHelper.P("@TableID", tableId),
            SqlHelper.P("@CustomerID", customerId),
            SqlHelper.P("@EmployeeID", employeeId),
            SqlHelper.P("@OrderType", orderType),
            SqlHelper.P("@Notes", notes),
            SqlHelper.P("@ItemsJson", itemsJson),
            orderId
        ]);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        decimal total = 0;
        if (await reader.ReadAsync(cancellationToken))
            total = reader.GetDecimal(reader.GetOrdinal("TotalAmount"));
        return (Convert.ToInt32(orderId.Value), total);
    }

    public async Task<(int OrderItemId, decimal TotalAmount)> AddOrderItemAsync(
        int orderId,
        int dishId,
        int quantity,
        string? comment,
        CancellationToken cancellationToken)
    {
        var itemId = new SqlParameter("@OrderItemID", SqlDbType.Int) { Direction = ParameterDirection.Output };
        await using var connection = await _db.OpenAsync(cancellationToken);
        await using var command = new SqlCommand("dbo.sp_AddOrderItem", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(
        [
            SqlHelper.P("@OrderID", orderId),
            SqlHelper.P("@DishID", dishId),
            SqlHelper.P("@Quantity", quantity),
            SqlHelper.P("@Comment", comment),
            itemId
        ]);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        decimal total = 0;
        if (await reader.ReadAsync(cancellationToken))
            total = reader.GetDecimal(reader.GetOrdinal("TotalAmount"));
        return (Convert.ToInt32(itemId.Value), total);
    }

    public async Task<decimal> DeleteOrderItemAsync(int orderItemId, CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await using var command = new SqlCommand("dbo.sp_DeleteOrderItem", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add(SqlHelper.P("@OrderItemID", orderItemId));

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (await reader.ReadAsync(cancellationToken))
            return reader.GetDecimal(reader.GetOrdinal("TotalAmount"));
        return 0;
    }

    public async Task<(int PaymentId, decimal Amount)> CloseOrderAsync(
        int orderId,
        int employeeId,
        string paymentMethod,
        CancellationToken cancellationToken)
    {
        var paymentId = new SqlParameter("@PaymentID", SqlDbType.Int) { Direction = ParameterDirection.Output };
        var amount = new SqlParameter("@Amount", SqlDbType.Decimal) { Direction = ParameterDirection.Output };
        amount.Precision = 12;
        amount.Scale = 2;

        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_CloseOrder",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@OrderID", orderId),
            SqlHelper.P("@EmployeeID", employeeId),
            SqlHelper.P("@PaymentMethod", paymentMethod),
            paymentId,
            amount);

        return (Convert.ToInt32(paymentId.Value), Convert.ToDecimal(amount.Value));
    }

    public async Task CancelOrderAsync(
        int orderId,
        string? reason,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_CancelOrder",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@OrderID", orderId),
            SqlHelper.P("@Reason", reason));
    }

    public async Task UpdateOrderStatusAsync(
        int orderId,
        string status,
        int? employeeId,
        string? comment,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_Order_UpdateStatus",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@OrderID", orderId),
            SqlHelper.P("@NewStatus", status),
            SqlHelper.P("@EmployeeID", employeeId),
            SqlHelper.P("@Comment", comment));
    }

    public async Task<List<ReservationInfo>> GetReservationsAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_Reservation_Get",
            reader => new ReservationInfo(
                reader.GetInt32(reader.GetOrdinal("ReservationID")),
                reader.GetDateTime(reader.GetOrdinal("ReservationDate")),
                reader.GetInt32(reader.GetOrdinal("GuestsCount")),
                reader.GetString(reader.GetOrdinal("ReservationStatus")),
                reader.GetString(reader.GetOrdinal("TableNumber")),
                reader.GetString(reader.GetOrdinal("Hall")),
                reader.GetString(reader.GetOrdinal("Customer")),
                reader.GetString(reader.GetOrdinal("Phone")),
                reader.GetString(reader.GetOrdinal("Manager")),
                SqlHelper.GetNullableString(reader, "Notes")),
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@DateFrom", dateFrom?.Date),
            SqlHelper.P("@DateTo", dateTo?.Date));
    }

    public async Task<int> CreateReservationAsync(
        int customerId,
        int tableId,
        int employeeId,
        DateTime reservationDate,
        int guestsCount,
        string? notes,
        CancellationToken cancellationToken)
    {
        var reservationId = new SqlParameter("@ReservationID", SqlDbType.Int) { Direction = ParameterDirection.Output };
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_CreateReservation",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@CustomerID", customerId),
            SqlHelper.P("@TableID", tableId),
            SqlHelper.P("@EmployeeID", employeeId),
            SqlHelper.P("@ReservationDate", reservationDate),
            SqlHelper.P("@GuestsCount", guestsCount),
            SqlHelper.P("@Notes", notes),
            reservationId);
        return Convert.ToInt32(reservationId.Value);
    }

    public async Task CancelReservationAsync(int reservationId, CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_CancelReservation",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@ReservationID", reservationId));
    }

    public async Task UpdateReservationStatusAsync(
        int reservationId,
        string status,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_Reservation_UpdateStatus",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@ReservationID", reservationId),
            SqlHelper.P("@Status", status));
    }

    public async Task<int> FindOrCreateCustomerAsync(
        CustomerRequest request,
        CancellationToken cancellationToken)
    {
        var customerId = new SqlParameter("@CustomerID", SqlDbType.Int) { Direction = ParameterDirection.Output };
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_Customer_FindOrCreate",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@LastName", request.LastName),
            SqlHelper.P("@FirstName", request.FirstName),
            SqlHelper.P("@MiddleName", request.MiddleName),
            SqlHelper.P("@Phone", request.Phone),
            SqlHelper.P("@Email", request.Email),
            customerId);
        return Convert.ToInt32(customerId.Value);
    }

    public async Task<List<CustomerInfo>> GetCustomersAsync(
        string? search,
        bool masked,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        if (!masked)
        {
            return await SqlHelper.QueryAsync(
                connection,
                "dbo.sp_Customer_Get",
                MapCustomer,
                cancellationToken,
                CommandType.StoredProcedure,
                SqlHelper.P("@Search", search));
        }

        const string sql = """
            SELECT CustomerID, LastName, FirstName, MiddleName, PhoneMasked, EmailMasked,
                   RegistrationDate, LoyaltyPoints
            FROM dbo.vw_CustomerMasked
            WHERE @Search IS NULL
               OR PhoneMasked LIKE N'%' + @Search + N'%'
               OR LastName LIKE N'%' + @Search + N'%'
               OR EmailMasked LIKE N'%' + @Search + N'%'
            ORDER BY LastName, FirstName;
            """;
        return await SqlHelper.QueryAsync(connection, sql, reader => new CustomerInfo(
            reader.GetInt32(reader.GetOrdinal("CustomerID")),
            reader.GetString(reader.GetOrdinal("LastName")),
            reader.GetString(reader.GetOrdinal("FirstName")),
            SqlHelper.GetNullableString(reader, "MiddleName"),
            SqlHelper.GetNullableString(reader, "PhoneMasked"),
            SqlHelper.GetNullableString(reader, "EmailMasked"),
            reader.GetDateTime(reader.GetOrdinal("RegistrationDate")),
            reader.GetInt32(reader.GetOrdinal("LoyaltyPoints"))
        ), cancellationToken, CommandType.Text, SqlHelper.P("@Search", search));
    }

    public async Task<List<DishInfo>> GetDishesAsync(
        int? categoryId,
        bool onlyAvailable,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_Dish_Get",
            reader => new DishInfo(
                reader.GetInt32(reader.GetOrdinal("DishID")),
                reader.GetInt32(reader.GetOrdinal("CategoryID")),
                reader.GetString(reader.GetOrdinal("CategoryName")),
                reader.GetString(reader.GetOrdinal("DishName")),
                reader.GetDecimal(reader.GetOrdinal("Price")),
                SqlHelper.GetNullableDecimal(reader, "WeightGr"),
                SqlHelper.GetNullableString(reader, "Description"),
                reader.GetBoolean(reader.GetOrdinal("IsAvailable"))),
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@CategoryID", categoryId),
            SqlHelper.P("@OnlyAvailable", onlyAvailable));
    }

    public async Task<int> InsertDishAsync(DishRequest request, CancellationToken cancellationToken)
    {
        var dishId = new SqlParameter("@DishID", SqlDbType.Int) { Direction = ParameterDirection.Output };
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_Dish_Insert",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@CategoryID", request.CategoryId),
            SqlHelper.P("@DishName", request.DishName),
            SqlHelper.P("@Price", request.Price),
            SqlHelper.P("@WeightGr", request.WeightGr),
            SqlHelper.P("@Description", request.Description),
            dishId);
        return Convert.ToInt32(dishId.Value);
    }

    public async Task UpdateDishAsync(int dishId, DishRequest request, CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_Dish_Update",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@DishID", dishId),
            SqlHelper.P("@CategoryID", request.CategoryId),
            SqlHelper.P("@DishName", request.DishName),
            SqlHelper.P("@Price", request.Price),
            SqlHelper.P("@WeightGr", request.WeightGr),
            SqlHelper.P("@Description", request.Description),
            SqlHelper.P("@IsAvailable", request.IsAvailable));
    }

    public async Task DeleteDishAsync(int dishId, CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_Dish_Delete",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@DishID", dishId));
    }

    public async Task<List<EmployeeInfo>> GetEmployeesAsync(
        bool onlyActive,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_Employee_Get",
            reader => new EmployeeInfo(
                reader.GetInt32(reader.GetOrdinal("EmployeeID")),
                reader.GetString(reader.GetOrdinal("LastName")),
                reader.GetString(reader.GetOrdinal("FirstName")),
                SqlHelper.GetNullableString(reader, "MiddleName"),
                SqlHelper.GetNullableString(reader, "Phone"),
                reader.GetString(reader.GetOrdinal("Post")),
                reader.GetInt32(reader.GetOrdinal("RoleID")),
                reader.GetString(reader.GetOrdinal("RoleName")),
                reader.GetDateTime(reader.GetOrdinal("HireDate")),
                reader.GetBoolean(reader.GetOrdinal("IsActive"))),
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@OnlyActive", onlyActive));
    }

    public async Task<UserRecord?> GetUserByLoginAsync(string login, CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        var users = await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_User_GetByLogin",
            reader => new UserRecord(
                reader.GetInt32(reader.GetOrdinal("UserID")),
                reader.GetString(reader.GetOrdinal("Login")),
                (byte[])reader["PasswordHash"],
                (byte[])reader["PasswordSalt"],
                SqlHelper.GetNullableInt(reader, "EmployeeID"),
                reader.GetInt32(reader.GetOrdinal("RoleID")),
                reader.GetString(reader.GetOrdinal("RoleName")),
                reader.GetBoolean(reader.GetOrdinal("IsActive")),
                SqlHelper.GetNullableString(reader, "EmployeeFullName")),
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@Login", login));
        return users.FirstOrDefault();
    }

    public async Task UpdateLastLoginAsync(int userId, CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_User_UpdateLastLogin",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@UserID", userId));
    }

    public async Task ChangePasswordAsync(
        int userId,
        byte[] hash,
        byte[] salt,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_User_ChangePassword",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@UserID", userId),
            SqlHelper.P("@PasswordHash", hash),
            SqlHelper.P("@PasswordSalt", salt));
    }

    public async Task<UserSettingDto> GetUserSettingsAsync(int userId, CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        var settings = await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_UserSetting_Get",
            reader => new UserSettingDto(
                reader.GetString(reader.GetOrdinal("Theme")),
                reader.GetString(reader.GetOrdinal("DateFormat")),
                reader.GetString(reader.GetOrdinal("NumberFormat")),
                reader.GetInt32(reader.GetOrdinal("PageSize")),
                SqlHelper.GetNullableString(reader, "SavedFilters")),
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@UserID", userId));
        return settings.FirstOrDefault() ?? new UserSettingDto("light", "dd.MM.yyyy", "ru-RU", 20, null);
    }

    public async Task SaveUserSettingsAsync(
        int userId,
        UserSettingDto settings,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_UserSetting_Upsert",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@UserID", userId),
            SqlHelper.P("@Theme", settings.Theme),
            SqlHelper.P("@DateFormat", settings.DateFormat),
            SqlHelper.P("@NumberFormat", settings.NumberFormat),
            SqlHelper.P("@PageSize", settings.PageSize),
            SqlHelper.P("@SavedFilters", settings.SavedFilters));
    }

    public async Task<List<AuditEntry>> GetAuditLogAsync(
        DateTime? dateFrom,
        DateTime? dateTo,
        string? login,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        return await SqlHelper.QueryAsync(
            connection,
            "dbo.sp_GetAuditLog",
            reader => new AuditEntry(
                reader.GetInt64(reader.GetOrdinal("LogID")),
                SqlHelper.GetNullableInt(reader, "UserID"),
                SqlHelper.GetNullableString(reader, "LoginName"),
                reader.GetDateTime(reader.GetOrdinal("ActionTime")),
                reader.GetString(reader.GetOrdinal("ActionType")),
                reader.GetString(reader.GetOrdinal("ObjectName")),
                SqlHelper.GetNullableString(reader, "ObjectID"),
                SqlHelper.GetNullableString(reader, "IPAddress"),
                SqlHelper.GetNullableString(reader, "Details"),
                SqlHelper.GetNullableString(reader, "OldValue"),
                SqlHelper.GetNullableString(reader, "NewValue")),
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@DateFrom", dateFrom?.Date),
            SqlHelper.P("@DateTo", dateTo?.Date),
            SqlHelper.P("@Login", login));
    }

    public async Task WriteAuditAsync(
        int? userId,
        string? loginName,
        string actionType,
        string objectName,
        string? objectId,
        string? ipAddress,
        string? details,
        CancellationToken cancellationToken)
    {
        await using var connection = await _db.OpenAsync(cancellationToken);
        await SqlHelper.ExecuteAsync(
            connection,
            "dbo.sp_Audit_Write",
            cancellationToken,
            CommandType.StoredProcedure,
            SqlHelper.P("@UserID", userId),
            SqlHelper.P("@LoginName", loginName),
            SqlHelper.P("@ActionType", actionType),
            SqlHelper.P("@ObjectName", objectName),
            SqlHelper.P("@ObjectID", objectId),
            SqlHelper.P("@IPAddress", ipAddress),
            SqlHelper.P("@Details", details));
    }

    private static MenuItem MapMenuItem(SqlDataReader reader) => new(
        reader.GetInt32(reader.GetOrdinal("DishID")),
        reader.GetInt32(reader.GetOrdinal("CategoryID")),
        reader.GetString(reader.GetOrdinal("CategoryName")),
        reader.GetString(reader.GetOrdinal("DishName")),
        reader.GetDecimal(reader.GetOrdinal("Price")),
        SqlHelper.GetNullableDecimal(reader, "WeightGr"),
        SqlHelper.GetNullableString(reader, "Description"),
        reader.GetBoolean(reader.GetOrdinal("IsAvailable")));

    private static TableInfo MapTable(SqlDataReader reader) => new(
        reader.GetInt32(reader.GetOrdinal("TableID")),
        reader.GetString(reader.GetOrdinal("TableNumber")),
        reader.GetInt32(reader.GetOrdinal("Seats")),
        reader.GetString(reader.GetOrdinal("Hall")),
        reader.GetString(reader.GetOrdinal("TableStatus")));

    private static OrderHeader MapOrderHeader(SqlDataReader reader) => new(
        reader.GetInt32(reader.GetOrdinal("OrderID")),
        reader.GetDateTime(reader.GetOrdinal("OrderDate")),
        reader.GetString(reader.GetOrdinal("OrderStatus")),
        reader.GetString(reader.GetOrdinal("OrderType")),
        reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
        reader.GetDecimal(reader.GetOrdinal("DiscountPercent")),
        SqlHelper.GetNullableString(reader, "Notes"),
        SqlHelper.GetNullableInt(reader, "TableID"),
        SqlHelper.GetNullableInt(reader, "CustomerID"),
        SqlHelper.GetNullableInt(reader, "EmployeeID"),
        SqlHelper.GetNullableString(reader, "TableNumber"),
        SqlHelper.GetNullableString(reader, "CustomerFullName"),
        SqlHelper.GetNullableString(reader, "CustomerPhone"),
        SqlHelper.GetNullableString(reader, "EmployeeFullName"));

    private static CustomerInfo MapCustomer(SqlDataReader reader) => new(
        reader.GetInt32(reader.GetOrdinal("CustomerID")),
        reader.GetString(reader.GetOrdinal("LastName")),
        reader.GetString(reader.GetOrdinal("FirstName")),
        SqlHelper.GetNullableString(reader, "MiddleName"),
        SqlHelper.GetNullableString(reader, "Phone"),
        SqlHelper.GetNullableString(reader, "Email"),
        reader.GetDateTime(reader.GetOrdinal("RegistrationDate")),
        reader.GetInt32(reader.GetOrdinal("LoyaltyPoints")));
}
