using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;

// Cuentas de usuario: el cliente se registra aquí (crea su cuenta y su ficha
// en "clientes"); el administrador se crea al arrancar (Sessions.EnsureAdmin).
[ApiController]
[Route("api/auth")]
public sealed partial class AuthController(Store store) : ControllerBase
{
    private const int MinPassword = 6;

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex EmailPattern();

    [GeneratedRegex(@"^\d{10}$")]
    private static partial Regex PhonePattern();

    [HttpPost("register")]
    public IActionResult Register([FromBody] RegisterRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var name = request.Name.Trim();
        if (name.Length == 0) return BadRequest(new { error = "Ingresa tu nombre completo" });
        if (!PhonePattern().IsMatch(request.Phone)) return BadRequest(new { error = "El teléfono debe tener exactamente 10 dígitos" });
        if (!EmailPattern().IsMatch(email)) return BadRequest(new { error = "Escribe un correo válido" });
        if (request.Password.Length < MinPassword) return BadRequest(new { error = $"La contraseña debe tener al menos {MinPassword} caracteres" });
        if (FindAccount(email).ValueKind != JsonValueKind.Undefined) return Conflict(new { error = "Este correo ya está registrado" });

        var client = store.Save("clientes", JsonSerializer.SerializeToElement(new { id = 0, name, phone = request.Phone }));
        var account = store.Save(Sessions.AccountsTable, JsonSerializer.SerializeToElement(new
        {
            id = 0,
            email,
            name,
            phone = request.Phone,
            role = "client",
            clientId = Store.IdOf(client),
            passwordHash = PasswordHasher.Hash(request.Password),
        }));
        return Ok(SessionResponse(account, Sessions.Create(store, account)));
    }

    [HttpPost("login")]
    public IActionResult Login([FromBody] LoginRequest request)
    {
        var account = FindAccount(request.Email.Trim().ToLowerInvariant());
        // Mismo mensaje si el correo no existe o la contraseña es incorrecta.
        if (account.ValueKind == JsonValueKind.Undefined
            || !PasswordHasher.Verify(request.Password, account.GetProperty("passwordHash").GetString() ?? ""))
            return Unauthorized(new { error = "Correo o contraseña incorrectos" });
        return Ok(SessionResponse(account, Sessions.Create(store, account)));
    }

    [HttpGet("me")]
    public IActionResult Me()
    {
        var account = store.Find(Sessions.AccountsTable, HttpContext.Session().AccountId);
        return account.ValueKind == JsonValueKind.Undefined ? Unauthorized() : Ok(Profile(account));
    }

    [HttpPut("me")]
    public IActionResult UpdateMe([FromBody] UpdateProfileRequest request)
    {
        var session = HttpContext.Session();
        var account = store.Find(Sessions.AccountsTable, session.AccountId);
        if (account.ValueKind == JsonValueKind.Undefined) return Unauthorized();
        var email = request.Email.Trim().ToLowerInvariant();
        var name = request.Name.Trim();
        if (name.Length == 0) return BadRequest(new { error = "Escribe tu nombre" });
        if (!PhonePattern().IsMatch(request.Phone)) return BadRequest(new { error = "El teléfono debe tener exactamente 10 dígitos" });
        if (!EmailPattern().IsMatch(email)) return BadRequest(new { error = "Escribe un correo válido" });
        var other = FindAccount(email);
        if (other.ValueKind != JsonValueKind.Undefined && Store.IdOf(other) != session.AccountId)
            return Conflict(new { error = "Ese correo ya está registrado en otra cuenta" });

        var data = account.Deserialize<Dictionary<string, JsonElement>>()!;
        data["email"] = JsonSerializer.SerializeToElement(email);
        data["name"] = JsonSerializer.SerializeToElement(name);
        data["phone"] = JsonSerializer.SerializeToElement(request.Phone);
        var address = (request.Address ?? "").Trim();
        data["address"] = JsonSerializer.SerializeToElement(address);
        var saved = store.Save(Sessions.AccountsTable, JsonSerializer.SerializeToElement(data));
        if (session.ClientId > 0 && store.Find("clientes", session.ClientId).ValueKind != JsonValueKind.Undefined)
            {
            var client = store.Find("clientes", session.ClientId).Deserialize<Dictionary<string, JsonElement>>()!;
            client["name"] = JsonSerializer.SerializeToElement(name);
            client["phone"] = JsonSerializer.SerializeToElement(request.Phone);
            client["address"] = JsonSerializer.SerializeToElement(address);
            store.Save("clientes", JsonSerializer.SerializeToElement(client));
        }
        return Ok(Profile(saved));
    }

