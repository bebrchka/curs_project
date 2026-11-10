/* ============================================================
   Скрипт 03. Тестовые данные
   Пароли демонстрационных учётных записей:
     admin   / Admin_12345!
     manager / Manager_12345!
     waiter  / Waiter_12345!
     cashier / Cashier_12345!
     chef    / Chef_12345!
   Хеши рассчитаны PBKDF2-HMAC-SHA256, 100 000 итераций, 32 байта.
   ============================================================ */
USE RestaurantDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ---------- Роли ---------- */
INSERT INTO dbo.Role (RoleName, RoleDescription) VALUES
(N'Director', N'Директор — полный доступ, управление пользователями и аудит'),
(N'Manager',  N'Менеджер — меню, заказы, бронирования, отчёты'),
(N'Waiter',   N'Официант — приём заказов и работа со столиками'),
(N'Cashier',  N'Кассир — расчёт и оплата заказов'),
(N'Chef',     N'Повар — кухня, изменение статусов заказов');
GO

/* ---------- Сотрудники ---------- */
INSERT INTO dbo.Employee (LastName, FirstName, MiddleName, Phone, Post, RoleID, HireDate) VALUES
(N'Иванов',    N'Алексей',  N'Петрович',    N'+7-900-111-22-33', N'Директор',              1, '2021-02-01'),
(N'Смирнова',  N'Ольга',    N'Викторовна',  N'+7-900-222-33-44', N'Менеджер',              2, '2021-05-17'),
(N'Петрова',   N'Мария',    N'Сергеевна',   N'+7-900-333-44-55', N'Официант',              3, '2022-03-01'),
(N'Сидоров',   N'Дмитрий',  N'Игоревич',    N'+7-900-444-55-66', N'Кассир',                4, '2022-04-11'),
(N'Кузнецов',  N'Андрей',   N'Николаевич',  N'+7-900-555-66-77', N'Шеф-повар',             5, '2021-09-06'),
(N'Волкова',   N'Анна',     N'Дмитриевна',  N'+7-900-666-77-88', N'Официант',              3, '2023-01-23'),
(N'Морозов',   N'Сергей',   N'Павлович',    N'+7-900-777-88-99', N'Повар',                 5, '2022-07-18'),
(N'Онлайн',    N'Менеджер', N'Сайта',       N'+7-900-888-99-00', N'Менеджер онлайн-заказов', 2, '2024-01-10');
GO

/* ---------- Учётные записи (PBKDF2) ---------- */
INSERT INTO dbo.AppUser (Login, PasswordHash, PasswordSalt, EmployeeID, RoleID) VALUES
(N'admin',   0x9EDB7A88C27A0B909D2BA7955EBE8EA7CAC60EF725ECC8E94F75AA597B6AC3C0, 0x4E1E2AD0294367E137D0E983616FE251, 1, 1),
(N'manager', 0x2BFBB7A19483AA1E9B92505467134B86A238D53D407F0542C72D84A4E182D702, 0x8D9FF84682AB2479C1A90668AB3F4EDE, 2, 2),
(N'waiter',  0x14B3A1189111F2DF6D63219F2A414127ED7FEEAEFFCA471A1A23C19C6C8338B9, 0x0A230027954DCB6F8A035A3FB4ACB175, 3, 3),
(N'cashier', 0xEACA66924A9EED824A04938E9728CAF363A20D37D6B9877505FCF40EE3BB3AE2, 0x9D6C3F92DAC687CD59B574E9D1A9E58E, 4, 4),
(N'chef',    0x235D58F469E1C20FCF9166F51892D98452DA276C5A1550358902642C1D888815, 0x3A29794A694B331D82087DF46E17A060, 5, 5);
GO

