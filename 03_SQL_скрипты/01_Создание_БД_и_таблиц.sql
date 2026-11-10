/* ============================================================
   Курсовой проект: «Разработка веб-сайта для организации
   деятельности ресторана»
   Скрипт 01. Создание базы данных и таблиц
   СУБД: Microsoft SQL Server 2019+ (T-SQL)
   ============================================================ */
USE master;
GO

IF DB_ID(N'RestaurantDB') IS NOT NULL
BEGIN
    ALTER DATABASE RestaurantDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RestaurantDB;
END
GO

CREATE DATABASE RestaurantDB;
GO

ALTER DATABASE RestaurantDB SET RECOVERY FULL;
GO

USE RestaurantDB;
GO

/* ---------- Справочник ролей ---------- */
CREATE TABLE dbo.Role (
    RoleID          INT IDENTITY(1,1) NOT NULL,
    RoleName        NVARCHAR(30)      NOT NULL,
    RoleDescription NVARCHAR(150)     NULL,
    CONSTRAINT PK_Role PRIMARY KEY (RoleID),
    CONSTRAINT UQ_Role_RoleName UNIQUE (RoleName)
);
GO

/* ---------- Сотрудники ---------- */
CREATE TABLE dbo.Employee (
    EmployeeID INT IDENTITY(1,1) NOT NULL,
    LastName   NVARCHAR(50)      NOT NULL,
    FirstName  NVARCHAR(50)      NOT NULL,
    MiddleName NVARCHAR(50)      NULL,
    Phone      NVARCHAR(20)      NULL,
    Post       NVARCHAR(80)      NOT NULL,
    RoleID     INT               NOT NULL,
    HireDate   DATE              NOT NULL CONSTRAINT DF_Employee_HireDate DEFAULT (GETDATE()),
    IsActive   BIT               NOT NULL CONSTRAINT DF_Employee_IsActive DEFAULT (1),
    CONSTRAINT PK_Employee PRIMARY KEY (EmployeeID),
    CONSTRAINT FK_Employee_Role FOREIGN KEY (RoleID) REFERENCES dbo.Role (RoleID),
    CONSTRAINT CK_Employee_Phone CHECK (Phone IS NULL OR LEN(Phone) >= 10)
);
GO

/* ---------- Учётные записи веб-приложения ---------- */
CREATE TABLE dbo.AppUser (
    UserID       INT IDENTITY(1,1) NOT NULL,
    Login        NVARCHAR(40)      NOT NULL,
    PasswordHash VARBINARY(64)     NOT NULL,
    PasswordSalt VARBINARY(32)     NOT NULL,
    EmployeeID   INT               NULL,
    RoleID       INT               NOT NULL,
    IsActive     BIT               NOT NULL CONSTRAINT DF_AppUser_IsActive DEFAULT (1),
    CreatedAt    DATETIME          NOT NULL CONSTRAINT DF_AppUser_CreatedAt DEFAULT (GETDATE()),
    LastLoginAt  DATETIME          NULL,
    CONSTRAINT PK_AppUser PRIMARY KEY (UserID),
    CONSTRAINT UQ_AppUser_Login UNIQUE (Login),
    CONSTRAINT FK_AppUser_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.Employee (EmployeeID),
    CONSTRAINT FK_AppUser_Role FOREIGN KEY (RoleID) REFERENCES dbo.Role (RoleID),
    CONSTRAINT CK_AppUser_Login CHECK (LEN(Login) >= 3)
);
GO

/* ---------- Категории меню ---------- */
CREATE TABLE dbo.Category (
    CategoryID   INT IDENTITY(1,1) NOT NULL,
    CategoryName NVARCHAR(80)      NOT NULL,
    Description  NVARCHAR(200)     NULL,
    SortOrder    INT               NOT NULL CONSTRAINT DF_Category_SortOrder DEFAULT (100),
    CONSTRAINT PK_Category PRIMARY KEY (CategoryID),
    CONSTRAINT UQ_Category_Name UNIQUE (CategoryName)
);
GO

/* ---------- Блюда ---------- */
CREATE TABLE dbo.Dish (
    DishID      INT IDENTITY(1,1) NOT NULL,
    CategoryID  INT               NOT NULL,
    DishName    NVARCHAR(120)     NOT NULL,
    Price       DECIMAL(12,2)     NOT NULL,
    WeightGr    DECIMAL(7,1)      NULL,
    Description NVARCHAR(400)     NULL,
    IsAvailable BIT               NOT NULL CONSTRAINT DF_Dish_IsAvailable DEFAULT (1),
    CreatedAt   DATETIME          NOT NULL CONSTRAINT DF_Dish_CreatedAt DEFAULT (GETDATE()),
    UpdatedAt   DATETIME          NULL,
    CONSTRAINT PK_Dish PRIMARY KEY (DishID),
    CONSTRAINT FK_Dish_Category FOREIGN KEY (CategoryID) REFERENCES dbo.Category (CategoryID),
    CONSTRAINT CK_Dish_Price CHECK (Price > 0),
    CONSTRAINT CK_Dish_Weight CHECK (WeightGr IS NULL OR WeightGr > 0),
    CONSTRAINT CK_Dish_Name CHECK (LEN(DishName) >= 2)
);
GO

