using RestaurantApi.Services;
using Xunit;

namespace RestaurantApi.Tests;

public sealed class PasswordHasherTests
{
    private readonly PasswordHasher _hasher = new();

    [Fact]
    public void Hash_And_Verify_ReturnsTrue()
    {
        var (hash, salt) = _hasher.Hash("Admin_12345!");

        Assert.Equal(PasswordHasher.HashSize, hash.Length);
        Assert.Equal(PasswordHasher.SaltSize, salt.Length);
        Assert.True(_hasher.Verify("Admin_12345!", hash, salt));
    }

    [Fact]
    public void Verify_WrongPassword_ReturnsFalse()
    {
        var (hash, salt) = _hasher.Hash("Admin_12345!");

        Assert.False(_hasher.Verify("wrong-password", hash, salt));
    }

    [Fact]
    public void Hash_UsesUniqueSalt()
    {
        var first = _hasher.Hash("Admin_12345!");
        var second = _hasher.Hash("Admin_12345!");

        Assert.NotEqual(first.Salt, second.Salt);
        Assert.NotEqual(first.Hash, second.Hash);
    }

    [Fact]
    public void Hash_ShortPassword_Throws()
    {
        Assert.Throws<ArgumentException>(() => _hasher.Hash("short"));
    }
}
