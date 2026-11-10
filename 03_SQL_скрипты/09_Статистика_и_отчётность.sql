/* ============================================================
   Скрипт 09. Подсистема статистики и отчётности
   ============================================================ */
USE RestaurantDB;
GO

/* ================= ПРЕДСТАВЛЕНИЯ ================= */

CREATE OR ALTER VIEW dbo.vw_RevenueByDay
AS
SELECT  CAST(p.PaymentDate AS DATE) AS RevenueDate,
        COUNT(*)                    AS PaymentsCount,
        SUM(p.Amount)               AS Revenue,
        CAST(AVG(p.Amount) AS DECIMAL(12,2)) AS AvgCheck
FROM dbo.Payment p
WHERE p.PaymentStatus = N'Оплачен'
GROUP BY CAST(p.PaymentDate AS DATE);
GO

CREATE OR ALTER VIEW dbo.vw_PopularDishes
AS
SELECT  d.DishID,
        d.DishName,
        c.CategoryName,
        SUM(oi.Quantity)                    AS TotalQuantity,
        SUM(oi.Quantity * oi.PriceAtOrder)  AS Revenue,
        COUNT(DISTINCT o.OrderID)           AS OrdersCount,
        MIN(o.OrderDate)                    AS FirstOrderDate,
        MAX(o.OrderDate)                    AS LastOrderDate
FROM dbo.OrderItem oi
JOIN dbo.Dish d ON d.DishID = oi.DishID
JOIN dbo.Category c ON c.CategoryID = d.CategoryID
JOIN dbo.[Order] o ON o.OrderID = oi.OrderID
WHERE o.OrderStatus <> N'Отменён'
GROUP BY d.DishID, d.DishName, c.CategoryName;
GO

CREATE OR ALTER VIEW dbo.vw_WaiterPerformance
AS
SELECT  e.EmployeeID,
        CONCAT(e.LastName, N' ', e.FirstName) AS EmployeeName,
        e.Post,
        COUNT(DISTINCT o.OrderID) AS OrdersCount,
        ISNULL(SUM(p.Amount), 0)  AS Revenue,
        CAST(ISNULL(AVG(p.Amount), 0) AS DECIMAL(12,2)) AS AvgCheck
FROM dbo.Employee e
LEFT JOIN dbo.[Order] o ON o.EmployeeID = e.EmployeeID AND o.OrderStatus = N'Оплачен'
LEFT JOIN dbo.Payment p ON p.OrderID = o.OrderID AND p.PaymentStatus = N'Оплачен'
GROUP BY e.EmployeeID, e.LastName, e.FirstName, e.Post;
GO

CREATE OR ALTER VIEW dbo.vw_TableLoad
AS
SELECT  t.TableID,
        t.TableNumber,
        t.Hall,
        t.Seats,
        COUNT(o.OrderID) AS OrdersCount,
        ISNULL(SUM(p.Amount), 0) AS Revenue,
        CAST(ISNULL(AVG(CASE WHEN o.ClosedAt IS NOT NULL
                             THEN DATEDIFF(MINUTE, o.OrderDate, o.ClosedAt) END), 0) AS DECIMAL(10,1)) AS AvgDurationMin
FROM dbo.RestaurantTable t
LEFT JOIN dbo.[Order] o ON o.TableID = t.TableID AND o.OrderStatus = N'Оплачен'
LEFT JOIN dbo.Payment p ON p.OrderID = o.OrderID AND p.PaymentStatus = N'Оплачен'
GROUP BY t.TableID, t.TableNumber, t.Hall, t.Seats;
GO

CREATE OR ALTER VIEW dbo.vw_HourlyLoad
AS
SELECT  DATEPART(HOUR, o.OrderDate) AS OrderHour,
        COUNT(*)                    AS OrdersCount,
        ISNULL(SUM(o.TotalAmount), 0) AS Revenue
FROM dbo.[Order] o
WHERE o.OrderStatus <> N'Отменён'
GROUP BY DATEPART(HOUR, o.OrderDate);
GO

CREATE OR ALTER VIEW dbo.vw_ReservationStats
AS
SELECT  CAST(r.ReservationDate AS DATE) AS ReservationDate,
        COUNT(*)                        AS TotalReservations,
        SUM(CASE WHEN r.ReservationStatus = N'Активна'   THEN 1 ELSE 0 END) AS ActiveCount,
        SUM(CASE WHEN r.ReservationStatus = N'Выполнена' THEN 1 ELSE 0 END) AS CompletedCount,
        SUM(CASE WHEN r.ReservationStatus = N'Отменена'  THEN 1 ELSE 0 END) AS CancelledCount,
        SUM(r.GuestsCount)              AS GuestsCount
FROM dbo.Reservation r
GROUP BY CAST(r.ReservationDate AS DATE);
GO

