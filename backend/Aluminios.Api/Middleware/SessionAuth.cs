using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

// Contraseñas: PBKDF2-SHA256 con sal aleatoria. Formato guardado:
// "pbkdf2-sha256$<iteraciones>$<sal base64>$<hash base64>". Nunca se guarda la contraseña.
public static class PasswordHasher
{
    private const int Iterations = 100_000;
    private const int SaltSize = 16;
    private const int HashSize = 32;

    public static string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, HashSize);
        return $"pbkdf2-sha256${Iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }

    public static bool Verify(string password, string stored)
    {
        var parts = stored.Split('$');
        if (parts.Length != 4 || parts[0] != "pbkdf2-sha256" || !int.TryParse(parts[1], out var iterations)) return false;
        var salt = Convert.FromBase64String(parts[2]);
        var expected = Convert.FromBase64String(parts[3]);
        var actual = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }
}

/// Sesión del usuario que hace la petición (la coloca SessionAuthMiddleware).
public sealed record SessionInfo(long AccountId, string Role, long ClientId, string Email)
{
    public bool IsAdmin => Role == "admin";
}

/// Cuentas y sesiones viven en tablas internas del Store ("cuentas", "sesiones")
/// que el controlador genérico no expone.
public static class Sessions
{
    public const string AccountsTable = "cuentas";
    public const string SessionsTable = "sesiones";
    private static readonly TimeSpan Lifetime = TimeSpan.FromDays(30);

    public static string TokenHash(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    /// Crea una sesión y devuelve el token en claro (solo se guarda su hash).
    public static string Create(Store store, JsonElement account)
    {
        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        store.Save(SessionsTable, JsonSerializer.SerializeToElement(new
        {
            id = 0,
            tokenHash = TokenHash(token),
            accountId = Store.IdOf(account),
            expiresAt = DateTimeOffset.UtcNow.Add(Lifetime),
        }));
        return token;
    }

    public static SessionInfo? Resolve(Store store, string token)
    {
        var hash = TokenHash(token);
        var session = store.Get(SessionsTable).FirstOrDefault(s => s.TryGetProperty("tokenHash", out var h) && h.GetString() == hash);
        if (session.ValueKind == JsonValueKind.Undefined) return null;
        if (session.TryGetProperty("expiresAt", out var exp) && exp.TryGetDateTimeOffset(out var expiresAt) && expiresAt < DateTimeOffset.UtcNow)
        {
            store.Delete(SessionsTable, Store.IdOf(session));
            return null;
        }
        var account = store.Find(AccountsTable, session.GetProperty("accountId").GetInt64());
        return account.ValueKind == JsonValueKind.Undefined ? null : ToSession(account);
    }

    public static void Revoke(Store store, string token)
    {
        var hash = TokenHash(token);
        foreach (var s in store.Get(SessionsTable).Where(s => s.TryGetProperty("tokenHash", out var h) && h.GetString() == hash).ToArray())
            store.Delete(SessionsTable, Store.IdOf(s));
    }

    public static SessionInfo ToSession(JsonElement account) => new(
        Store.IdOf(account),
        account.GetProperty("role").GetString() ?? "client",
        account.TryGetProperty("clientId", out var c) && c.TryGetInt64(out var clientId) ? clientId : 0,
        account.GetProperty("email").GetString() ?? "");

    public static string? BearerToken(HttpContext context)
    {
        var header = context.Request.Headers.Authorization.ToString();
        return header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ? header["Bearer ".Length..].Trim() : null;
    }

    /// Crea la cuenta de administrador la primera vez. La contraseña sale de la
    /// configuración (Admin:Password / variable ADMIN__PASSWORD); si no hay, se
    /// genera una aleatoria y se muestra una sola vez en la consola.
    public static void EnsureAdmin(Store store, IConfiguration config, ILogger logger)
    {
        if (store.Get(AccountsTable).Any(a => a.TryGetProperty("role", out var r) && r.GetString() == "admin")) return;
        var email = (config["Admin:Email"] ?? "admin@aluminieros.com").Trim().ToLowerInvariant();
        var password = config["Admin:Password"];
        if (string.IsNullOrWhiteSpace(password))
        {
            password = Convert.ToBase64String(RandomNumberGenerator.GetBytes(9));
            logger.LogWarning("Cuenta de administrador creada: {Email} / contraseña: {Password}  (cámbiala y guárdala en un lugar seguro)", email, password);
        }
        store.Save(AccountsTable, JsonSerializer.SerializeToElement(new
        {
            id = 0,
            email,
            name = "Administrador",
            phone = "",
            role = "admin",
            clientId = 0,
            passwordHash = PasswordHasher.Hash(password),
        }));
    }
}

/// Exige sesión en toda la API excepto el registro, el inicio de sesión y "/".
public sealed class SessionAuthMiddleware(RequestDelegate next)
{
    private static readonly string[] Public = ["/api/auth/login", "/api/auth/register"];

    public async Task InvokeAsync(HttpContext context, Store store)
    {
        var path = context.Request.Path.Value ?? "";
        if (!path.StartsWith("/api/", StringComparison.OrdinalIgnoreCase) || Public.Any(p => path.Equals(p, StringComparison.OrdinalIgnoreCase))
            || HttpMethods.IsOptions(context.Request.Method))
        {
            await next(context);
            return;
        }
        var token = Sessions.BearerToken(context);
        var session = token is null ? null : Sessions.Resolve(store, token);
        if (session is null)
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new { error = "Tu sesión expiró. Vuelve a iniciar sesión." });
            return;
        }
        context.Items[nameof(SessionInfo)] = session;
        await next(context);
    }
}

public static class HttpContextSessionExtensions
{
    public static SessionInfo Session(this HttpContext context) => (SessionInfo)context.Items[nameof(SessionInfo)]!;
}
