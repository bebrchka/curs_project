/* ============================================================
   Скрипт 04. Представления и базовые CRUD-операции
   ============================================================ */
USE RestaurantDB;
GO

/* ================= ПРЕДСТАВЛЕНИЯ ================= */

CREATE OR ALTER VIEW dbo.vw_Menu
AS
SELECT  d.DishID,
        c.CategoryID,
        c.CategoryName,
        d.DishName,
        d.Price,
        d.WeightGr,
        d.Description,
        d.IsAvailable
FROM dbo.Dish d
JOIN dbo.Category c ON c.CategoryID = d.CategoryID;
GO

CREATE OR ALTER VIEW dbo.vw_ActiveOrders
AS
SELECT  o.OrderID,
        o.OrderDate,
        o.OrderType,
        o.OrderStatus,
        ISNULL(t.TableNumber, N'—') AS TableNumber,
        ISNULL(t.Hall, N'—') AS Hall,
        CONCAT(e.LastName, N' ', LEFT(e.FirstName, 1), N'.') AS Waiter,
        ISNULL(CONCAT(c.LastName, N' ', c.FirstName), N'Гость') AS Customer,
        o.TotalAmount
FROM dbo.[Order] o
LEFT JOIN dbo.RestaurantTable t ON t.TableID = o.TableID
LEFT JOIN dbo.Employee e ON e.EmployeeID = o.EmployeeID
LEFT JOIN dbo.Customer c ON c.CustomerID = o.CustomerID
WHERE o.OrderStatus IN (N'Оформлен', N'Готовится', N'Готов');
GO

CREATE OR ALTER VIEW dbo.vw_OrderBill
AS
SELECT  oi.OrderID,
        oi.OrderItemID,
        d.DishName,
        oi.Quantity,
        oi.PriceAtOrder,
        CAST(oi.Quantity * oi.PriceAtOrder AS DECIMAL(12,2)) AS LineTotal
FROM dbo.OrderItem oi
JOIN dbo.Dish d ON d.DishID = oi.DishID;
GO

CREATE OR ALTER VIEW dbo.vw_ReservationSchedule
AS
SELECT  r.ReservationID,
        r.ReservationDate,
        r.GuestsCount,
        r.ReservationStatus,
        t.TableNumber,
        t.Hall,
        CONCAT(c.LastName, N' ', c.FirstName) AS Customer,
        c.Phone,
        CONCAT(e.LastName, N' ', LEFT(e.FirstName, 1), N'.') AS Manager,
        r.Notes
FROM dbo.Reservation r
JOIN dbo.Customer c ON c.CustomerID = r.CustomerID
JOIN dbo.RestaurantTable t ON t.TableID = r.TableID
JOIN dbo.Employee e ON e.EmployeeID = r.EmployeeID;
GO

CREATE OR ALTER VIEW dbo.vw_OrderDetails
AS
SELECT  o.OrderID,
        o.OrderDate,
        o.OrderStatus,
        o.OrderType,
        o.TotalAmount,
        o.DiscountPercent,
        o.Notes,
        o.TableID,
        o.CustomerID,
        o.EmployeeID,
        t.TableNumber,
        CONCAT(c.LastName, N' ', c.FirstName, N' ', ISNULL(c.MiddleName, N'')) AS CustomerFullName,
        c.Phone AS CustomerPhone,
        CONCAT(e.LastName, N' ', e.FirstName) AS EmployeeFullName
FROM dbo.[Order] o
LEFT JOIN dbo.RestaurantTable t ON t.TableID = o.TableID
LEFT JOIN dbo.Customer c ON c.CustomerID = o.CustomerID
LEFT JOIN dbo.Employee e ON e.EmployeeID = o.EmployeeID;
GO

