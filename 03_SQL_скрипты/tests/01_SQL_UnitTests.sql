/* ============================================================
   SQL unit-тесты для базы RestaurantDB
   Запуск: sqlcmd -S <server> -E -d RestaurantDB -i 01_SQL_UnitTests.sql
   Все изменения откатываются в конце каждого теста.
   ============================================================ */
USE RestaurantDB;
GO

IF SCHEMA_ID(N'test') IS NULL
    EXEC(N'CREATE SCHEMA test;');
GO

/* ---------- Вспомогательные процедуры проверок ---------- */
CREATE OR ALTER PROCEDURE test.AssertTrue
    @Condition BIT,
    @Message   NVARCHAR(300)
AS
BEGIN
    IF @Condition = 0
        THROW 59000, @Message, 1;
END
GO

CREATE OR ALTER PROCEDURE test.AssertEqualInt
    @Expected INT,
    @Actual   INT,
    @Message  NVARCHAR(300)
AS
BEGIN
    IF @Expected <> @Actual
        THROW 59001, @Message, 1;
END
GO

CREATE OR ALTER PROCEDURE test.AssertEqualDecimal
    @Expected DECIMAL(12,2),
    @Actual   DECIMAL(12,2),
    @Message  NVARCHAR(300)
AS
BEGIN
    IF @Expected <> @Actual
        THROW 59002, @Message, 1;
END
GO

/* ---------- Тест 1. fn_OrderTotal ---------- */
CREATE OR ALTER PROCEDURE test.Test_OrderTotal
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Total DECIMAL(12,2) = dbo.fn_OrderTotal(1);
    EXEC test.AssertEqualDecimal 5030.00, @Total, N'fn_OrderTotal: неверная сумма заказа 1';
END
GO

/* ---------- Тест 2. fn_DishesCountByCategory ---------- */
CREATE OR ALTER PROCEDURE test.Test_DishesCount
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Cnt INT = dbo.fn_DishesCountByCategory(4);
    EXEC test.AssertEqualInt 5, @Cnt, N'fn_DishesCountByCategory: ожидалось 5 блюд в категории 4';
END
GO

/* ---------- Тест 3. Создание заказа и обновление суммы ---------- */
CREATE OR ALTER PROCEDURE test.Test_CreateOrder
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @OrderID INT, @Total DECIMAL(12,2);
        EXEC dbo.sp_CreateOrder
            @TableID = 1, @CustomerID = 1, @EmployeeID = 3, @OrderType = N'В зале',
            @ItemsJson = N'[{"dishId":4,"quantity":1},{"dishId":23,"quantity":2}]',
            @OrderID = @OrderID OUTPUT;

        EXEC test.AssertTrue @Condition = IIF(@OrderID > 0, 1, 0), @Message = N'sp_CreateOrder: не создан заказ';

        SET @Total = dbo.fn_OrderTotal(@OrderID);
        EXEC test.AssertEqualDecimal 810.00, @Total, N'sp_CreateOrder: неверная сумма заказа';

        EXEC test.AssertTrue
            @Condition = IIF((SELECT TableStatus FROM dbo.RestaurantTable WHERE TableID = 1) = N'Занят', 1, 0),
            @Message = N'sp_CreateOrder: столик не переведён в статус «Занят»';

        ROLLBACK;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ---------- Тест 4. Добавление позиции и пересчёт триггером ---------- */
CREATE OR ALTER PROCEDURE test.Test_AddOrderItemAndTrigger
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @OrderID INT;
        EXEC dbo.sp_CreateOrder
            @TableID = 2, @EmployeeID = 3, @OrderType = N'В зале',
            @OrderID = @OrderID OUTPUT;

        EXEC dbo.sp_AddOrderItem @OrderID = @OrderID, @DishID = 1, @Quantity = 2;

        DECLARE @Total DECIMAL(12,2) = dbo.fn_OrderTotal(@OrderID);
        EXEC test.AssertEqualDecimal 640.00, @Total, N'sp_AddOrderItem: триггер не пересчитал сумму';

        ROLLBACK;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ---------- Тест 5. Запрет добавления недоступного блюда ---------- */
