/* ============================================================
   Скрипт 06. Разграничение прав доступа (RBAC), логины и роли
   Внимание: пароли в скрипте — демонстрационные.
   В продуктивной среде используются случайные пароли и CHECK_POLICY=ON.
   ============================================================ */
USE master;
GO

/* ---------- SQL-логины ---------- */
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'login_admin_rest')
    EXEC(N'CREATE LOGIN login_admin_rest WITH PASSWORD = N''Adm1n_Rest_2026!'', CHECK_POLICY = OFF;');
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'login_manager_rest')
    EXEC(N'CREATE LOGIN login_manager_rest WITH PASSWORD = N''Mgr_Rest_2026!'', CHECK_POLICY = OFF;');
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'login_waiter_rest')
    EXEC(N'CREATE LOGIN login_waiter_rest WITH PASSWORD = N''Wtr_Rest_2026!'', CHECK_POLICY = OFF;');
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'login_cashier_rest')
    EXEC(N'CREATE LOGIN login_cashier_rest WITH PASSWORD = N''Csr_Rest_2026!'', CHECK_POLICY = OFF;');
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'login_chef_rest')
    EXEC(N'CREATE LOGIN login_chef_rest WITH PASSWORD = N''Chef_Rest_2026!'', CHECK_POLICY = OFF;');
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'login_reports_rest')
    EXEC(N'CREATE LOGIN login_reports_rest WITH PASSWORD = N''Rpt_Rest_2026!'', CHECK_POLICY = OFF;');
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'login_app_rest')
    EXEC(N'CREATE LOGIN login_app_rest WITH PASSWORD = N''App_Rest_2026!'', CHECK_POLICY = OFF;');
GO

USE RestaurantDB;
GO

/* ---------- Пользователи базы данных ---------- */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_admin_rest')
    CREATE USER user_admin_rest FOR LOGIN login_admin_rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_manager_rest')
    CREATE USER user_manager_rest FOR LOGIN login_manager_rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_waiter_rest')
    CREATE USER user_waiter_rest FOR LOGIN login_waiter_rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_cashier_rest')
    CREATE USER user_cashier_rest FOR LOGIN login_cashier_rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_chef_rest')
    CREATE USER user_chef_rest FOR LOGIN login_chef_rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_reports_rest')
    CREATE USER user_reports_rest FOR LOGIN login_reports_rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_app_rest')
    CREATE USER user_app_rest FOR LOGIN login_app_rest;
GO

/* ---------- Роли базы данных ---------- */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_Director_Rest' AND type = 'R')
    CREATE ROLE role_Director_Rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_Manager_Rest' AND type = 'R')
    CREATE ROLE role_Manager_Rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_Waiter_Rest' AND type = 'R')
    CREATE ROLE role_Waiter_Rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_Cashier_Rest' AND type = 'R')
    CREATE ROLE role_Cashier_Rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_Chef_Rest' AND type = 'R')
    CREATE ROLE role_Chef_Rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_Reports_Rest' AND type = 'R')
    CREATE ROLE role_Reports_Rest;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_App_Rest' AND type = 'R')
    CREATE ROLE role_App_Rest;
GO

/* ---------- Директор: полный доступ в пределах БД ---------- */
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO role_Director_Rest;
GRANT EXECUTE ON SCHEMA::dbo TO role_Director_Rest;
GRANT VIEW DEFINITION ON DATABASE::RestaurantDB TO role_Director_Rest;
GO

/* ---------- Менеджер: меню, заказы, бронирования, отчёты ---------- */
GRANT SELECT, INSERT, UPDATE ON dbo.Category TO role_Manager_Rest;
GRANT SELECT, INSERT, UPDATE ON dbo.Dish TO role_Manager_Rest;
GRANT SELECT, INSERT, UPDATE ON dbo.RestaurantTable TO role_Manager_Rest;
GRANT SELECT, INSERT, UPDATE ON dbo.Customer TO role_Manager_Rest;
GRANT SELECT, INSERT, UPDATE ON dbo.Reservation TO role_Manager_Rest;
GRANT SELECT, INSERT, UPDATE ON dbo.[Order] TO role_Manager_Rest;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.OrderItem TO role_Manager_Rest;
GRANT SELECT, INSERT, UPDATE ON dbo.Payment TO role_Manager_Rest;
GRANT SELECT ON dbo.Employee TO role_Manager_Rest;
GRANT SELECT ON dbo.vw_Menu TO role_Manager_Rest;
GRANT SELECT ON dbo.vw_ActiveOrders TO role_Manager_Rest;
GRANT SELECT ON dbo.vw_OrderBill TO role_Manager_Rest;
GRANT SELECT ON dbo.vw_ReservationSchedule TO role_Manager_Rest;
GRANT SELECT ON dbo.vw_OrderDetails TO role_Manager_Rest;
GRANT SELECT ON dbo.vw_CustomerMasked TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_CreateOrder TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_AddOrderItem TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_CloseOrder TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_CancelOrder TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_CreateReservation TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_CancelReservation TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_Order_UpdateStatus TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_MoveOrderToKitchen TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_MarkOrderReady TO role_Manager_Rest;
GRANT EXECUTE ON dbo.sp_Audit_Write TO role_Manager_Rest;
GO