/* ---------- Настройки пользователей (1:1) ---------- */
INSERT INTO dbo.UserSetting (UserID, Theme, DateFormat, NumberFormat, PageSize, SavedFilters) VALUES
(1, N'light', N'dd.MM.yyyy', N'ru-RU', 50, N'{"orders":{"status":"Оплачен"}}'),
(2, N'light', N'dd.MM.yyyy', N'ru-RU', 25, N'{"reports":{"period":"30"}}'),
(3, N'dark',  N'dd.MM.yyyy', N'ru-RU', 20, N'{"orders":{"status":"Готовится"}}'),
(4, N'light', N'dd.MM.yyyy', N'ru-RU', 20, NULL),
(5, N'dark',  N'dd.MM.yyyy', N'ru-RU', 20, N'{"kitchen":{"status":"Оформлен"}}');
GO

/* ---------- Категории меню ---------- */
INSERT INTO dbo.Category (CategoryName, Description, SortOrder) VALUES
(N'Холодные закуски', N'Закуски для начала трапезы', 10),
(N'Салаты',           N'Свежие салаты и закуски',    20),
(N'Супы',             N'Горячие первые блюда',       30),
(N'Горячие блюда',    N'Основные блюда из мяса, рыбы и птицы', 40),
(N'Гарниры',          N'Дополнительные блюда',       50),
(N'Десерты',          N'Сладкие блюда',              60),
(N'Напитки',          N'Горячие и холодные напитки', 70);
GO

/* ---------- Блюда ---------- */
INSERT INTO dbo.Dish (CategoryID, DishName, Price, WeightGr, Description) VALUES
(1, N'Брускетта с томатами',        320.00, 180, N'Хрустящий багет, томаты, базилик, оливковое масло'),
(1, N'Сырная тарелка',              690.00, 250, N'Ассорти сыров, мёд, орехи, виноград'),
(1, N'Тартар из говядины',          790.00, 160, N'Говядина, каперсы, дижонский соус, тосты'),
(2, N'Цезарь с курицей',            490.00, 260, N'Романо, курица гриль, пармезан, гренки'),
(2, N'Оливье с языком',             420.00, 220, N'Овощи, язык, майонез, зелень'),
(2, N'Салат с креветками',          620.00, 210, N'Креветки, авокадо, руккола, цитрусовый соус'),
(3, N'Борщ с говядиной',            380.00, 320, N'С говядиной, сметаной и пампушками'),
(3, N'Крем-суп из грибов',          360.00, 300, N'Шампиньоны, сливки, трюфельное масло'),
(3, N'Том-ям с морепродуктами',     520.00, 350, N'Креветки, кальмары, кокосовое молоко'),
(4, N'Стейк Рибай',                1890.00, 400, N'Стейк из мраморной говядины, овощи гриль'),
(4, N'Паста Карбонара',             620.00, 300, N'Спагетти, бекон, яйцо, пармезан'),
(4, N'Куриное филе гриль',          540.00, 320, N'Филе цыплёнка, соус чимичурри'),
(4, N'Лосось на гриле',             890.00, 330, N'Филе лосося, лимон, овощи'),
(4, N'Бургер с говядиной',          590.00, 380, N'Котлета, булочка бриошь, сыр, соус'),
(5, N'Картофель по-деревенски',     220.00, 200, N'С пряными травами'),
(5, N'Овощи гриль',                 260.00, 220, N'Кабачки, баклажаны, перец'),
(5, N'Рис с овощами',               200.00, 200, N'Рис басмати, морковь, горошек'),
(6, N'Чизкейк Нью-Йорк',            320.00, 150, N'Классический чизкейк с ягодным соусом'),
(6, N'Тирамису',                    340.00, 140, N'Савоярди, маскарпоне, кофе'),
(6, N'Медовик',                     280.00, 160, N'Домашний медовый торт'),
(7, N'Чай чёрный',                  120.00, 300, N'Цейлонский чай'),
(7, N'Чай зелёный',                 120.00, 300, N'Жасминовый зелёный чай'),
(7, N'Кофе американо',              160.00, 200, N'Свежесваренный кофе'),
(7, N'Капучино',                    210.00, 250, N'Эспрессо и вспененное молоко'),
(7, N'Лимонад домашний',            240.00, 400, N'Лимон, мята, тархун'),
(7, N'Морс клюквенный',             190.00, 400, N'Клюква, сахар, вода'),
(7, N'Вино красное (бокал)',        390.00, 150, N'Сухое красное вино'),
(7, N'Пиво крафтовое',              290.00, 330, N'Светлый эль');
GO

