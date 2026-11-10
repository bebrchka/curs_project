/* ============================================================
   Скрипт 10. Администрирование: сеть, удалённый доступ,
   импорт и экспорт данных, резервное копирование в Azure
   ============================================================ */
USE master;
GO

/* ---------- 1. Сведения о сервере и сетевых подключениях ---------- */
SELECT
    @@SERVERNAME                                   AS ServerName,
    SERVERPROPERTY('InstanceName')                 AS InstanceName,
    SERVERPROPERTY('ProductVersion')               AS ProductVersion,
    SERVERPROPERTY('Edition')                      AS Edition,
    SERVERPROPERTY('IsIntegratedSecurityOnly')     AS WindowsAuthOnly,
    SERVERPROPERTY('IsHadrEnabled')                AS HadrEnabled;
GO

SELECT
    session_id,
    client_net_address,
    local_net_address,
    protocol_type,
    encrypt_option,
    auth_scheme
FROM sys.dm_exec_connections
WHERE session_id = @@SPID;
GO

/* ---------- 2. Проверка прослушиваемых портов ---------- */
SELECT
    ip_address,
    port,
    type_desc,
    state_desc
FROM sys.dm_tcp_listener_states;
GO

/* ---------- 3. Экспорт/импорт через bcp ----------
   Выполняется из командной строки Windows (не внутри SSMS).

   Экспорт таблицы Dish:
     bcp RestaurantDB.dbo.Dish out C:\Export\Dish.dat -c -T -S localhost -f C:\Export\Dish.fmt

   Импорт таблицы Dish:
     bcp RestaurantDB.dbo.Dish in C:\Export\Dish.dat -c -T -S localhost

   Экспорт результата запроса:
     bcp "SELECT DishID, DishName, Price FROM RestaurantDB.dbo.Dish" queryout C:\Export\Menu.txt -c -T -S localhost

   Экспорт всей БД (скрипт с данными) — через SSMS:
     Tasks → Generate Scripts → Script entire database and all database objects
     Advanced → Types of data to script = Schema and data
----------------------------------------------------------- */

/* ---------- 4. Импорт через BULK INSERT ---------- */
-- Пример: предварительно выгрузите Dish в CSV с разделителем ;
-- BULK INSERT dbo.DishStage FROM 'C:\Export\Dish.csv'
-- WITH (FIELDTERMINATOR = ';', ROWTERMINATOR = '\n', FIRSTROW = 2, CODEPAGE = '65001');

/* ---------- 5. Быстрое копирование таблицы ---------- */
IF OBJECT_ID(N'dbo.DishArchive', N'U') IS NOT NULL DROP TABLE dbo.DishArchive;
SELECT * INTO dbo.DishArchive FROM dbo.Dish;
GO

/* ---------- 6. Резервная копия в Azure Blob Storage ----------
   Требуется учётная запись хранения Azure и контейнер.
   Секрет — ключ доступа к хранилищу (не храните в открытом виде!).

CREATE CREDENTIAL AzureRestaurantBackup
WITH IDENTITY = 'restaurantstorage',
     SECRET = '<storage-account-key>';
GO

BACKUP DATABASE RestaurantDB
TO URL = 'https://restaurantstorage.blob.core.windows.net/backups/RestaurantDB_Full.bak'
WITH CREDENTIAL = 'AzureRestaurantBackup',
     FORMAT, INIT, CHECKSUM, COMPRESSION, STATS = 10;
GO
----------------------------------------------------------- */

/* ---------- 7. Публикация БД в Azure SQL (порядок действий) ----------
   1. Создать Azure SQL Server и базу RestaurantDB.
   2. В разделе Networking добавить IP клиента и разрешить Azure-сервисы.
   3. Выполнить скрипты 01–09 через sqlcmd:
        sqlcmd -S <server>.database.windows.net -U <admin> -P <password> -d RestaurantDB -i 01_Создание_БД_и_таблиц.sql
   4. Строка подключения:
        Server=tcp:<server>.database.windows.net,1433;Database=RestaurantDB;
        User ID=<admin>;Password=<password>;Encrypt=True;TrustServerCertificate=False;
   5. Проверить шифрование:
        SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID;
----------------------------------------------------------- */

PRINT N'Административные примеры выполнены.';
GO
