/* ============================================================
   Скрипт 08. Резервное копирование, проверка и восстановление
   Требуется папка C:\Backup (или измените путь).
   ============================================================ */
USE master;
GO

/* Создание каталога для резервных копий (если разрешено xp_create_subdir) */
BEGIN TRY
    EXEC master.dbo.xp_create_subdir N'C:\Backup';
END TRY
BEGIN CATCH
    PRINT N'Каталог C:\Backup уже существует или недоступен: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ---------- 1. Полная резервная копия ---------- */
BACKUP DATABASE RestaurantDB
TO DISK = N'C:\Backup\RestaurantDB_Full.bak'
WITH FORMAT,
     INIT,
     CHECKSUM,
     COMPRESSION,
     NAME = N'RestaurantDB — полная копия',
     STATS = 10;
GO

/* ---------- 2. Проверка целостности копии ---------- */
RESTORE VERIFYONLY
FROM DISK = N'C:\Backup\RestaurantDB_Full.bak'
WITH CHECKSUM;
GO

/* ---------- 3. Дифференциальная копия ---------- */
BACKUP DATABASE RestaurantDB
TO DISK = N'C:\Backup\RestaurantDB_Diff.bak'
WITH DIFFERENTIAL,
     CHECKSUM,
     COMPRESSION,
     NAME = N'RestaurantDB — дифференциальная копия',
     STATS = 10;
GO

/* ---------- 4. Копия журнала транзакций ---------- */
BACKUP LOG RestaurantDB
TO DISK = N'C:\Backup\RestaurantDB_Log.trn'
WITH CHECKSUM,
     COMPRESSION,
     NAME = N'RestaurantDB — журнал транзакций',
     STATS = 10;
GO

/* ---------- 5. Проверка базы данных ---------- */
DBCC CHECKDB (N'RestaurantDB') WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO

/* ---------- 6. Пример восстановления ----------
   Остановить приложение, затем выполнить:

RESTORE DATABASE RestaurantDB
FROM DISK = N'C:\Backup\RestaurantDB_Full.bak'
WITH NORECOVERY,
     REPLACE,
     STATS = 10;

RESTORE DATABASE RestaurantDB
FROM DISK = N'C:\Backup\RestaurantDB_Diff.bak'
WITH NORECOVERY,
     STATS = 10;

RESTORE LOG RestaurantDB
FROM DISK = N'C:\Backup\RestaurantDB_Log.trn'
WITH RECOVERY,
     STATS = 10;
--------------------------------------------------- */

/* ---------- 7. Расписание (пример через SQL Server Agent) ----------
   Задание: полная копия — ежедневно в 02:00,
   дифференциальная — каждые 4 часа,
   журнал — каждые 30 минут.
   Скрипт задания создаётся в msdb:

USE msdb;
EXEC dbo.sp_add_job @job_name = N'RestaurantDB — backup';
EXEC dbo.sp_add_jobstep
    @job_name = N'RestaurantDB — backup',
    @step_name = N'Full backup',
    @subsystem = N'TSQL',
    @command = N'BACKUP DATABASE RestaurantDB TO DISK = N''C:\Backup\RestaurantDB_Full.bak'' WITH INIT, COMPRESSION;',
    @database_name = N'master';
EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily 02:00',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 020000;
EXEC dbo.sp_attach_schedule
    @job_name = N'RestaurantDB — backup',
    @schedule_name = N'Daily 02:00';
EXEC dbo.sp_add_jobserver @job_name = N'RestaurantDB — backup';
--------------------------------------------------- */
GO

PRINT N'Резервное копирование завершено. Проверьте каталог C:\Backup.';
GO