/* ---------- Столики ---------- */
INSERT INTO dbo.RestaurantTable (TableNumber, Seats, Hall, TableStatus) VALUES
(N'1',  2, N'Основной зал',  N'Свободен'),
(N'2',  4, N'Основной зал',  N'Свободен'),
(N'3',  4, N'Основной зал',  N'Свободен'),
(N'4',  6, N'Основной зал',  N'Свободен'),
(N'5',  2, N'Основной зал',  N'Свободен'),
(N'6',  6, N'Основной зал',  N'Свободен'),
(N'7',  4, N'Веранда',       N'Занят'),
(N'8',  4, N'Веранда',       N'Занят'),
(N'9',  8, N'Банкетный зал', N'Свободен'),
(N'10', 8, N'Банкетный зал', N'Забронирован'),
(N'11', 6, N'Веранда',       N'Забронирован'),
(N'12', 2, N'Основной зал',  N'Забронирован');
GO

/* ---------- Клиенты ---------- */
INSERT INTO dbo.Customer (LastName, FirstName, MiddleName, Phone, Email, RegistrationDate, LoyaltyPoints) VALUES
(N'Кузнецов',  N'Михаил',  N'Андреевич',   N'+7-901-555-66-77', N'm.kuznetsov@mail.ru',  DATEADD(DAY, -120, GETDATE()), 120),
(N'Орлова',    N'Елена',   N'Викторовна',  N'+7-901-666-77-88', N'e.orlova@mail.ru',     DATEADD(DAY, -95,  GETDATE()),  80),
(N'Соколов',   N'Павел',   N'Дмитриевич',  N'+7-901-777-88-99', N'p.sokolov@mail.ru',    DATEADD(DAY, -60,  GETDATE()),  45),
(N'Лебедева',  N'Ирина',   N'Алексеевна',  N'+7-901-888-99-00', N'i.lebedeva@mail.ru',   DATEADD(DAY, -45,  GETDATE()),  30),
(N'Новиков',   N'Артём',   N'Сергеевич',   N'+7-901-999-00-11', N'a.novikov@mail.ru',    DATEADD(DAY, -30,  GETDATE()),  15),
(N'Егорова',   N'Наталья', N'Игоревна',    N'+7-902-111-22-33', N'n.egorova@mail.ru',    DATEADD(DAY, -20,  GETDATE()),  10),
(N'Фролов',    N'Денис',   N'Владимирович',N'+7-902-222-33-44', N'd.frolov@mail.ru',     DATEADD(DAY, -10,  GETDATE()),   5),
(N'Романова',  N'Ксения',  N'Андреевна',   N'+7-902-333-44-55', N'k.romanova@mail.ru',   DATEADD(DAY, -3,   GETDATE()),   0);
GO

