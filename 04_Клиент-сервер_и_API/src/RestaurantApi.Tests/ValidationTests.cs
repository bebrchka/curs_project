using RestaurantApi.Services;
using Xunit;

namespace RestaurantApi.Tests;

public sealed class ValidationTests
{
    [Theory]
    [InlineData("+7 (999) 123-45-67")]
    [InlineData("89991234567")]
    [InlineData("+7 999 123 45 67")]
    public void IsValidPhone_AcceptsRussianFormats(string phone)
    {
        Assert.True(Validation.IsValidPhone(phone));
    }

    [Theory]
    [InlineData("")]
    [InlineData("abc")]
    [InlineData("123")]
    public void IsValidPhone_RejectsInvalid(string phone)
    {
        Assert.False(Validation.IsValidPhone(phone));
    }

    [Theory]
    [InlineData("guest@example.com")]
    [InlineData(null)]
    [InlineData("")]
    public void IsValidEmail_AcceptsEmptyOrValid(string? email)
    {
        Assert.True(Validation.IsValidEmail(email));
    }

    [Fact]
    public void IsValidEmail_RejectsInvalid()
    {
        Assert.False(Validation.IsValidEmail("not-an-email"));
    }

    [Fact]
    public void RequireString_TrimsAndReturns()
    {
        Assert.Equal("Борщ", Validation.RequireString("  Борщ  ", "Название"));
    }

    [Fact]
    public void RequireString_Empty_ThrowsApiException()
    {
        var exception = Assert.Throws<ApiException>(() => Validation.RequireString(" ", "Название"));
        Assert.Equal("VALIDATION", exception.Code);
        Assert.Equal(400, exception.StatusCode);
    }
}
