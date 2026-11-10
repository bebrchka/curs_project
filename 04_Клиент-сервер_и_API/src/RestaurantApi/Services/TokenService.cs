using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using RestaurantApi.Models;

namespace RestaurantApi.Services;

public sealed class TokenService
{
    private readonly IConfiguration _configuration;

    public TokenService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public (string Token, DateTime ExpiresAt) Create(UserInfo user)
    {
        var key = _configuration["Jwt:Key"]
            ?? throw new InvalidOperationException("Не задан Jwt:Key");
        var issuer = _configuration["Jwt:Issuer"] ?? "RestaurantApi";
        var audience = _configuration["Jwt:Audience"] ?? "RestaurantWeb";
        var hours = _configuration.GetValue("Jwt:ExpiresHours", 8);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.UserId.ToString()),
            new(ClaimTypes.Name, user.Login),
            new(ClaimTypes.Role, user.Role),
            new("employeeId", user.EmployeeId?.ToString() ?? string.Empty),
            new("employeeName", user.EmployeeName ?? string.Empty)
        };

        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
            SecurityAlgorithms.HmacSha256);

        var expiresAt = DateTime.UtcNow.AddHours(hours);
        var token = new JwtSecurityToken(
            issuer,
            audience,
            claims,
            expires: expiresAt,
            signingCredentials: credentials);

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }
}
