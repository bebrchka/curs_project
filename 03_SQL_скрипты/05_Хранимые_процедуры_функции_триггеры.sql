/* ============================================================
   Скрипт 05. Расширенная серверная логика:
   функции, хранимые процедуры, триггеры, аудит
   ============================================================ */
USE RestaurantDB;
GO

/* ================= ФУНКЦИИ ================= */

CREATE OR ALTER FUNCTION dbo.fn_OrderTotal (@OrderID INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Total DECIMAL(12,2) = 0;
    SELECT @Total = ISNULL(SUM(Quantity * PriceAtOrder), 0)
    FROM dbo.OrderItem
    WHERE OrderID = @OrderID;
    RETURN @Total;
END
GO

CREATE OR ALTER FUNCTION dbo.fn_DishesCountByCategory (@CategoryID INT)
RETURNS INT
AS
BEGIN
    DECLARE @Cnt INT = 0;
    SELECT @Cnt = COUNT(*)
    FROM dbo.Dish
    WHERE CategoryID = @CategoryID AND IsAvailable = 1;
    RETURN @Cnt;
END
GO

CREATE OR ALTER FUNCTION dbo.fn_TableBusyHours (@TableID INT, @Date DATE)
RETURNS INT
AS
BEGIN
    DECLARE @Hours INT = 0;
    SELECT @Hours = COUNT(DISTINCT DATEPART(HOUR, OrderDate))
    FROM dbo.[Order]
    WHERE TableID = @TableID
      AND CAST(OrderDate AS DATE) = @Date
      AND OrderStatus IN (N'Готовится', N'Готов', N'Оплачен');
    RETURN @Hours;
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetDiscount (@OrderID INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @CustomerID INT, @PaidOrders INT, @Discount DECIMAL(5,2) = 0;
    SELECT @CustomerID = CustomerID FROM dbo.[Order] WHERE OrderID = @OrderID;
    IF @CustomerID IS NULL RETURN 0;

    SELECT @PaidOrders = COUNT(*)
    FROM dbo.[Order]
    WHERE CustomerID = @CustomerID AND OrderStatus = N'Оплачен';

    SET @Discount = CASE
        WHEN @PaidOrders >= 20 THEN 10
        WHEN @PaidOrders >= 10 THEN 5
        ELSE 0
    END;
    RETURN @Discount;
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetRevenue (@DateFrom DATE, @DateTo DATE)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Revenue DECIMAL(12,2) = 0;
    SELECT @Revenue = ISNULL(SUM(Amount), 0)
    FROM dbo.Payment
    WHERE PaymentStatus = N'Оплачен'
      AND CAST(PaymentDate AS DATE) BETWEEN @DateFrom AND @DateTo;
    RETURN @Revenue;
END
GO

/* ================= ПРОЦЕДУРЫ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Order_UpdateStatus
    @OrderID    INT,
    @NewStatus  NVARCHAR(20),
    @EmployeeID INT = NULL,
    @Comment    NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @NewStatus NOT IN (N'Оформлен', N'Готовится', N'Готов', N'Оплачен', N'Отменён')
        THROW 50401, N'Недопустимый статус заказа', 1;

    DECLARE @OldStatus NVARCHAR(20);
    SELECT @OldStatus = OrderStatus FROM dbo.[Order] WHERE OrderID = @OrderID;

    IF @OldStatus IS NULL
        THROW 50402, N'Заказ не найден', 1;
    IF @OldStatus = @NewStatus
        RETURN;

    IF NOT (
        (@OldStatus = N'Оформлен' AND @NewStatus IN (N'Готовится', N'Отменён')) OR
        (@OldStatus = N'Готовится' AND @NewStatus IN (N'Готов', N'Отменён')) OR
        (@OldStatus = N'Готов' AND @NewStatus IN (N'Оплачен', N'Отменён'))
    )
        THROW 50403, N'Недопустимый переход статуса заказа', 1;

    IF @NewStatus = N'Оплачен' AND NOT EXISTS (SELECT 1 FROM dbo.Payment WHERE OrderID = @OrderID)
        THROW 50404, N'Для оплаты используйте процедуру sp_CloseOrder', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE dbo.[Order]
        SET OrderStatus = @NewStatus,
            ClosedAt = CASE WHEN @NewStatus IN (N'Оплачен', N'Отменён') THEN GETDATE() ELSE ClosedAt END
        WHERE OrderID = @OrderID;

        IF @NewStatus = N'Отменён'
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

CREATE OR ALTER PROCEDURE dbo.sp_MoveOrderToKitchen
    @OrderID    INT,
    @EmployeeID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Order_UpdateStatus @OrderID = @OrderID, @NewStatus = N'Готовится',
         @EmployeeID = @EmployeeID, @Comment = N'Передан на кухню';
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_MarkOrderReady
    @OrderID    INT,
    @EmployeeID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Order_UpdateStatus @OrderID = @OrderID, @NewStatus = N'Готов',
         @EmployeeID = @EmployeeID, @Comment = N'Блюда приготовлены';
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreateReservation
    @CustomerID      INT,
    @TableID         INT,
    @EmployeeID      INT,
    @ReservationDate DATETIME,
    @GuestsCount     INT,
    @Notes           NVARCHAR(200) = NULL,
    @ReservationID   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE CustomerID = @CustomerID)
        THROW 50410, N'Клиент не найден', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Employee WHERE EmployeeID = @EmployeeID AND IsActive = 1)
        THROW 50411, N'Сотрудник не найден', 1;
    IF @ReservationDate < GETDATE()
        THROW 50412, N'Нельзя забронировать столик на прошедшее время', 1;
    IF @GuestsCount <= 0
        THROW 50413, N'Количество гостей должно быть положительным', 1;

    DECLARE @Seats INT, @TableStatus NVARCHAR(20);
    SELECT @Seats = Seats, @TableStatus = TableStatus
    FROM dbo.RestaurantTable WHERE TableID = @TableID;

    IF @Seats IS NULL
        THROW 50414, N'Столик не найден', 1;
    IF @TableStatus = N'Неактивен'
        THROW 50415, N'Столик недоступен для бронирования', 1;
    IF @GuestsCount > @Seats
        THROW 50416, N'Количество гостей превышает вместимость столика', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.Reservation
        WHERE TableID = @TableID
          AND ReservationStatus = N'Активна'
          AND ABS(DATEDIFF(MINUTE, ReservationDate, @ReservationDate)) < 120
    )
        THROW 50417, N'Столик уже забронирован на это время (интервал 2 часа)', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.Reservation
            (CustomerID, TableID, EmployeeID, ReservationDate, GuestsCount, ReservationStatus, Notes)
        VALUES
            (@CustomerID, @TableID, @EmployeeID, @ReservationDate, @GuestsCount, N'Активна', @Notes);

        SET @ReservationID = SCOPE_IDENTITY();

        IF @TableStatus <> N'Занят'
            UPDATE dbo.RestaurantTable SET TableStatus = N'Забронирован' WHERE TableID = @TableID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CancelReservation
    @ReservationID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TableID INT;
    SELECT @TableID = TableID FROM dbo.Reservation WHERE ReservationID = @ReservationID;
    IF @TableID IS NULL
        THROW 50418, N'Бронирование не найдено', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE dbo.Reservation
        SET ReservationStatus = N'Отменена'
        WHERE ReservationID = @ReservationID;

        IF NOT EXISTS (SELECT 1 FROM dbo.Reservation WHERE TableID = @TableID AND ReservationStatus = N'Активна')
            UPDATE dbo.RestaurantTable SET TableStatus = N'Свободен' WHERE TableID = @TableID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAuditLog
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL,
    @Login    NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT LogID, UserID, LoginName, ActionTime, ActionType, ObjectName, ObjectID, IPAddress, Details
    FROM dbo.AuditLog
    WHERE (@DateFrom IS NULL OR CAST(ActionTime AS DATE) >= @DateFrom)
      AND (@DateTo IS NULL OR CAST(ActionTime AS DATE) <= @DateTo)
      AND (@Login IS NULL OR LoginName = @Login)
    ORDER BY ActionTime DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetTableAvailability
    @ReservationDate DATETIME,
    @GuestsCount INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT t.TableID, t.TableNumber, t.Seats, t.Hall, t.TableStatus
    FROM dbo.RestaurantTable t
    WHERE t.TableStatus <> N'Неактивен'
      AND t.Seats >= @GuestsCount
      AND NOT EXISTS (
          SELECT 1 FROM dbo.Reservation r
          WHERE r.TableID = t.TableID
            AND r.ReservationStatus = N'Активна'
            AND ABS(DATEDIFF(MINUTE, r.ReservationDate, @ReservationDate)) < 120
      )
    ORDER BY t.Seats, t.TableNumber;
END
GO

/* ================= ТРИГГЕРЫ ================= */

CREATE OR ALTER TRIGGER dbo.trg_OrderItem_UpdateTotal
ON dbo.OrderItem
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE o
    SET TotalAmount = ISNULL((
        SELECT SUM(oi.Quantity * oi.PriceAtOrder)
        FROM dbo.OrderItem oi
        WHERE oi.OrderID = o.OrderID
    ), 0)
    FROM dbo.[Order] o
    WHERE o.OrderID IN (
        SELECT OrderID FROM inserted
        UNION
        SELECT OrderID FROM deleted
    );
END
GO

CREATE OR ALTER TRIGGER dbo.trg_Order_StatusHistory
ON dbo.[Order]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.OrderStatusHistory (OrderID, OldStatus, NewStatus, ChangedBy, Comment)
    SELECT  i.OrderID,
            d.OrderStatus,
            i.OrderStatus,
            SUSER_SNAME(),
            CASE WHEN d.OrderID IS NULL THEN N'Создание заказа' ELSE N'Изменение статуса' END
    FROM inserted i
    LEFT JOIN deleted d ON d.OrderID = i.OrderID
    WHERE d.OrderID IS NULL OR i.OrderStatus <> d.OrderStatus;
END
GO

CREATE OR ALTER TRIGGER dbo.trg_Payment_UpdateOrder
ON dbo.Payment
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE o
    SET OrderStatus = N'Оплачен',
        ClosedAt = GETDATE()
    FROM dbo.[Order] o
    JOIN inserted p ON p.OrderID = o.OrderID
    WHERE o.OrderStatus <> N'Оплачен';

    UPDATE t
    SET TableStatus = N'Свободен'
    FROM dbo.RestaurantTable t
    JOIN dbo.[Order] o ON o.TableID = t.TableID
    JOIN inserted p ON p.OrderID = o.OrderID;
END
GO

CREATE OR ALTER TRIGGER dbo.trg_Audit_OrderItem
ON dbo.OrderItem
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLog (LoginName, ActionTime, ActionType, ObjectName, ObjectID, Details)
    SELECT  SUSER_SNAME(),
            GETDATE(),
            CASE
                WHEN d.OrderItemID IS NULL THEN N'INSERT'
                WHEN i.OrderItemID IS NULL THEN N'DELETE'
                ELSE N'UPDATE'
            END,
            N'OrderItem',
            CAST(COALESCE(i.OrderItemID, d.OrderItemID) AS NVARCHAR(40)),
            CONCAT(N'OrderID=', COALESCE(i.OrderID, d.OrderID),
                   N'; Quantity=', COALESCE(i.Quantity, 0),
                   N' (было ', COALESCE(d.Quantity, 0), N')')
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.OrderItemID = i.OrderItemID;
END
GO

CREATE OR ALTER TRIGGER dbo.trg_Audit_Reservation
ON dbo.Reservation
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLog (LoginName, ActionTime, ActionType, ObjectName, ObjectID, Details)
    SELECT  SUSER_SNAME(),
            GETDATE(),
            CASE WHEN d.ReservationID IS NULL THEN N'INSERT' ELSE N'UPDATE' END,
            N'Reservation',
            CAST(i.ReservationID AS NVARCHAR(40)),
            CONCAT(N'TableID=', i.TableID,
                   N'; Date=', CONVERT(NVARCHAR(19), i.ReservationDate, 120),
                   N'; Status=', i.ReservationStatus)
    FROM inserted i
    LEFT JOIN deleted d ON d.ReservationID = i.ReservationID;
END
GO

CREATE OR ALTER TRIGGER dbo.trg_Dish_PriceAudit
ON dbo.Dish
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLog (LoginName, ActionTime, ActionType, ObjectName, ObjectID, Details)
    SELECT  SUSER_SNAME(),
            GETDATE(),
            N'PRICE_CHANGE',
            N'Dish',
            CAST(i.DishID AS NVARCHAR(40)),
            CONCAT(N'Цена изменена: ', d.Price, N' -> ', i.Price)
    FROM inserted i
    JOIN deleted d ON d.DishID = i.DishID
    WHERE i.Price <> d.Price;
END
GO
