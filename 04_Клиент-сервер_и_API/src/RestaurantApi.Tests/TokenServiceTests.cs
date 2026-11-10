using System.IdentityModel.Tokens.Jwt;
using Microsoft.Extensions.Configuration;
using RestaurantApi.Models;
using RestaurantApi.Services;
using Xunit;

namespace RestaurantApi.Tests;

public sealed class TokenServiceTests
{
    private static IConfiguration BuildConfiguration() =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:Issuer"] = "RestaurantApi.Tests",
                ["Jwt:Audience"] = "RestaurantWeb.Tests",
                ["Jwt:Key"] = "TestJwtKey_At_Least_32_Characters_Long_2026!",
                ["Jwt:ExpiresHours"] = "1"
            })
            .Build();

    [Fact]
    public void Create_ReturnsTokenWithRoleAndEmployeeClaims()
    {
        var service = new TokenService(BuildConfiguration());
        var user = new UserInfo(1, "manager", "Manager", 2, "Иванов Иван");

        var (token, expiresAt) = service.Create(user);
        var parsed = new JwtSecurityTokenHandler().ReadJwtToken(token);

        Assert.False(string.IsNullOrWhiteSpace(token));
        Assert.True(expiresAt > DateTime.UtcNow);
        Assert.Contains(parsed.Claims, claim => claim.Value == "Manager");
        Assert.Contains(parsed.Claims, claim => claim.Value == "manager");
        Assert.Contains(parsed.Claims, claim => claim.Value == "2");
    }

    [Fact]
    public void Create_WithoutKey_Throws()
    {
        var configuration = new ConfigurationBuilder().Build();
        var service = new TokenService(configuration);

        Assert.Throws<InvalidOperationException>(() =>
            service.Create(new UserInfo(1, "admin", "Director", null, null)));
    }
}
