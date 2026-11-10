using System.Security.Cryptography;

namespace RestaurantApi.Services;

public sealed class PasswordHasher
{
    public const int SaltSize = 16;
    public const int HashSize = 32;
    public const int Iterations = 100_000;

    public (byte[] Hash, byte[] Salt) Hash(string password)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(password);
        if (password.Length < 8)
            throw new ArgumentException("Пароль должен содержать не менее 8 символов", nameof(password));

        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(
            password,
            salt,
            Iterations,
            HashAlgorithmName.SHA256,
            HashSize);
        return (hash, salt);
    }

    public bool Verify(string password, byte[] hash, byte[] salt)
    {
        if (string.IsNullOrEmpty(password) || hash.Length == 0 || salt.Length == 0)
            return false;

        var computed = Rfc2898DeriveBytes.Pbkdf2(
            password,
            salt,
            Iterations,
            HashAlgorithmName.SHA256,
            HashSize);
        return CryptographicOperations.FixedTimeEquals(computed, hash);
    }
}
