namespace RestaurantApi.Data;

public sealed record UserRecord(
    int UserId,
    string Login,
    byte[] PasswordHash,
    byte[] PasswordSalt,
    int? EmployeeId,
    int RoleId,
    string RoleName,
    bool IsActive,
    string? EmployeeName);
