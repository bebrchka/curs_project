/* ============================================================
   Скрипт 11. Шифрование, защита канала и аудит SQL Server
   Внимание: TDE и аудит требуют соответствующих прав.
   ============================================================ */
USE master;
GO

/* ---------- 1. Проверка шифрования текущего соединения ---------- */
SELECT
    session_id,
    encrypt_option,
    protocol_type,
    auth_scheme,
    client_net_address
FROM sys.dm_exec_connections
WHERE session_id = @@SPID;
GO

/* ---------- 2. Прозрачное шифрование данных (TDE) ----------
   Шаги выполняются один раз для экземпляра и базы.
   Обязательно сохраните резервную копию сертификата!

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'Rest_Master_Key_2026!';
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'RestaurantTDECert')
    CREATE CERTIFICATE RestaurantTDECert
    WITH SUBJECT = N'Сертификат TDE для RestaurantDB',
         EXPIRY_DATE = N'2036-12-31';
GO

BACKUP CERTIFICATE RestaurantTDECert
TO FILE = N'C:\Backup\RestaurantTDECert.cer'
WITH PRIVATE KEY (
    FILE = N'C:\Backup\RestaurantTDECert.key',
    ENCRYPTION BY PASSWORD = N'Rest_Cert_Key_2026!'
);
GO

USE RestaurantDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID())
BEGIN
    CREATE DATABASE ENCRYPTION KEY
    WITH ALGORITHM = AES_256
    ENCRYPTION BY SERVER CERTIFICATE RestaurantTDECert;
END
GO

ALTER DATABASE RestaurantDB SET ENCRYPTION ON;
GO

SELECT
    DB_NAME(database_id) AS DatabaseName,
    encryption_state,
    encryptor_type,
    key_algorithm,
    key_length
FROM sys.dm_database_encryption_keys;
GO
----------------------------------------------------------- */

/* ---------- 3. Шифрование отдельных значений (ENCRYPTBYKEY) ----------
USE RestaurantDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'RestaurantDataKey')
    CREATE SYMMETRIC KEY RestaurantDataKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE RestaurantTDECert;
GO

OPEN SYMMETRIC KEY RestaurantDataKey DECRYPTION BY CERTIFICATE RestaurantTDECert;
GO

-- Пример: зашифрованное хранение телефона клиента
-- (в учебной БД основной столбец Phone остаётся открытым для поиска)
SELECT
    CustomerID,
    Phone,
    ENCRYPTBYKEY(KEY_GUID(N'RestaurantDataKey'), Phone) AS PhoneEncrypted
FROM dbo.Customer;
GO

CLOSE SYMMETRIC KEY RestaurantDataKey;
GO
----------------------------------------------------------- */

/* ---------- 4. Хеширование паролей ----------
   В приложении используется PBKDF2-HMAC-SHA256, 100 000 итераций,
   случайная соль 16 байт и хеш 32 байта. В БД хранятся только
   PasswordSalt и PasswordHash (VARBINARY), открытый пароль не хранится.
----------------------------------------------------------- */
USE RestaurantDB;
GO

SELECT
    Login,
    LEN(PasswordHash) AS HashBytes,
    LEN(PasswordSalt) AS SaltBytes,
    LastLoginAt
FROM dbo.AppUser;
GO

/* ---------- 5. SQL Server Audit ----------
USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = N'RestaurantServerAudit')
BEGIN
    CREATE SERVER AUDIT RestaurantServerAudit
    TO FILE (FILEPATH = N'C:\Audit\', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 10)
    WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
    ALTER SERVER AUDIT RestaurantServerAudit WITH (STATE = ON);
END
GO

USE RestaurantDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = N'RestaurantDbAuditSpec')
BEGIN
    CREATE DATABASE AUDIT SPECIFICATION RestaurantDbAuditSpec
    FOR SERVER AUDIT RestaurantServerAudit
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.AppUser BY public),
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog BY public),
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Payment BY public)
    WITH (STATE = ON);
END
GO
----------------------------------------------------------- */

/* ---------- 6. Рекомендации по защите канала ---------- */
PRINT N'1. Включить Force Encryption в SQL Server Configuration Manager.';
PRINT N'2. Использовать сертификат доверенного центра сертификации.';
PRINT N'3. Запретить TLS 1.0/1.1, оставить TLS 1.2+.';
PRINT N'4. Закрыть порт 1433 из интернета, использовать VPN или Azure Private Link.';
PRINT N'5. Отключить учётную запись sa или задать длинный пароль.';
PRINT N'6. Включить SQL Server Audit и регулярно анализировать журнал.';
PRINT N'7. Хранить резервные копии в зашифрованном виде (TDE/BitLocker/Azure).';
GO