CREATE OR ALTER VIEW dbo.vw_OrderStatusSummary
AS
SELECT  o.OrderStatus,
        COUNT(*)             AS OrdersCount,
        ISNULL(SUM(o.TotalAmount), 0) AS TotalAmount
FROM dbo.[Order] o
GROUP BY o.OrderStatus;
GO

/* ================= ПРОЦЕДУРЫ ОТЧЁТОВ ================= */

CREATE OR ALTER PROCEDURE dbo.sp_Report_Revenue
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)));
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS DATE));

    SELECT  CAST(p.PaymentDate AS DATE) AS RevenueDate,
            COUNT(*)                    AS PaymentsCount,
            SUM(p.Amount)               AS Revenue,
            CAST(AVG(p.Amount) AS DECIMAL(12,2)) AS AvgCheck
    FROM dbo.Payment p
    WHERE p.PaymentStatus = N'Оплачен'
      AND CAST(p.PaymentDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY CAST(p.PaymentDate AS DATE)
    ORDER BY RevenueDate;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_PopularDishes
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL,
    @Top      INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)));
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS DATE));
    IF @Top <= 0 SET @Top = 10;

    SELECT TOP (@Top)
            ROW_NUMBER() OVER (ORDER BY SUM(oi.Quantity) DESC) AS Place,
            d.DishName,
            c.CategoryName,
            SUM(oi.Quantity)                   AS TotalQuantity,
            SUM(oi.Quantity * oi.PriceAtOrder) AS Revenue,
            COUNT(DISTINCT o.OrderID)          AS OrdersCount
    FROM dbo.OrderItem oi
    JOIN dbo.Dish d ON d.DishID = oi.DishID
    JOIN dbo.Category c ON c.CategoryID = d.CategoryID
    JOIN dbo.[Order] o ON o.OrderID = oi.OrderID
    WHERE o.OrderStatus <> N'Отменён'
      AND CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY d.DishID, d.DishName, c.CategoryName
    ORDER BY TotalQuantity DESC, Revenue DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_WaiterPerformance
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)));
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS DATE));

    SELECT  e.EmployeeID,
            CONCAT(e.LastName, N' ', e.FirstName) AS EmployeeName,
            e.Post,
            COUNT(DISTINCT o.OrderID) AS OrdersCount,
            ISNULL(SUM(p.Amount), 0)  AS Revenue,
            CAST(ISNULL(AVG(p.Amount), 0) AS DECIMAL(12,2)) AS AvgCheck
    FROM dbo.Employee e
    JOIN dbo.[Order] o ON o.EmployeeID = e.EmployeeID
    LEFT JOIN dbo.Payment p ON p.OrderID = o.OrderID AND p.PaymentStatus = N'Оплачен'
    WHERE o.OrderStatus = N'Оплачен'
      AND CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY e.EmployeeID, e.LastName, e.FirstName, e.Post
    ORDER BY Revenue DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_TableLoad
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)));
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS DATE));

    SELECT  t.TableNumber,
            t.Hall,
            t.Seats,
            COUNT(o.OrderID) AS OrdersCount,
            ISNULL(SUM(p.Amount), 0) AS Revenue,
            CAST(ISNULL(AVG(CASE WHEN o.ClosedAt IS NOT NULL
                                 THEN DATEDIFF(MINUTE, o.OrderDate, o.ClosedAt) END), 0) AS DECIMAL(10,1)) AS AvgDurationMin
    FROM dbo.RestaurantTable t
    LEFT JOIN dbo.[Order] o ON o.TableID = t.TableID
         AND o.OrderStatus = N'Оплачен'
         AND CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    LEFT JOIN dbo.Payment p ON p.OrderID = o.OrderID AND p.PaymentStatus = N'Оплачен'
    GROUP BY t.TableID, t.TableNumber, t.Hall, t.Seats
    ORDER BY Revenue DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_HourlyLoad
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)));
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS DATE));

    SELECT  DATEPART(HOUR, o.OrderDate) AS OrderHour,
            COUNT(*)                    AS OrdersCount,
            ISNULL(SUM(o.TotalAmount), 0) AS Revenue
    FROM dbo.[Order] o
    WHERE o.OrderStatus <> N'Отменён'
      AND CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY DATEPART(HOUR, o.OrderDate)
    ORDER BY OrderHour;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_ReservationStats
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)));
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS DATE));

    SELECT  CAST(r.ReservationDate AS DATE) AS ReservationDate,
            COUNT(*) AS TotalReservations,
            SUM(CASE WHEN r.ReservationStatus = N'Активна'   THEN 1 ELSE 0 END) AS ActiveCount,
            SUM(CASE WHEN r.ReservationStatus = N'Выполнена' THEN 1 ELSE 0 END) AS CompletedCount,
            SUM(CASE WHEN r.ReservationStatus = N'Отменена'  THEN 1 ELSE 0 END) AS CancelledCount,
            SUM(r.GuestsCount) AS GuestsCount
    FROM dbo.Reservation r
    WHERE CAST(r.ReservationDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY CAST(r.ReservationDate AS DATE)
    ORDER BY ReservationDate;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_OrderStatusSummary
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)));
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS DATE));

    SELECT  o.OrderStatus,
            COUNT(*) AS OrdersCount,
            ISNULL(SUM(o.TotalAmount), 0) AS TotalAmount
    FROM dbo.[Order] o
    WHERE CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY o.OrderStatus
    ORDER BY OrdersCount DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_Dashboard
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)));
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS DATE));

    /* 1. Ключевые показатели */
    SELECT
        ISNULL((SELECT SUM(p.Amount) FROM dbo.Payment p
                WHERE p.PaymentStatus = N'Оплачен'
                  AND CAST(p.PaymentDate AS DATE) BETWEEN @DateFrom AND @DateTo), 0) AS Revenue,
        (SELECT COUNT(*) FROM dbo.[Order] o
         WHERE CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo) AS OrdersCount,
        ISNULL((SELECT CAST(AVG(p.Amount) AS DECIMAL(12,2)) FROM dbo.Payment p
                WHERE p.PaymentStatus = N'Оплачен'
                  AND CAST(p.PaymentDate AS DATE) BETWEEN @DateFrom AND @DateTo), 0) AS AvgCheck,
        (SELECT COUNT(*) FROM dbo.Reservation r
         WHERE CAST(r.ReservationDate AS DATE) BETWEEN @DateFrom AND @DateTo) AS ReservationsCount,
        (SELECT COUNT(*) FROM dbo.[Order] o
         WHERE o.OrderStatus IN (N'Оформлен', N'Готовится', N'Готов')) AS ActiveOrders;

    /* 2. Выручка по дням */
    SELECT CAST(p.PaymentDate AS DATE) AS RevenueDate,
           SUM(p.Amount) AS Revenue,
           COUNT(*) AS PaymentsCount
    FROM dbo.Payment p
    WHERE p.PaymentStatus = N'Оплачен'
      AND CAST(p.PaymentDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY CAST(p.PaymentDate AS DATE)
    ORDER BY RevenueDate;

    /* 3. Топ-10 блюд */
    SELECT TOP (10)
            d.DishName,
            c.CategoryName,
            SUM(oi.Quantity) AS TotalQuantity,
            SUM(oi.Quantity * oi.PriceAtOrder) AS Revenue
    FROM dbo.OrderItem oi
    JOIN dbo.Dish d ON d.DishID = oi.DishID
    JOIN dbo.Category c ON c.CategoryID = d.CategoryID
    JOIN dbo.[Order] o ON o.OrderID = oi.OrderID
    WHERE o.OrderStatus <> N'Отменён'
      AND CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY d.DishName, c.CategoryName
    ORDER BY TotalQuantity DESC;

    /* 4. Эффективность официантов */
    SELECT CONCAT(e.LastName, N' ', e.FirstName) AS EmployeeName,
           COUNT(DISTINCT o.OrderID) AS OrdersCount,
           ISNULL(SUM(p.Amount), 0) AS Revenue
    FROM dbo.Employee e
    JOIN dbo.[Order] o ON o.EmployeeID = e.EmployeeID AND o.OrderStatus = N'Оплачен'
    LEFT JOIN dbo.Payment p ON p.OrderID = o.OrderID AND p.PaymentStatus = N'Оплачен'
    WHERE CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY e.EmployeeID, e.LastName, e.FirstName
    ORDER BY Revenue DESC;

    /* 5. Загрузка столиков */
    SELECT t.TableNumber, t.Hall, COUNT(o.OrderID) AS OrdersCount,
           ISNULL(SUM(p.Amount), 0) AS Revenue
    FROM dbo.RestaurantTable t
    LEFT JOIN dbo.[Order] o ON o.TableID = t.TableID
         AND o.OrderStatus = N'Оплачен'
         AND CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    LEFT JOIN dbo.Payment p ON p.OrderID = o.OrderID AND p.PaymentStatus = N'Оплачен'
    GROUP BY t.TableID, t.TableNumber, t.Hall
    ORDER BY Revenue DESC;

    /* 6. Нагрузка по часам */
    SELECT DATEPART(HOUR, o.OrderDate) AS OrderHour,
           COUNT(*) AS OrdersCount
    FROM dbo.[Order] o
    WHERE o.OrderStatus <> N'Отменён'
      AND CAST(o.OrderDate AS DATE) BETWEEN @DateFrom AND @DateTo
    GROUP BY DATEPART(HOUR, o.OrderDate)
    ORDER BY OrderHour;
END
GO

PRINT N'Подсистема статистики и отчётности создана.';
GO