/* ---------- Столики ---------- */
CREATE TABLE dbo.RestaurantTable (
    TableID     INT IDENTITY(1,1) NOT NULL,
    TableNumber NVARCHAR(10)      NOT NULL,
    Seats       INT               NOT NULL,
    Hall        NVARCHAR(40)      NOT NULL CONSTRAINT DF_Table_Hall DEFAULT (N'Основной зал'),
    TableStatus NVARCHAR(20)      NOT NULL CONSTRAINT DF_Table_Status DEFAULT (N'Свободен'),
    CONSTRAINT PK_RestaurantTable PRIMARY KEY (TableID),
    CONSTRAINT UQ_TableNumber UNIQUE (TableNumber),
    CONSTRAINT CK_Table_Seats CHECK (Seats > 0 AND Seats <= 30),
    CONSTRAINT CK_TableStatus CHECK (TableStatus IN (N'Свободен', N'Занят', N'Забронирован', N'Неактивен'))
);
GO

/* ---------- Клиенты ---------- */
CREATE TABLE dbo.Customer (
    CustomerID       INT IDENTITY(1,1) NOT NULL,
    LastName         NVARCHAR(50)      NOT NULL,
    FirstName        NVARCHAR(50)      NOT NULL,
    MiddleName       NVARCHAR(50)      NULL,
    Phone            NVARCHAR(20)      NOT NULL,
    Email            NVARCHAR(80)      NULL,
    RegistrationDate DATE              NOT NULL CONSTRAINT DF_Customer_RegDate DEFAULT (GETDATE()),
    LoyaltyPoints    INT               NOT NULL CONSTRAINT DF_Customer_Points DEFAULT (0),
    CONSTRAINT PK_Customer PRIMARY KEY (CustomerID),
    CONSTRAINT UQ_Customer_Phone UNIQUE (Phone),
    CONSTRAINT CK_Customer_Points CHECK (LoyaltyPoints >= 0)
);
GO

/* ---------- Бронирования ---------- */
CREATE TABLE dbo.Reservation (
    ReservationID   INT IDENTITY(1,1) NOT NULL,
    CustomerID      INT               NOT NULL,
    TableID         INT               NOT NULL,
    EmployeeID      INT               NOT NULL,
    ReservationDate DATETIME          NOT NULL,
    GuestsCount     INT               NOT NULL,
    ReservationStatus NVARCHAR(20)    NOT NULL CONSTRAINT DF_Reservation_Status DEFAULT (N'Активна'),
    Notes           NVARCHAR(200)     NULL,
    CreatedAt       DATETIME          NOT NULL CONSTRAINT DF_Reservation_CreatedAt DEFAULT (GETDATE()),
    CONSTRAINT PK_Reservation PRIMARY KEY (ReservationID),
    CONSTRAINT FK_Reservation_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customer (CustomerID),
    CONSTRAINT FK_Reservation_Table FOREIGN KEY (TableID) REFERENCES dbo.RestaurantTable (TableID),
    CONSTRAINT FK_Reservation_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.Employee (EmployeeID),
    CONSTRAINT CK_Reservation_Guests CHECK (GuestsCount > 0 AND GuestsCount <= 30),
    CONSTRAINT CK_Reservation_Status CHECK (ReservationStatus IN (N'Активна', N'Выполнена', N'Отменена'))
);
GO

/* ---------- Заказы ---------- */
CREATE TABLE dbo.[Order] (
    OrderID         INT IDENTITY(1,1) NOT NULL,
    TableID         INT               NULL,
    CustomerID      INT               NULL,
    EmployeeID      INT               NOT NULL,
    OrderDate       DATETIME          NOT NULL CONSTRAINT DF_Order_Date DEFAULT (GETDATE()),
    OrderStatus     NVARCHAR(20)      NOT NULL CONSTRAINT DF_Order_Status DEFAULT (N'Оформлен'),
    OrderType       NVARCHAR(20)      NOT NULL CONSTRAINT DF_Order_Type DEFAULT (N'В зале'),
    Notes           NVARCHAR(200)     NULL,
    TotalAmount     DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Order_Total DEFAULT (0),
    DiscountPercent DECIMAL(5,2)      NOT NULL CONSTRAINT DF_Order_Discount DEFAULT (0),
    ClosedAt        DATETIME          NULL,
    CONSTRAINT PK_Order PRIMARY KEY (OrderID),
    CONSTRAINT FK_Order_Table FOREIGN KEY (TableID) REFERENCES dbo.RestaurantTable (TableID),
    CONSTRAINT FK_Order_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customer (CustomerID),
    CONSTRAINT FK_Order_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.Employee (EmployeeID),
    CONSTRAINT CK_Order_Status CHECK (OrderStatus IN (N'Оформлен', N'Готовится', N'Готов', N'Оплачен', N'Отменён')),
    CONSTRAINT CK_Order_Type CHECK (OrderType IN (N'В зале', N'На вынос', N'Доставка')),
    CONSTRAINT CK_Order_Total CHECK (TotalAmount >= 0),
    CONSTRAINT CK_Order_Discount CHECK (DiscountPercent >= 0 AND DiscountPercent <= 100)
);
GO