/* ---------- Бронирования ---------- */
INSERT INTO dbo.Reservation (CustomerID, TableID, EmployeeID, ReservationDate, GuestsCount, ReservationStatus, Notes) VALUES
(2, 10, 2, DATEADD(HOUR, 19, DATEADD(DAY, 1, CAST(GETDATE() AS DATE))), 6, N'Активна', N'День рождения'),
(3, 11, 2, DATEADD(HOUR, 20, DATEADD(DAY, 1, CAST(GETDATE() AS DATE))), 5, N'Активна', N'У окна'),
(4, 12, 3, DATEADD(HOUR, 18, DATEADD(DAY, 2, CAST(GETDATE() AS DATE))), 2, N'Активна', N'Романтический ужин'),
(5, 10, 2, DATEADD(HOUR, 19, DATEADD(DAY, 3, CAST(GETDATE() AS DATE))), 8, N'Активна', N'Корпоратив'),
(1, 2,  3, DATEADD(DAY, -3, GETDATE()), 2, N'Выполнена', NULL),
(6, 3,  3, DATEADD(DAY, -5, GETDATE()), 4, N'Отменена', N'Клиент не пришёл');
GO

/* ---------- Заказы ---------- */
DECLARE @Today DATE = CAST(GETDATE() AS DATE);

INSERT INTO dbo.[Order] (TableID, CustomerID, EmployeeID, OrderDate, OrderStatus, OrderType, Notes, TotalAmount) VALUES
(1, 1, 3, DATEADD(DAY, -10, DATEADD(HOUR, 13, CAST(@Today AS DATETIME))), N'Оплачен',  N'В зале',   N'Бизнес-ланч', 0),
(2, 2, 6, DATEADD(DAY, -9,  DATEADD(HOUR, 18, CAST(@Today AS DATETIME))), N'Оплачен',  N'В зале',   NULL, 0),
(3, 3, 3, DATEADD(DAY, -7,  DATEADD(HOUR, 20, CAST(@Today AS DATETIME))), N'Оплачен',  N'В зале',   NULL, 0),
(NULL, 4, 6, DATEADD(DAY, -6, DATEADD(HOUR, 12, CAST(@Today AS DATETIME))), N'Оплачен', N'На вынос', N'С собой', 0),
(NULL, 5, 8, DATEADD(DAY, -4, DATEADD(HOUR, 19, CAST(@Today AS DATETIME))), N'Оплачен', N'Доставка', N'Доставка 30 минут', 0),
(4, 1, 3, DATEADD(DAY, -3,  DATEADD(HOUR, 19, CAST(@Today AS DATETIME))), N'Оплачен',  N'В зале',   NULL, 0),
(5, 6, 6, DATEADD(DAY, -2,  DATEADD(HOUR, 14, CAST(@Today AS DATETIME))), N'Оплачен',  N'В зале',   NULL, 0),
(6, 7, 3, DATEADD(DAY, -1,  DATEADD(HOUR, 20, CAST(@Today AS DATETIME))), N'Оплачен',  N'В зале',   NULL, 0),
(7, 8, 6, DATEADD(HOUR, -1, GETDATE()), N'Оформлен',  N'В зале',   N'Столик у окна', 0),
(8, 2, 3, DATEADD(HOUR, -2, GETDATE()), N'Готовится', N'В зале',   NULL, 0),
(NULL, 3, 6, DATEADD(HOUR, -1, GETDATE()), N'Готов', N'На вынос', N'Ожидает выдачи', 0),
(9, 4, 3, DATEADD(DAY, -1, DATEADD(HOUR, 17, CAST(@Today AS DATETIME))), N'Отменён', N'В зале', N'Клиент отменил заказ', 0),
(NULL, 5, 8, DATEADD(MINUTE, -30, GETDATE()), N'Готовится', N'Доставка', N'Оплата онлайн', 0);
GO

