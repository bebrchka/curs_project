/* ============================================================
   Скрипт 07. Транзакции и откаты
   Все примеры можно выполнять по отдельности.
   ============================================================ */
USE RestaurantDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ------------------------------------------------------------
   Пример 1. Успешное оформление заказа с позициями и оплатой.
   Транзакция охватывает создание заказа, позиции и платёж.
   ------------------------------------------------------------ */
BEGIN TRY
    BEGIN TRAN;

    DECLARE @OrderID INT, @PaymentID INT, @Amount DECIMAL(12,2);

    EXEC dbo.sp_CreateOrder
        @TableID = 1,
        @CustomerID = 1,
        @EmployeeID = 3,
        @OrderType = N'В зале',
        @Notes = N'Пример транзакции: успешный заказ',
        @ItemsJson = N'[{"dishId":4,"quantity":1},{"dishId":23,"quantity":2}]',
        @OrderID = @OrderID OUTPUT;

    EXEC dbo.sp_CloseOrder
        @OrderID = @OrderID,
        @EmployeeID = 4,
        @PaymentMethod = N'Карта',
        @PaymentID = @PaymentID OUTPUT,
        @Amount = @Amount OUTPUT;

    COMMIT;
    PRINT CONCAT(N'Пример 1: заказ ', @OrderID, N' оплачен на сумму ', @Amount, N' руб.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'Пример 1: ошибка, выполнен ROLLBACK. ', ERROR_MESSAGE());
END CATCH;
GO

/* ------------------------------------------------------------
   Пример 2. Откат при попытке добавить позицию в оплаченный заказ.
   ------------------------------------------------------------ */
BEGIN TRY
    BEGIN TRAN;

    DECLARE @PaidOrderID INT =
        (SELECT TOP (1) OrderID FROM dbo.[Order] WHERE OrderStatus = N'Оплачен' ORDER BY OrderID);

    PRINT CONCAT(N'Пример 2: пробуем изменить оплаченный заказ ', @PaidOrderID);

    EXEC dbo.sp_AddOrderItem
        @OrderID = @PaidOrderID,
        @DishID = 5,
        @Quantity = 1;

    COMMIT;
    PRINT N'Пример 2: неожиданно успешно (проверьте статус заказа).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'Пример 2: ожидаемый ROLLBACK. ', ERROR_MESSAGE());
END CATCH;
GO

/* ------------------------------------------------------------
   Пример 3. Откат при конфликте бронирования.
   Столик 10 уже забронирован на завтра в 19:00.
   ------------------------------------------------------------ */
BEGIN TRY
    BEGIN TRAN;

    DECLARE @ReservationID INT;
    DECLARE @ConflictDate DATETIME =
        DATEADD(HOUR, 19, DATEADD(DAY, 1, CAST(GETDATE() AS DATE)));

    EXEC dbo.sp_CreateReservation
        @CustomerID = 7,
        @TableID = 10,
        @EmployeeID = 2,
        @ReservationDate = @ConflictDate,
        @GuestsCount = 4,
        @Notes = N'Пример конфликта бронирования',
        @ReservationID = @ReservationID OUTPUT;

    COMMIT;
    PRINT N'Пример 3: бронирование создано.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'Пример 3: ожидаемый ROLLBACK. ', ERROR_MESSAGE());
END CATCH;
GO

/* ------------------------------------------------------------
   Пример 4. Точка сохранения (SAVE TRANSACTION).
   Откатывается только вторая операция, первая остаётся.
   ------------------------------------------------------------ */
BEGIN TRY
    BEGIN TRAN;

    DECLARE @OrderID4 INT;
    EXEC dbo.sp_CreateOrder
        @TableID = 2,
        @CustomerID = 2,
        @EmployeeID = 6,
        @OrderType = N'В зале',
        @Notes = N'Пример SAVE TRANSACTION',
        @OrderID = @OrderID4 OUTPUT;

    SAVE TRANSACTION BeforeItem;

    BEGIN TRY
        EXEC dbo.sp_AddOrderItem @OrderID = @OrderID4, @DishID = 9999, @Quantity = 1;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION BeforeItem;
        PRINT CONCAT(N'Пример 4: позиция отменена, заказ сохранён. ', ERROR_MESSAGE());
    END CATCH;

    COMMIT;
    PRINT CONCAT(N'Пример 4: заказ ', @OrderID4, N' создан без некорректной позиции.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'Пример 4: ROLLBACK. ', ERROR_MESSAGE());
END CATCH;
GO