/* ================= CRUD: КАТЕГОРИИ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Category_Get
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CategoryID, CategoryName, Description, SortOrder
    FROM dbo.Category
    ORDER BY SortOrder, CategoryName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Category_Insert
    @CategoryName NVARCHAR(80),
    @Description  NVARCHAR(200) = NULL,
    @SortOrder    INT = 100,
    @CategoryID   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF LEN(LTRIM(RTRIM(@CategoryName))) < 2
        THROW 50201, N'Название категории слишком короткое', 1;
    IF EXISTS (SELECT 1 FROM dbo.Category WHERE CategoryName = @CategoryName)
        THROW 50202, N'Категория с таким названием уже существует', 1;

    INSERT INTO dbo.Category (CategoryName, Description, SortOrder)
    VALUES (@CategoryName, @Description, @SortOrder);
    SET @CategoryID = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Category_Update
    @CategoryID   INT,
    @CategoryName NVARCHAR(80),
    @Description  NVARCHAR(200) = NULL,
    @SortOrder    INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Category WHERE CategoryID = @CategoryID)
        THROW 50203, N'Категория не найдена', 1;
    IF EXISTS (SELECT 1 FROM dbo.Category WHERE CategoryName = @CategoryName AND CategoryID <> @CategoryID)
        THROW 50202, N'Категория с таким названием уже существует', 1;

    UPDATE dbo.Category
    SET CategoryName = @CategoryName,
        Description = @Description,
        SortOrder = @SortOrder
    WHERE CategoryID = @CategoryID;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Category_Delete
    @CategoryID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.Dish WHERE CategoryID = @CategoryID)
        THROW 50204, N'Нельзя удалить категорию, в которой есть блюда', 1;
    DELETE FROM dbo.Category WHERE CategoryID = @CategoryID;
END
GO

/* ================= CRUD: БЛЮДА ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Dish_Get
    @CategoryID INT = NULL,
    @OnlyAvailable BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM dbo.vw_Menu
    WHERE (@CategoryID IS NULL OR CategoryID = @CategoryID)
      AND (@OnlyAvailable = 0 OR IsAvailable = 1)
    ORDER BY CategoryName, DishName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dish_Insert
    @CategoryID INT,
    @DishName   NVARCHAR(120),
    @Price      DECIMAL(12,2),
    @WeightGr   DECIMAL(7,1) = NULL,
    @Description NVARCHAR(400) = NULL,
    @DishID     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Category WHERE CategoryID = @CategoryID)
        THROW 50205, N'Категория не найдена', 1;
    IF @Price <= 0
        THROW 50206, N'Цена должна быть больше нуля', 1;

    INSERT INTO dbo.Dish (CategoryID, DishName, Price, WeightGr, Description)
    VALUES (@CategoryID, @DishName, @Price, @WeightGr, @Description);
    SET @DishID = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dish_Update
    @DishID     INT,
    @CategoryID INT,
    @DishName   NVARCHAR(120),
    @Price      DECIMAL(12,2),
    @WeightGr   DECIMAL(7,1) = NULL,
    @Description NVARCHAR(400) = NULL,
    @IsAvailable BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Dish WHERE DishID = @DishID)
        THROW 50207, N'Блюдо не найдено', 1;
    IF @Price <= 0
        THROW 50206, N'Цена должна быть больше нуля', 1;

    UPDATE dbo.Dish
    SET CategoryID = @CategoryID,
        DishName = @DishName,
        Price = @Price,
        WeightGr = @WeightGr,
        Description = @Description,
        IsAvailable = @IsAvailable,
        UpdatedAt = GETDATE()
    WHERE DishID = @DishID;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dish_Delete
    @DishID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Dish
    SET IsAvailable = 0,
        UpdatedAt = GETDATE()
    WHERE DishID = @DishID;
END
GO

/* ================= CRUD: СТОЛИКИ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Table_Get
    @OnlyFree BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TableID, TableNumber, Seats, Hall, TableStatus
    FROM dbo.RestaurantTable
    WHERE (@OnlyFree = 0 OR TableStatus = N'Свободен')
    ORDER BY Hall, TRY_CONVERT(INT, TableNumber);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Table_UpdateStatus
    @TableID INT,
    @TableStatus NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF @TableStatus NOT IN (N'Свободен', N'Занят', N'Забронирован', N'Неактивен')
        THROW 50208, N'Недопустимый статус столика', 1;
    UPDATE dbo.RestaurantTable SET TableStatus = @TableStatus WHERE TableID = @TableID;
END
GO

/* ================= CRUD: КЛИЕНТЫ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Customer_Get
    @Search NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CustomerID, LastName, FirstName, MiddleName, Phone, Email, RegistrationDate, LoyaltyPoints
    FROM dbo.Customer
    WHERE @Search IS NULL
       OR Phone LIKE N'%' + @Search + N'%'
       OR LastName LIKE N'%' + @Search + N'%'
       OR Email LIKE N'%' + @Search + N'%'
    ORDER BY LastName, FirstName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Customer_FindOrCreate
    @LastName  NVARCHAR(50),
    @FirstName NVARCHAR(50),
    @MiddleName NVARCHAR(50) = NULL,
    @Phone     NVARCHAR(20),
    @Email     NVARCHAR(80) = NULL,
    @CustomerID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT @CustomerID = CustomerID FROM dbo.Customer WHERE Phone = @Phone;
    IF @CustomerID IS NULL
    BEGIN
        INSERT INTO dbo.Customer (LastName, FirstName, MiddleName, Phone, Email)
        VALUES (@LastName, @FirstName, @MiddleName, @Phone, @Email);
        SET @CustomerID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.Customer
        SET LastName = @LastName,
            FirstName = @FirstName,
            MiddleName = ISNULL(@MiddleName, MiddleName),
            Email = ISNULL(@Email, Email)
        WHERE CustomerID = @CustomerID;
    END
END
GO

/* ================= CRUD: СОТРУДНИКИ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Employee_Get
    @OnlyActive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.EmployeeID, e.LastName, e.FirstName, e.MiddleName, e.Phone, e.Post,
           e.RoleID, r.RoleName, e.HireDate, e.IsActive
    FROM dbo.Employee e
    JOIN dbo.Role r ON r.RoleID = e.RoleID
    WHERE (@OnlyActive = 0 OR e.IsActive = 1)
    ORDER BY e.LastName, e.FirstName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_Insert
    @LastName NVARCHAR(50),
    @FirstName NVARCHAR(50),
    @MiddleName NVARCHAR(50) = NULL,
    @Phone NVARCHAR(20) = NULL,
    @Post NVARCHAR(80),
    @RoleID INT,
    @EmployeeID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Role WHERE RoleID = @RoleID)
        THROW 50209, N'Роль не найдена', 1;
    INSERT INTO dbo.Employee (LastName, FirstName, MiddleName, Phone, Post, RoleID)
    VALUES (@LastName, @FirstName, @MiddleName, @Phone, @Post, @RoleID);
    SET @EmployeeID = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_Update
    @EmployeeID INT,
    @LastName NVARCHAR(50),
    @FirstName NVARCHAR(50),
    @MiddleName NVARCHAR(50) = NULL,
    @Phone NVARCHAR(20) = NULL,
    @Post NVARCHAR(80),
    @RoleID INT,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Employee
    SET LastName = @LastName,
        FirstName = @FirstName,
        MiddleName = @MiddleName,
        Phone = @Phone,
        Post = @Post,
        RoleID = @RoleID,
        IsActive = @IsActive
    WHERE EmployeeID = @EmployeeID;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_Deactivate
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRAN;
        UPDATE dbo.Employee SET IsActive = 0 WHERE EmployeeID = @EmployeeID;
        UPDATE dbo.AppUser SET IsActive = 0 WHERE EmployeeID = @EmployeeID;
    COMMIT;
END
GO

/* ================= АУТЕНТИФИКАЦИЯ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_User_GetByLogin
    @Login NVARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  u.UserID, u.Login, u.PasswordHash, u.PasswordSalt, u.EmployeeID, u.RoleID,
            r.RoleName, u.IsActive, u.CreatedAt, u.LastLoginAt,
            CONCAT(e.LastName, N' ', e.FirstName, N' ', ISNULL(e.MiddleName, N'')) AS EmployeeFullName
    FROM dbo.AppUser u
    JOIN dbo.Role r ON r.RoleID = u.RoleID
    LEFT JOIN dbo.Employee e ON e.EmployeeID = u.EmployeeID
    WHERE u.Login = @Login;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_ChangePassword
    @UserID INT,
    @PasswordHash VARBINARY(64),
    @PasswordSalt VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.AppUser
    SET PasswordHash = @PasswordHash,
        PasswordSalt = @PasswordSalt
    WHERE UserID = @UserID;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_UpdateLastLogin
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.AppUser SET LastLoginAt = GETDATE() WHERE UserID = @UserID;
END
GO

/* ================= ЗАКАЗЫ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Order_Get
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL,
    @Status   NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT od.*
    FROM dbo.vw_OrderDetails od
    WHERE (@DateFrom IS NULL OR CAST(od.OrderDate AS DATE) >= @DateFrom)
      AND (@DateTo IS NULL OR CAST(od.OrderDate AS DATE) <= @DateTo)
      AND (@Status IS NULL OR od.OrderStatus = @Status)
    ORDER BY od.OrderDate DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Order_GetById
    @OrderID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_OrderDetails WHERE OrderID = @OrderID;
    SELECT * FROM dbo.vw_OrderBill WHERE OrderID = @OrderID ORDER BY OrderItemID;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreateOrder
    @TableID    INT = NULL,
    @CustomerID INT = NULL,
    @EmployeeID INT,
    @OrderType  NVARCHAR(20) = N'В зале',
    @Notes      NVARCHAR(200) = NULL,
    @ItemsJson  NVARCHAR(MAX) = NULL,
    @OrderID    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @OrderType NOT IN (N'В зале', N'На вынос', N'Доставка')
        THROW 50301, N'Недопустимый тип заказа', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Employee WHERE EmployeeID = @EmployeeID AND IsActive = 1)
        THROW 50302, N'Сотрудник не найден или неактивен', 1;
    IF @OrderType = N'В зале' AND @TableID IS NULL
        THROW 50303, N'Для заказа в зале необходимо указать столик', 1;
    IF @OrderType = N'Доставка' AND @CustomerID IS NULL
        THROW 50304, N'Для доставки необходимо указать клиента', 1;
    IF @TableID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.RestaurantTable WHERE TableID = @TableID)
        THROW 50305, N'Столик не найден', 1;
    IF @ItemsJson IS NOT NULL AND ISJSON(@ItemsJson) = 0
        THROW 50306, N'Некорректный JSON состава заказа', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.[Order] (TableID, CustomerID, EmployeeID, OrderDate, OrderStatus, OrderType, Notes)
        VALUES (@TableID, @CustomerID, @EmployeeID, GETDATE(), N'Оформлен', @OrderType, @Notes);
        SET @OrderID = SCOPE_IDENTITY();

        IF @ItemsJson IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM OPENJSON(@ItemsJson) WITH (
                    DishID INT '$.dishId',
                    Quantity INT '$.quantity'
                ) j
                LEFT JOIN dbo.Dish d ON d.DishID = j.DishID AND d.IsAvailable = 1
                WHERE j.DishID IS NULL OR j.Quantity IS NULL OR j.Quantity <= 0 OR d.DishID IS NULL
            )
                THROW 50307, N'В заказе есть недоступное блюдо или неверное количество', 1;

            INSERT INTO dbo.OrderItem (OrderID, DishID, Quantity, PriceAtOrder)
            SELECT @OrderID, j.DishID, SUM(j.Quantity), MAX(d.Price)
            FROM OPENJSON(@ItemsJson) WITH (
                DishID INT '$.dishId',
                Quantity INT '$.quantity'
            ) j
            JOIN dbo.Dish d ON d.DishID = j.DishID AND d.IsAvailable = 1
            GROUP BY j.DishID;
        END

        IF @TableID IS NOT NULL
            UPDATE dbo.RestaurantTable SET TableStatus = N'Занят' WHERE TableID = @TableID;

        COMMIT;

        SELECT @OrderID AS OrderID,
               ISNULL((SELECT SUM(Quantity * PriceAtOrder) FROM dbo.OrderItem WHERE OrderID = @OrderID), 0) AS TotalAmount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddOrderItem
    @OrderID  INT,
    @DishID   INT,
    @Quantity INT,
    @Comment  NVARCHAR(150) = NULL,
    @OrderItemID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE OrderID = @OrderID AND OrderStatus IN (N'Оформлен', N'Готовится'))
        THROW 50308, N'Нельзя добавлять позиции в заказ в текущем статусе', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Dish WHERE DishID = @DishID AND IsAvailable = 1)
        THROW 50309, N'Блюдо недоступно', 1;
    IF @Quantity IS NULL OR @Quantity <= 0
        THROW 50310, N'Количество должно быть положительным', 1;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Price DECIMAL(12,2);
        SELECT @Price = Price FROM dbo.Dish WHERE DishID = @DishID;

        SELECT @OrderItemID = OrderItemID
        FROM dbo.OrderItem
        WHERE OrderID = @OrderID AND DishID = @DishID;

        IF @OrderItemID IS NULL
        BEGIN
            INSERT INTO dbo.OrderItem (OrderID, DishID, Quantity, PriceAtOrder, ItemComment)
            VALUES (@OrderID, @DishID, @Quantity, @Price, @Comment);
            SET @OrderItemID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.OrderItem
            SET Quantity = Quantity + @Quantity,
                ItemComment = ISNULL(@Comment, ItemComment)
            WHERE OrderItemID = @OrderItemID;
        END

        COMMIT;

        SELECT @OrderItemID AS OrderItemID,
               ISNULL((SELECT SUM(Quantity * PriceAtOrder) FROM dbo.OrderItem WHERE OrderID = @OrderID), 0) AS TotalAmount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CloseOrder
    @OrderID       INT,
    @EmployeeID    INT,
    @PaymentMethod NVARCHAR(20),
    @PaymentID     INT OUTPUT,
    @Amount        DECIMAL(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PaymentMethod NOT IN (N'Наличные', N'Карта', N'Онлайн')
        THROW 50311, N'Недопустимый способ оплаты', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE OrderID = @OrderID)
        THROW 50312, N'Заказ не найден', 1;
    IF EXISTS (SELECT 1 FROM dbo.Payment WHERE OrderID = @OrderID)
        THROW 50313, N'Заказ уже оплачен', 1;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Sum DECIMAL(12,2), @Discount DECIMAL(5,2) = 0, @CustomerID INT;
        SELECT @Sum = ISNULL(SUM(Quantity * PriceAtOrder), 0)
        FROM dbo.OrderItem WHERE OrderID = @OrderID;

        IF @Sum <= 0
            THROW 50314, N'В заказе нет позиций', 1;

        SELECT @CustomerID = CustomerID FROM dbo.[Order] WHERE OrderID = @OrderID;
        IF @CustomerID IS NOT NULL
        BEGIN
            DECLARE @PaidOrders INT =
                (SELECT COUNT(*) FROM dbo.[Order] WHERE CustomerID = @CustomerID AND OrderStatus = N'Оплачен');
            SET @Discount = CASE WHEN @PaidOrders >= 20 THEN 10 WHEN @PaidOrders >= 10 THEN 5 ELSE 0 END;
        END

        SET @Amount = CAST(@Sum * (1 - @Discount / 100.0) AS DECIMAL(12,2));

        UPDATE dbo.[Order]
        SET DiscountPercent = @Discount
        WHERE OrderID = @OrderID;

        INSERT INTO dbo.Payment (OrderID, EmployeeID, PaymentDate, Amount, PaymentMethod, PaymentStatus)
        VALUES (@OrderID, @EmployeeID, GETDATE(), @Amount, @PaymentMethod, N'Оплачен');
        SET @PaymentID = SCOPE_IDENTITY();

        UPDATE dbo.[Order]
        SET OrderStatus = N'Оплачен',
            ClosedAt = GETDATE()
        WHERE OrderID = @OrderID AND OrderStatus <> N'Оплачен';

        UPDATE dbo.RestaurantTable
        SET TableStatus = N'Свободен'
        WHERE TableID = (SELECT TableID FROM dbo.[Order] WHERE OrderID = @OrderID);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CancelOrder
    @OrderID INT,
    @Reason  NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF EXISTS (SELECT 1 FROM dbo.[Order] WHERE OrderID = @OrderID AND OrderStatus = N'Оплачен')
        THROW 50315, N'Оплаченный заказ нельзя отменить, оформите возврат', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE dbo.[Order]
        SET OrderStatus = N'Отменён',
            ClosedAt = GETDATE()
        WHERE OrderID = @OrderID AND OrderStatus NOT IN (N'Оплачен', N'Отменён');

        UPDATE dbo.RestaurantTable
        SET TableStatus = N'Свободен'
        WHERE TableID = (SELECT TableID FROM dbo.[Order] WHERE OrderID = @OrderID);

        UPDATE dbo.Payment
        SET PaymentStatus = N'Возврат'
        WHERE OrderID = @OrderID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ================= БРОНИРОВАНИЯ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Reservation_Get
    @DateFrom DATE = NULL,
    @DateTo DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM dbo.vw_ReservationSchedule
    WHERE (@DateFrom IS NULL OR CAST(ReservationDate AS DATE) >= @DateFrom)
      AND (@DateTo IS NULL OR CAST(ReservationDate AS DATE) <= @DateTo)
    ORDER BY ReservationDate;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Reservation_UpdateStatus
    @ReservationID INT,
    @Status NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Status NOT IN (N'Активна', N'Выполнена', N'Отменена')
        THROW 50316, N'Недопустимый статус бронирования', 1;

    UPDATE dbo.Reservation SET ReservationStatus = @Status WHERE ReservationID = @ReservationID;

    IF @Status IN (N'Выполнена', N'Отменена')
       AND NOT EXISTS (SELECT 1 FROM dbo.Reservation WHERE TableID = (SELECT TableID FROM dbo.Reservation WHERE ReservationID = @ReservationID) AND ReservationStatus = N'Активна')
        UPDATE dbo.RestaurantTable
        SET TableStatus = N'Свободен'
        WHERE TableID = (SELECT TableID FROM dbo.Reservation WHERE ReservationID = @ReservationID);
END
GO

/* ================= АУДИТ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Audit_Write
    @UserID     INT = NULL,
    @LoginName  NVARCHAR(100) = NULL,
    @ActionType NVARCHAR(40),
    @ObjectName NVARCHAR(80),
    @ObjectID   NVARCHAR(40) = NULL,
    @IPAddress  NVARCHAR(45) = NULL,
    @Details    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog (UserID, LoginName, ActionTime, ActionType, ObjectName, ObjectID, IPAddress, Details)
    VALUES (@UserID, @LoginName, GETDATE(), @ActionType, @ObjectName, @ObjectID, @IPAddress, @Details);
END
GO