/* ---------- Позиции заказа ---------- */
CREATE TABLE dbo.OrderItem (
    OrderItemID  INT IDENTITY(1,1) NOT NULL,
    OrderID      INT               NOT NULL,
    DishID       INT               NOT NULL,
    Quantity     INT               NOT NULL,
    PriceAtOrder DECIMAL(12,2)     NOT NULL,
    ItemComment  NVARCHAR(150)     NULL,
    CONSTRAINT PK_OrderItem PRIMARY KEY (OrderItemID),
    CONSTRAINT FK_OrderItem_Order FOREIGN KEY (OrderID) REFERENCES dbo.[Order] (OrderID) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItem_Dish FOREIGN KEY (DishID) REFERENCES dbo.Dish (DishID),
    CONSTRAINT CK_OrderItem_Qty CHECK (Quantity > 0 AND Quantity <= 100),
    CONSTRAINT CK_OrderItem_Price CHECK (PriceAtOrder > 0)
);
GO

/* ---------- Оплаты ---------- */
CREATE TABLE dbo.Payment (
    PaymentID     INT IDENTITY(1,1) NOT NULL,
    OrderID       INT               NOT NULL,
    EmployeeID    INT               NOT NULL,
    PaymentDate   DATETIME          NOT NULL CONSTRAINT DF_Payment_Date DEFAULT (GETDATE()),
    Amount        DECIMAL(12,2)     NOT NULL,
    PaymentMethod NVARCHAR(20)      NOT NULL,
    PaymentStatus NVARCHAR(20)      NOT NULL CONSTRAINT DF_Payment_Status DEFAULT (N'Оплачен'),
    CONSTRAINT PK_Payment PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payment_Order FOREIGN KEY (OrderID) REFERENCES dbo.[Order] (OrderID),
    CONSTRAINT FK_Payment_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.Employee (EmployeeID),
    CONSTRAINT UQ_Payment_Order UNIQUE (OrderID),
    CONSTRAINT CK_Payment_Amount CHECK (Amount > 0),
    CONSTRAINT CK_Payment_Method CHECK (PaymentMethod IN (N'Наличные', N'Карта', N'Онлайн')),
    CONSTRAINT CK_Payment_Status CHECK (PaymentStatus IN (N'Оплачен', N'Возврат'))
);
GO

/* ---------- История статусов заказа ---------- */
CREATE TABLE dbo.OrderStatusHistory (
    HistoryID INT IDENTITY(1,1) NOT NULL,
    OrderID   INT               NOT NULL,
    OldStatus NVARCHAR(20)      NULL,
    NewStatus NVARCHAR(20)      NOT NULL,
    ChangedBy NVARCHAR(100)     NOT NULL,
    ChangedAt DATETIME          NOT NULL CONSTRAINT DF_History_ChangedAt DEFAULT (GETDATE()),
    Comment   NVARCHAR(250)     NULL,
    CONSTRAINT PK_OrderStatusHistory PRIMARY KEY (HistoryID),
    CONSTRAINT FK_History_Order FOREIGN KEY (OrderID) REFERENCES dbo.[Order] (OrderID) ON DELETE CASCADE
);
GO

/* ---------- Журнал аудита ---------- */
CREATE TABLE dbo.AuditLog (
    LogID      BIGINT IDENTITY(1,1) NOT NULL,
    UserID     INT               NULL,
    LoginName  NVARCHAR(100)     NULL,
    ActionTime DATETIME          NOT NULL CONSTRAINT DF_Audit_Time DEFAULT (GETDATE()),
    ActionType NVARCHAR(40)      NOT NULL,
    ObjectName NVARCHAR(80)      NOT NULL,
    ObjectID   NVARCHAR(40)      NULL,
    IPAddress  NVARCHAR(45)      NULL,
    Details    NVARCHAR(500)     NULL,
    CONSTRAINT PK_AuditLog PRIMARY KEY (LogID)
);
GO
