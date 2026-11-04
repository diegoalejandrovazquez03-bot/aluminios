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
        var saved = store.Save(Sessions.AccountsTable, JsonSerializer.SerializeToElement(data));
        if (session.ClientId > 0 && store.Find("clientes", session.ClientId).ValueKind != JsonValueKind.Undefined)
            store.Save("clientes", JsonSerializer.SerializeToElement(new { id = session.ClientId, name, phone = request.Phone }));
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
        };
    }

    private static object SessionResponse(JsonElement account, string token) => new { token, profile = Profile(account) };
}

public sealed record RegisterRequest(string Name, string Phone, string Email, string Password);
public sealed record LoginRequest(string Email, string Password);
public sealed record UpdateProfileRequest(string Name, string Phone, string Email);
public sealed record ChangePasswordRequest(string Current, string New);