/* ---------- Официант: заказы, столики, бронирования ---------- */
GRANT SELECT ON dbo.vw_Menu TO role_Waiter_Rest;
GRANT SELECT ON dbo.vw_ActiveOrders TO role_Waiter_Rest;
GRANT SELECT ON dbo.vw_OrderBill TO role_Waiter_Rest;
GRANT SELECT ON dbo.vw_ReservationSchedule TO role_Waiter_Rest;
GRANT SELECT ON dbo.RestaurantTable TO role_Waiter_Rest;
GRANT SELECT ON dbo.Customer TO role_Waiter_Rest;
GRANT SELECT ON dbo.vw_CustomerMasked TO role_Waiter_Rest;
GRANT SELECT ON dbo.[Order] TO role_Waiter_Rest;
GRANT SELECT ON dbo.OrderItem TO role_Waiter_Rest;
GRANT INSERT, UPDATE ON dbo.[Order] TO role_Waiter_Rest;
GRANT INSERT, UPDATE ON dbo.OrderItem TO role_Waiter_Rest;
GRANT EXECUTE ON dbo.sp_CreateOrder TO role_Waiter_Rest;
GRANT EXECUTE ON dbo.sp_AddOrderItem TO role_Waiter_Rest;
GRANT EXECUTE ON dbo.sp_MoveOrderToKitchen TO role_Waiter_Rest;
GRANT EXECUTE ON dbo.sp_CreateReservation TO role_Waiter_Rest;
GRANT EXECUTE ON dbo.sp_CancelReservation TO role_Waiter_Rest;
GRANT EXECUTE ON dbo.sp_GetTableAvailability TO role_Waiter_Rest;
GRANT EXECUTE ON dbo.sp_Audit_Write TO role_Waiter_Rest;
GO

/* ---------- Кассир: оплата и просмотр заказов ---------- */
GRANT SELECT ON dbo.vw_Menu TO role_Cashier_Rest;
GRANT SELECT ON dbo.vw_ActiveOrders TO role_Cashier_Rest;
GRANT SELECT ON dbo.vw_OrderBill TO role_Cashier_Rest;
GRANT SELECT ON dbo.vw_CustomerMasked TO role_Cashier_Rest;
GRANT SELECT ON dbo.[Order] TO role_Cashier_Rest;
GRANT SELECT ON dbo.OrderItem TO role_Cashier_Rest;
GRANT SELECT, INSERT ON dbo.Payment TO role_Cashier_Rest;
GRANT EXECUTE ON dbo.sp_CloseOrder TO role_Cashier_Rest;
GRANT EXECUTE ON dbo.sp_Audit_Write TO role_Cashier_Rest;
GO

/* ---------- Повар: кухня и статусы ---------- */
GRANT SELECT ON dbo.vw_Menu TO role_Chef_Rest;
GRANT SELECT ON dbo.vw_ActiveOrders TO role_Chef_Rest;
GRANT SELECT ON dbo.vw_CustomerMasked TO role_Chef_Rest;
GRANT SELECT ON dbo.vw_OrderBill TO role_Chef_Rest;
GRANT SELECT ON dbo.[Order] TO role_Chef_Rest;
GRANT SELECT ON dbo.OrderItem TO role_Chef_Rest;
GRANT EXECUTE ON dbo.sp_MoveOrderToKitchen TO role_Chef_Rest;
GRANT EXECUTE ON dbo.sp_MarkOrderReady TO role_Chef_Rest;
GRANT EXECUTE ON dbo.sp_Order_UpdateStatus TO role_Chef_Rest;
GRANT EXECUTE ON dbo.sp_Audit_Write TO role_Chef_Rest;
GO

/* ---------- Сервис отчётности: только чтение представлений ---------- */
GRANT SELECT ON dbo.vw_Menu TO role_Reports_Rest;
GRANT SELECT ON dbo.vw_ActiveOrders TO role_Reports_Rest;
GRANT SELECT ON dbo.vw_OrderBill TO role_Reports_Rest;
GRANT SELECT ON dbo.vw_ReservationSchedule TO role_Reports_Rest;
GRANT SELECT ON dbo.vw_OrderDetails TO role_Reports_Rest;
GRANT SELECT ON dbo.vw_CustomerMasked TO role_Reports_Rest;
GRANT EXECUTE ON dbo.sp_GetAuditLog TO role_Reports_Rest;
GO

