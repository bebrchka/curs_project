/* ============================================================
   Скрипт 12. Проверка RBAC, аудита и защиты данных
   ============================================================ */
USE RestaurantDB;
GO

/* ---------- 1. Роли и участники ---------- */
SELECT  r.name AS RoleName,
        m.name AS MemberName,
        m.type_desc AS MemberType
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
ORDER BY r.name, m.name;
GO

/* ---------- 2. Выданные и запрещённые права на объекты ---------- */
SELECT  dp.name          AS PrincipalName,
        o.name           AS ObjectName,
        p.permission_name,
        p.state_desc
FROM sys.database_permissions p
JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
LEFT JOIN sys.objects o ON o.object_id = p.major_id
WHERE dp.name LIKE N'role[_]%Rest' OR dp.name LIKE N'user[_]%rest'
ORDER BY dp.name, o.name, p.permission_name;
GO

/* ---------- 3. Проверка запрета: официант не читает AppUser ---------- */
BEGIN TRY
    EXECUTE AS USER = N'user_waiter_rest';
    SELECT TOP (1) Login, PasswordHash FROM dbo.AppUser;
    REVERT;
    PRINT N'ОШИБКА: официант смог прочитать AppUser!';
END TRY
BEGIN CATCH
    IF USER_NAME() <> N'dbo' REVERT;
    PRINT N'OK: прямой доступ официанта к AppUser запрещён. ' + ERROR_MESSAGE();
END CATCH;
GO

/* ---------- 4. Проверка разрешения: официант видит меню ---------- */
BEGIN TRY
    EXECUTE AS USER = N'user_waiter_rest';
    SELECT TOP (3) DishName, Price FROM dbo.vw_Menu;
    REVERT;
    PRINT N'OK: официант читает представление vw_Menu.';
END TRY
BEGIN CATCH
    IF USER_NAME() <> N'dbo' REVERT;
    PRINT N'ОШИБКА: официант не смог прочитать vw_Menu. ' + ERROR_MESSAGE();
END CATCH;
GO

/* ---------- 5. Маскирование ПДн ---------- */
SELECT TOP (5) CustomerID, LastName, PhoneMasked, EmailMasked
FROM dbo.vw_CustomerMasked
ORDER BY CustomerID;
GO

/* ---------- 6. Пароли не хранятся в открытом виде ---------- */
SELECT  Login,
        LEN(PasswordHash) AS HashBytes,
        LEN(PasswordSalt) AS SaltBytes,
        CASE WHEN LEN(PasswordHash) >= 32 AND LEN(PasswordSalt) >= 16
             THEN N'OK' ELSE N'ПРОВЕРИТЬ' END AS PasswordStorageCheck
FROM dbo.AppUser;
GO

/* ---------- 7. Журнал аудита: последние изменения с «до/после» ---------- */
SELECT TOP (20)
        LogID, LoginName, ActionTime, ActionType, ObjectName, ObjectID,
        OldValue, NewValue
FROM dbo.AuditLog
ORDER BY ActionTime DESC;
GO

/* ---------- 8. Сводка аудита по типам действий ---------- */
SELECT  ActionType,
        COUNT(*) AS EventsCount,
        MIN(ActionTime) AS FirstEvent,
        MAX(ActionTime) AS LastEvent
FROM dbo.AuditLog
GROUP BY ActionType
ORDER BY EventsCount DESC;
GO

/* ---------- 9. Проверка политики логинов ---------- */
SELECT  name,
        is_disabled,
        is_policy_checked,
        is_expiration_checked
FROM sys.sql_logins
WHERE name LIKE N'login[_]%rest';
GO

/* ---------- 10. Проверка шифрования соединения ---------- */
SELECT  session_id,
        encrypt_option,
        protocol_type,
        auth_scheme,
        client_net_address
FROM sys.dm_exec_connections
WHERE session_id = @@SPID;
GO
