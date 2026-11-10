-- 08_Резервное_копирование_восстановление.sql
-- Пример для MS SQL Server
USE master;
GO
-- Полное резервное копирование
BACKUP DATABASE RestaurantDB
TO DISK = 'C:\Backup\RestaurantDB_Full.bak'
WITH FORMAT, INIT, NAME = 'RestaurantDB-Full Backup', STATS=10;
GO

-- Дифференциальное резервное копирование (после полного)
BACKUP DATABASE RestaurantDB
TO DISK = 'C:\Backup\RestaurantDB_Diff.bak'
WITH DIFFERENTIAL, NAME = 'RestaurantDB-Diff Backup', STATS=10;
GO

-- Восстановление (пример)
-- RESTORE DATABASE RestaurantDB
-- FROM DISK = 'C:\Backup\RestaurantDB_Full.bak'
-- WITH NORECOVERY;
-- RESTORE DATABASE RestaurantDB
-- FROM DISK = 'C:\Backup\RestaurantDB_Diff.bak'
-- WITH RECOVERY;
GO