CREATE OR ALTER PROCEDURE test.Test_AddUnavailableDish
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @OrderID INT;
        EXEC dbo.sp_CreateOrder @TableID = 3, @EmployeeID = 3, @OrderType = N'В зале', @OrderID = @OrderID OUTPUT;

        BEGIN TRY
            EXEC dbo.sp_AddOrderItem @OrderID = @OrderID, @DishID = 9999, @Quantity = 1;
            ROLLBACK;
            THROW 59010, N'sp_AddOrderItem: недоступное блюдо не отклонено', 1;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            IF ERROR_NUMBER() = 59010 THROW;
            PRINT N'  ожидаемая ошибка: ' + ERROR_MESSAGE();
        END CATCH;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ---------- Тест 6. Оплата заказа ---------- */
CREATE OR ALTER PROCEDURE test.Test_CloseOrder
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @OrderID INT, @PaymentID INT, @Amount DECIMAL(12,2);
        EXEC dbo.sp_CreateOrder
            @TableID = 4, @EmployeeID = 3, @OrderType = N'В зале',
            @ItemsJson = N'[{"dishId":10,"quantity":1}]',
            @OrderID = @OrderID OUTPUT;

        EXEC dbo.sp_CloseOrder
            @OrderID = @OrderID, @EmployeeID = 4, @PaymentMethod = N'Карта',
            @PaymentID = @PaymentID OUTPUT, @Amount = @Amount OUTPUT;

        EXEC test.AssertEqualDecimal 1890.00, @Amount, N'sp_CloseOrder: неверная сумма оплаты';
        EXEC test.AssertTrue
            @Condition = IIF((SELECT OrderStatus FROM dbo.[Order] WHERE OrderID = @OrderID) = N'Оплачен', 1, 0),
            @Message = N'sp_CloseOrder: заказ не переведён в статус «Оплачен»';
        EXEC test.AssertTrue
            @Condition = IIF((SELECT COUNT(*) FROM dbo.Payment WHERE OrderID = @OrderID) = 1, 1, 0),
            @Message = N'sp_CloseOrder: платёж не создан';

        ROLLBACK;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ---------- Тест 7. История статусов ---------- */
CREATE OR ALTER PROCEDURE test.Test_StatusHistory
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @OrderID INT, @Cnt INT;
        EXEC dbo.sp_CreateOrder @TableID = 5, @EmployeeID = 3, @OrderType = N'В зале', @OrderID = @OrderID OUTPUT;
        EXEC dbo.sp_MoveOrderToKitchen @OrderID = @OrderID, @EmployeeID = 3;

        SELECT @Cnt = COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderID = @OrderID;
        EXEC test.AssertTrue @Condition = IIF(@Cnt >= 2, 1, 0), @Message = N'Триггер истории: нет записи о смене статуса';

        ROLLBACK;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ---------- Тест 8. Конфликт бронирования ---------- */
CREATE OR ALTER PROCEDURE test.Test_ReservationConflict
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @ReservationID INT;
        DECLARE @ConflictDate DATETIME = DATEADD(HOUR, 19, DATEADD(DAY, 1, CAST(GETDATE() AS DATE)));

        BEGIN TRY
            EXEC dbo.sp_CreateReservation
                @CustomerID = 7, @TableID = 10, @EmployeeID = 2,
                @ReservationDate = @ConflictDate, @GuestsCount = 4,
                @ReservationID = @ReservationID OUTPUT;
            ROLLBACK;
            THROW 59011, N'sp_CreateReservation: конфликт не обнаружен', 1;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            IF ERROR_NUMBER() = 59011 THROW;
            PRINT N'  ожидаемая ошибка: ' + ERROR_MESSAGE();
        END CATCH;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ---------- Тест 9. Проверка ограничения CK_Dish_Price ---------- */