/* ---------- Позиции заказов ---------- */
INSERT INTO dbo.OrderItem (OrderID, DishID, Quantity, PriceAtOrder) VALUES
(1, 4, 1, 490.00), (1, 10, 2, 1890.00), (1, 15, 2, 220.00), (1, 23, 2, 160.00),
(2, 1, 2, 320.00), (2, 7, 1, 380.00), (2, 12, 1, 540.00), (2, 18, 2, 320.00), (2, 21, 1, 120.00),
(3, 6, 1, 620.00), (3, 13, 1, 890.00), (3, 16, 1, 260.00), (3, 25, 2, 240.00),
(4, 14, 2, 590.00), (4, 15, 1, 220.00), (4, 24, 2, 210.00),
(5, 11, 2, 620.00), (5, 5, 1, 420.00), (5, 19, 1, 340.00), (5, 26, 1, 190.00),
(6, 3, 1, 790.00), (6, 10, 1, 1890.00), (6, 17, 1, 200.00), (6, 27, 2, 390.00),
(7, 9, 2, 520.00), (7, 13, 1, 890.00), (7, 20, 1, 280.00), (7, 22, 2, 120.00),
(8, 2, 1, 690.00), (8, 8, 2, 360.00), (8, 12, 1, 540.00), (8, 18, 1, 320.00), (8, 28, 2, 290.00),
(9, 4, 2, 490.00), (9, 11, 1, 620.00), (9, 23, 2, 160.00),
(10, 1, 1, 320.00), (10, 7, 1, 380.00), (10, 10, 1, 1890.00), (10, 16, 1, 260.00),
(11, 14, 1, 590.00), (11, 15, 2, 220.00), (11, 25, 1, 240.00),
(12, 5, 1, 420.00), (12, 7, 1, 380.00),
(13, 9, 1, 520.00), (13, 13, 1, 890.00), (13, 19, 1, 340.00), (13, 26, 2, 190.00);
GO

/* ---------- Оплаты по закрытым заказам ---------- */
INSERT INTO dbo.Payment (OrderID, EmployeeID, PaymentDate, Amount, PaymentMethod, PaymentStatus)
SELECT o.OrderID, 4,
       DATEADD(MINUTE, 60, o.OrderDate),
       o.TotalAmount,
       CASE WHEN o.OrderID % 3 = 0 THEN N'Карта'
            WHEN o.OrderID % 3 = 1 THEN N'Наличные'
            ELSE N'Онлайн' END,
       N'Оплачен'
FROM dbo.[Order] o
WHERE o.OrderID IN (1,2,3,4,5,6,7,8)
  AND o.OrderStatus = N'Оплачен';
GO

/* ---------- История статусов ---------- */
INSERT INTO dbo.OrderStatusHistory (OrderID, OldStatus, NewStatus, ChangedBy, ChangedAt, Comment) VALUES
(10, N'Оформлен', N'Готовится', N'waiter', DATEADD(MINUTE, 5, GETDATE()), N'Передан на кухню'),
(11, N'Оформлен', N'Готовится', N'waiter', DATEADD(MINUTE, 10, GETDATE()), N'Передан на кухню'),
(11, N'Готовится', N'Готов', N'chef', DATEADD(MINUTE, 25, GETDATE()), N'Блюда готовы'),
(12, N'Оформлен', N'Отменён', N'waiter', DATEADD(MINUTE, 15, GETDATE()), N'Отмена клиентом');
GO

/* ---------- Записи аудита ---------- */
INSERT INTO dbo.AuditLog (UserID, LoginName, ActionTime, ActionType, ObjectName, ObjectID, IPAddress, Details) VALUES
(1, N'admin',   DATEADD(MINUTE, -90, GETDATE()), N'LOGIN',   N'AppUser', N'1', N'127.0.0.1', N'Успешный вход директора'),
(2, N'manager', DATEADD(MINUTE, -70, GETDATE()), N'UPDATE',  N'Dish',    N'10', N'127.0.0.1', N'Изменена цена стейка Рибай'),
(3, N'waiter',  DATEADD(MINUTE, -55, GETDATE()), N'INSERT',  N'Order',   N'13', N'127.0.0.1', N'Создан заказ на доставку'),
(4, N'cashier', DATEADD(MINUTE, -40, GETDATE()), N'PAYMENT', N'Payment', N'9',  N'127.0.0.1', N'Оплата заказа');
GO

PRINT N'Тестовые данные успешно добавлены.';
GO