    [HttpPost("password")]
    public IActionResult ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var session = HttpContext.Session();
        var account = store.Find(Sessions.AccountsTable, session.AccountId);
        if (account.ValueKind == JsonValueKind.Undefined) return Unauthorized();
        if (!PasswordHasher.Verify(request.Current, account.GetProperty("passwordHash").GetString() ?? ""))
            return BadRequest(new { error = "La contraseña actual no es correcta" });
        if (request.New.Length < MinPassword) return BadRequest(new { error = $"La contraseña debe tener al menos {MinPassword} caracteres" });
        if (request.New == request.Current) return BadRequest(new { error = "La nueva contraseña debe ser distinta de la actual" });
        var data = account.Deserialize<Dictionary<string, JsonElement>>()!;
        data["passwordHash"] = JsonSerializer.SerializeToElement(PasswordHasher.Hash(request.New));
        store.Save(Sessions.AccountsTable, JsonSerializer.SerializeToElement(data));
        return NoContent();
    }

    // Foto de perfil (data:image/...;base64). Se limita el tamaño para no
    // saturar el almacenamiento; la app la manda ya reducida.
    [HttpPut("avatar")]
    public IActionResult UpdateAvatar([FromBody] AvatarRequest request)
    {
        var account = store.Find(Sessions.AccountsTable, HttpContext.Session().AccountId);
        if (account.ValueKind == JsonValueKind.Undefined) return Unauthorized();
        var url = request.AvatarUrl ?? "";
        if (url.Length > 0 && !url.StartsWith("data:image/", StringComparison.Ordinal))
            return BadRequest(new { error = "La foto no tiene un formato válido." });
        if (url.Length > 1_500_000) return BadRequest(new { error = "La foto es demasiado grande." });
        var data = account.Deserialize<Dictionary<string, JsonElement>>()!;
        data["avatarUrl"] = JsonSerializer.SerializeToElement(url);
        return Ok(Profile(store.Save(Sessions.AccountsTable, JsonSerializer.SerializeToElement(data))));
    }

    // Eliminar la cuenta (requisito de Google Play). Pide la contraseña.
    // Se borran la cuenta, sus sesiones, la ficha del cliente, sus visitas y
    // sus solicitudes de cotización (traen fotos y descripciones de su casa).
    // Las cotizaciones y pagos se conservan como registro comercial del taller.
    [HttpDelete("me")]
    public IActionResult DeleteMe([FromBody] DeleteAccountRequest request)
    {
        var session = HttpContext.Session();
        if (session.IsAdmin) return BadRequest(new { error = "La cuenta del administrador no se puede eliminar desde la app." });
        var account = store.Find(Sessions.AccountsTable, session.AccountId);
        if (account.ValueKind == JsonValueKind.Undefined) return Unauthorized();
        if (!PasswordHasher.Verify(request.Password, account.GetProperty("passwordHash").GetString() ?? ""))
            return BadRequest(new { error = "La contraseña no es correcta" });

        foreach (var s in store.Get(Sessions.SessionsTable)
                     .Where(s => s.TryGetProperty("accountId", out var a) && a.GetInt64() == session.AccountId).ToArray())
            store.Delete(Sessions.SessionsTable, Store.IdOf(s));
        foreach (var resource in new[] { "visitas", "solicitudes" })
            foreach (var v in store.Get(resource)
                         .Where(v => v.TryGetProperty("clientId", out var c) && c.TryGetInt64(out var id) && id == session.ClientId).ToArray())
                store.Delete(resource, Store.IdOf(v));
        if (session.ClientId > 0) store.Delete("clientes", session.ClientId);
        store.Delete(Sessions.AccountsTable, session.AccountId);
        return NoContent();
    }

    [HttpPost("logout")]
    public IActionResult Logout()
    {
        if (Sessions.BearerToken(HttpContext) is { } token) Sessions.Revoke(store, token);
        return NoContent();
    }

    private JsonElement FindAccount(string email) =>
        store.Get(Sessions.AccountsTable).FirstOrDefault(a => a.TryGetProperty("email", out var e) && e.GetString() == email);

    // Nunca se devuelve el hash de la contraseña.
    private static object Profile(JsonElement account)
    {
        var s = Sessions.ToSession(account);
        return new
        {
            role = s.Role,
            clientId = s.ClientId,
            email = s.Email,
            name = account.TryGetProperty("name", out var n) ? n.GetString() : "",
            phone = account.TryGetProperty("phone", out var p) ? p.GetString() : "",
            address = account.TryGetProperty("address", out var a) ? a.GetString() : "",
            avatarUrl = account.TryGetProperty("avatarUrl", out var av) ? av.GetString() : "",
        };
    }

    private static object SessionResponse(JsonElement account, string token) => new { token, profile = Profile(account) };
}

public sealed record RegisterRequest(string Name, string Phone, string Email, string Password);
public sealed record LoginRequest(string Email, string Password);
public sealed record UpdateProfileRequest(string Name, string Phone, string Email, string? Address = null);
public sealed record AvatarRequest(string AvatarUrl);
public sealed record DeleteAccountRequest(string Password);
public sealed record ChangePasswordRequest(string Current, string New);
