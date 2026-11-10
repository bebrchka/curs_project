using System.Text.RegularExpressions;

namespace RestaurantApi.Services;

public static partial class Validation
{
    [GeneratedRegex(@"^\+?[0-9\-\s\(\)]{10,20}$")]
    private static partial Regex PhoneRegex();

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex EmailRegex();

    public static bool IsValidPhone(string? phone) =>
        !string.IsNullOrWhiteSpace(phone) && PhoneRegex().IsMatch(phone);

    public static bool IsValidEmail(string? email) =>
        string.IsNullOrWhiteSpace(email) || EmailRegex().IsMatch(email);

    public static string RequireString(string? value, string field, int maxLength = 200)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new ApiException("VALIDATION", $"Поле «{field}» обязательно", StatusCodes.Status400BadRequest);
        var trimmed = value.Trim();
        if (trimmed.Length > maxLength)
            throw new ApiException("VALIDATION", $"Поле «{field}» длиннее {maxLength} символов", StatusCodes.Status400BadRequest);
        return trimmed;
    }

    public static string? OptionalString(string? value, int maxLength = 200)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;
        var trimmed = value.Trim();
        if (trimmed.Length > maxLength)
            throw new ApiException("VALIDATION", $"Поле длиннее {maxLength} символов", StatusCodes.Status400BadRequest);
        return trimmed;
    }
}