CREATE OR ALTER PROCEDURE test.Test_DishPriceConstraint
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        BEGIN TRY
            INSERT INTO dbo.Dish (CategoryID, DishName, Price) VALUES (1, N'Тестовое блюдо', -1);
            ROLLBACK;
            THROW 59012, N'CHECK-ограничение цены не сработало', 1;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            IF ERROR_NUMBER() = 59012 THROW;
            PRINT N'  ожидаемая ошибка: ' + ERROR_MESSAGE();
        END CATCH;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ---------- Тест 10. RBAC: официант не читает AppUser ---------- */
CREATE OR ALTER PROCEDURE test.Test_RbacWaiter
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        EXECUTE AS USER = N'user_waiter_rest';
        BEGIN TRY
            SELECT TOP (1) * FROM dbo.AppUser;
            REVERT;
            THROW 59013, N'RBAC: официант смог прочитать AppUser', 1;
        END TRY
        BEGIN CATCH
            DECLARE @Msg NVARCHAR(4000) = ERROR_MESSAGE();
            IF USER_NAME() <> N'dbo' REVERT;
            IF @Msg LIKE N'%permission%' OR @Msg LIKE N'%denied%' OR @Msg LIKE N'%разрешени%'
                PRINT N'  ожидаемый запрет доступа: ' + @Msg;
            ELSE
                THROW;
        END CATCH;
    END TRY
    BEGIN CATCH
        IF USER_NAME() <> N'dbo' REVERT;
        THROW;
    END CATCH
END
GO

/* ---------- Тест 11. Отчётность выполняется без ошибок ---------- */
CREATE OR ALTER PROCEDURE test.Test_Reports
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Report_Revenue @DateFrom = '2024-01-01', @DateTo = '2030-12-31';
    EXEC dbo.sp_Report_PopularDishes @DateFrom = '2024-01-01', @DateTo = '2030-12-31', @Top = 5;
    EXEC dbo.sp_Report_WaiterPerformance @DateFrom = '2024-01-01', @DateTo = '2030-12-31';
    PRINT N'  отчёты выполнены без ошибок';
END
GO

/* ---------- Запуск всех тестов ---------- */
CREATE OR ALTER PROCEDURE test.RunAll
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Passed INT = 0, @Failed INT = 0, @Name NVARCHAR(100), @Msg NVARCHAR(4000);

    BEGIN TRY EXEC test.Test_OrderTotal;            SET @Passed += 1; PRINT N'PASS  Test_OrderTotal'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_OrderTotal: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_DishesCount;           SET @Passed += 1; PRINT N'PASS  Test_DishesCount'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_DishesCount: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_CreateOrder;           SET @Passed += 1; PRINT N'PASS  Test_CreateOrder'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_CreateOrder: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_AddOrderItemAndTrigger; SET @Passed += 1; PRINT N'PASS  Test_AddOrderItemAndTrigger'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_AddOrderItemAndTrigger: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_AddUnavailableDish;    SET @Passed += 1; PRINT N'PASS  Test_AddUnavailableDish'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_AddUnavailableDish: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_CloseOrder;            SET @Passed += 1; PRINT N'PASS  Test_CloseOrder'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_CloseOrder: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_StatusHistory;         SET @Passed += 1; PRINT N'PASS  Test_StatusHistory'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_StatusHistory: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_ReservationConflict;   SET @Passed += 1; PRINT N'PASS  Test_ReservationConflict'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_ReservationConflict: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_DishPriceConstraint;   SET @Passed += 1; PRINT N'PASS  Test_DishPriceConstraint'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_DishPriceConstraint: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_RbacWaiter;            SET @Passed += 1; PRINT N'PASS  Test_RbacWaiter'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_RbacWaiter: ' + ERROR_MESSAGE(); END CATCH;

    BEGIN TRY EXEC test.Test_Reports;               SET @Passed += 1; PRINT N'PASS  Test_Reports'; END TRY
    BEGIN CATCH SET @Failed += 1; PRINT N'FAIL  Test_Reports: ' + ERROR_MESSAGE(); END CATCH;

    PRINT CONCAT(N'ИТОГО: пройдено ', @Passed, N', провалено ', @Failed, N'.');
    IF @Failed > 0
        THROW 59099, N'Есть проваленные SQL-тесты', 1;
END
GO

EXEC test.RunAll;
GO