/* ---------- Сервисный аккаунт веб-приложения ---------- */
GRANT SELECT ON SCHEMA::dbo TO role_App_Rest;
GRANT INSERT, UPDATE, DELETE ON SCHEMA::dbo TO role_App_Rest;
GRANT EXECUTE ON SCHEMA::dbo TO role_App_Rest;
GO

/* ---------- Отчёты: выдача прав после создания объектов (динамически) ---------- */
IF OBJECT_ID(N'dbo.sp_Report_Dashboard', N'P') IS NOT NULL
    EXEC(N'GRANT EXECUTE ON dbo.sp_Report_Dashboard TO role_Manager_Rest, role_Reports_Rest;');
IF OBJECT_ID(N'dbo.sp_Report_Revenue', N'P') IS NOT NULL
    EXEC(N'GRANT EXECUTE ON dbo.sp_Report_Revenue TO role_Manager_Rest, role_Reports_Rest;');
IF OBJECT_ID(N'dbo.sp_Report_PopularDishes', N'P') IS NOT NULL
    EXEC(N'GRANT EXECUTE ON dbo.sp_Report_PopularDishes TO role_Manager_Rest, role_Reports_Rest;');
IF OBJECT_ID(N'dbo.sp_Report_WaiterPerformance', N'P') IS NOT NULL
    EXEC(N'GRANT EXECUTE ON dbo.sp_Report_WaiterPerformance TO role_Manager_Rest, role_Reports_Rest;');
IF OBJECT_ID(N'dbo.sp_Report_TableLoad', N'P') IS NOT NULL
    EXEC(N'GRANT EXECUTE ON dbo.sp_Report_TableLoad TO role_Manager_Rest, role_Reports_Rest;');
IF OBJECT_ID(N'dbo.sp_Report_HourlyLoad', N'P') IS NOT NULL
    EXEC(N'GRANT EXECUTE ON dbo.sp_Report_HourlyLoad TO role_Manager_Rest, role_Reports_Rest;');
GO

/* ---------- Явные запреты на чувствительные объекты ---------- */
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AppUser TO role_Manager_Rest, role_Waiter_Rest, role_Cashier_Rest, role_Chef_Rest, role_Reports_Rest, role_App_Rest;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_Manager_Rest, role_Waiter_Rest, role_Cashier_Rest, role_Chef_Rest, role_Reports_Rest;
DENY UPDATE, DELETE ON dbo.Payment TO role_Waiter_Rest, role_Chef_Rest;
DENY INSERT, UPDATE, DELETE ON dbo.Dish TO role_Waiter_Rest, role_Cashier_Rest, role_Chef_Rest;
GO

/* ---------- Настройки пользователя: доступ через процедуры ---------- */
GRANT EXECUTE ON dbo.sp_UserSetting_Get TO role_Manager_Rest, role_Waiter_Rest, role_Cashier_Rest, role_Chef_Rest;
GRANT EXECUTE ON dbo.sp_UserSetting_Upsert TO role_Manager_Rest, role_Waiter_Rest, role_Cashier_Rest, role_Chef_Rest;
GO

/* ---------- Назначение ролей пользователям (идемпотентно) ---------- */
IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name = N'role_Director_Rest' AND m.name = N'user_admin_rest')
    ALTER ROLE role_Director_Rest ADD MEMBER user_admin_rest;

IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name = N'role_Manager_Rest' AND m.name = N'user_manager_rest')
    ALTER ROLE role_Manager_Rest ADD MEMBER user_manager_rest;

IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name = N'role_Waiter_Rest' AND m.name = N'user_waiter_rest')
    ALTER ROLE role_Waiter_Rest ADD MEMBER user_waiter_rest;

IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name = N'role_Cashier_Rest' AND m.name = N'user_cashier_rest')
    ALTER ROLE role_Cashier_Rest ADD MEMBER user_cashier_rest;

IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name = N'role_Chef_Rest' AND m.name = N'user_chef_rest')
    ALTER ROLE role_Chef_Rest ADD MEMBER user_chef_rest;

IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name = N'role_Reports_Rest' AND m.name = N'user_reports_rest')
    ALTER ROLE role_Reports_Rest ADD MEMBER user_reports_rest;

IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name = N'role_App_Rest' AND m.name = N'user_app_rest')
    ALTER ROLE role_App_Rest ADD MEMBER user_app_rest;
GO

PRINT N'RBAC настроен: 7 ролей, 7 пользователей БД.';
GO
