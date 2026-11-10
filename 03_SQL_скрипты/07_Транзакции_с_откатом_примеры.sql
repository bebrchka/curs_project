-- 07_Транзакции_с_откатом_примеры.sql
USE RestaurantDB;
GO

-- Пример 1. Успешное оформление заказа с позициями
BEGIN TRAN;
DECLARE @OrderID INT;
EXEC dbo.sp_CreateOrder @TableID=1, @EmployeeID=2, @OrderType='В зале';
SET @OrderID = SCOPE_IDENTITY();
EXEC dbo.sp_AddOrderItem @OrderID=@OrderID, @DishID=1, @Quantity=2;
EXEC dbo.sp_AddOrderItem @OrderID=@OrderID, @DishID=7, @Quantity=2;
EXEC dbo.sp_MoveOrderToKitchen @OrderID=@OrderID;
COMMIT;
GO

-- Пример 2. Откат при попытке добавить позицию в оплаченный заказ
BEGIN TRAN;
DECLARE @OrderID2 INT = (SELECT TOP 1 OrderID FROM dbo.[Order] ORDER BY OrderID DESC);
UPDATE dbo.[Order] SET OrderStatus='Оплачен' WHERE OrderID=@OrderID2;
BEGIN TRY
    EXEC dbo.sp_AddOrderItem @OrderID=@OrderID2, @DishID=5, @Quantity=1;
    COMMIT;
END TRY
BEGIN CATCH
    PRINT 'Ошибка. Выполняется ROLLBACK';
    ROLLBACK;
END CATCH;
GO
