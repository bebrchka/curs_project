/* ============================================================
   Скрипт 02. Дополнительные ограничения целостности и индексы
   ============================================================ */
USE RestaurantDB;
GO

/* ---------- Дополнительные CHECK-ограничения ---------- */
ALTER TABLE dbo.[Order] WITH CHECK
    ADD CONSTRAINT CK_Order_TableRequired
    CHECK (OrderType <> N'В зале' OR TableID IS NOT NULL);
GO

ALTER TABLE dbo.[Order] WITH CHECK
    ADD CONSTRAINT CK_Order_DeliveryCustomer
    CHECK (OrderType <> N'Доставка' OR CustomerID IS NOT NULL);
GO

ALTER TABLE dbo.Customer WITH CHECK
    ADD CONSTRAINT CK_Customer_Email
    CHECK (Email IS NULL OR Email LIKE N'%_@_%._%');
GO

ALTER TABLE dbo.Reservation WITH CHECK
    ADD CONSTRAINT CK_Reservation_Date
    CHECK (ReservationDate >= CONVERT(DATETIME, '2024-01-01', 120));
GO

/* ---------- Индексы по внешним ключам и часто используемым полям ---------- */
CREATE INDEX IX_Employee_RoleID          ON dbo.Employee (RoleID);
CREATE UNIQUE INDEX UX_AppUser_EmployeeID
    ON dbo.AppUser (EmployeeID)
    WHERE EmployeeID IS NOT NULL;
CREATE INDEX IX_Dish_CategoryID          ON dbo.Dish (CategoryID);
CREATE INDEX IX_Dish_IsAvailable         ON dbo.Dish (IsAvailable) INCLUDE (DishName, Price);
CREATE INDEX IX_Reservation_TableID      ON dbo.Reservation (TableID);
CREATE INDEX IX_Reservation_CustomerID   ON dbo.Reservation (CustomerID);
CREATE INDEX IX_Reservation_Date         ON dbo.Reservation (ReservationDate) INCLUDE (ReservationStatus, TableID);
CREATE INDEX IX_Order_OrderDate          ON dbo.[Order] (OrderDate) INCLUDE (OrderStatus, TotalAmount);
CREATE INDEX IX_Order_OrderStatus        ON dbo.[Order] (OrderStatus) INCLUDE (OrderDate, TotalAmount);
CREATE INDEX IX_Order_TableID            ON dbo.[Order] (TableID);
CREATE INDEX IX_Order_CustomerID         ON dbo.[Order] (CustomerID);
CREATE INDEX IX_OrderItem_OrderID        ON dbo.OrderItem (OrderID);
CREATE INDEX IX_OrderItem_DishID         ON dbo.OrderItem (DishID);
CREATE INDEX IX_Payment_PaymentDate      ON dbo.Payment (PaymentDate) INCLUDE (Amount, PaymentMethod);
CREATE INDEX IX_History_OrderID          ON dbo.OrderStatusHistory (OrderID);
CREATE INDEX IX_AuditLog_ActionTime      ON dbo.AuditLog (ActionTime);
CREATE INDEX IX_AuditLog_Object           ON dbo.AuditLog (ObjectName, ObjectID);
GO

/* ---------- Уникальность позиции блюда в заказе ---------- */
CREATE UNIQUE INDEX UX_OrderItem_Order_Dish
    ON dbo.OrderItem (OrderID, DishID);
GO

/* ---------- Уникальность активного бронирования на конкретное время ---------- */
CREATE UNIQUE INDEX UX_Reservation_Table_Time
    ON dbo.Reservation (TableID, ReservationDate)
    WHERE ReservationStatus = N'Активна';
GO
