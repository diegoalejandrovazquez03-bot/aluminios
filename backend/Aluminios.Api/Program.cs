using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddSingleton(serviceProvider => new Store(serviceProvider.GetRequiredService<IWebHostEnvironment>().ContentRootPath));
// Notificaciones en el teléfono: necesitan el archivo de cuenta de servicio de
// Firebase en Firebase:CredentialsPath (user-secrets o variable de entorno
// Firebase__CredentialsPath). Sin él, la API funciona igual sin enviarlas.
builder.Services.AddSingleton<Push>();
// Asistente (Claude): solo se registra si hay clave; la clave nunca viaja a la app.
// Se toma de la variable de entorno ANTHROPIC_API_KEY o de user-secrets ("Anthropic:ApiKey").
var anthropicKey = builder.Configuration["ANTHROPIC_API_KEY"] ?? builder.Configuration["Anthropic:ApiKey"];
if (!string.IsNullOrWhiteSpace(anthropicKey)) builder.Services.AddSingleton(new Anthropic.AnthropicClient { ApiKey = anthropicKey });
var app = builder.Build();
// Crea la cuenta de administrador la primera vez (contraseña desde Admin:Password
// o generada y mostrada una sola vez en la consola).
Sessions.EnsureAdmin(app.Services.GetRequiredService<Store>(), app.Configuration, app.Logger);
app.UseCors();
// Toda la API exige sesión salvo /api/auth/login y /api/auth/register.
app.UseMiddleware<SessionAuthMiddleware>();
app.MapControllers();
app.MapGet("/", () => Results.Ok(new { name = "Aluminios API", status = "ok" }));
app.Run();

public sealed class Store
{
    private readonly string _path;
    private readonly object _lock = new();
    public Dictionary<string, List<JsonElement>> Tables { get; private set; } = new();
    public Store(string contentRoot)
    {
        _path = Path.Combine(contentRoot, "Data", "database.json");
        Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
        if (File.Exists(_path)) Tables = JsonSerializer.Deserialize<Dictionary<string, List<JsonElement>>>(File.ReadAllText(_path)) ?? new();
    }
    // Los IDs son long porque la app móvil los genera con DateTime.now().millisecondsSinceEpoch.
    public static long IdOf(JsonElement entity) => entity.ValueKind == JsonValueKind.Object && entity.TryGetProperty("id", out var e) && e.ValueKind == JsonValueKind.Number && e.TryGetInt64(out var id) ? id : 0;
    public List<JsonElement> Get(string table) { lock (_lock) return Tables.GetValueOrDefault(table, new()).ToList(); }
    public JsonElement Find(string table, long id) => Get(table).FirstOrDefault(x => IdOf(x) == id);
    public JsonElement Save(string table, JsonElement input)
    {
        lock (_lock)
        {
            var list = Tables.GetValueOrDefault(table, new());
            var id = IdOf(input);
            var data = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(input.GetRawText())!;
            if (id <= 0) id = list.Select(IdOf).DefaultIfEmpty().Max() + 1;
            data["id"] = JsonSerializer.SerializeToElement(id);
            var saved = JsonSerializer.SerializeToElement(data);
            var index = list.FindIndex(x => IdOf(x) == id);
            if (index < 0) list.Add(saved); else list[index] = saved;
            Tables[table] = list;
            File.WriteAllText(_path, JsonSerializer.Serialize(Tables));
            return saved;
        }
    }
    public bool Delete(string table, long id)
    {
        lock (_lock)
        {
            var list = Tables.GetValueOrDefault(table, new());
            var count = list.RemoveAll(x => IdOf(x) == id);
            Tables[table] = list; File.WriteAllText(_path, JsonSerializer.Serialize(Tables)); return count > 0;
        }
    }

    public JsonElement Archive(string table, long id)
    {
        lock (_lock)
        {
            var list = Tables.GetValueOrDefault(table, new());
            var index = list.FindIndex(x => IdOf(x) == id);
            if (index < 0) return default;
            var entry = JsonSerializer.SerializeToElement(new { resource = table, archivedAt = DateTimeOffset.UtcNow, record = list[index] });
            list.RemoveAt(index);
            Tables[table] = list;
            var trash = Tables.GetValueOrDefault("papelera", new());
            var nextId = trash.Select(IdOf).DefaultIfEmpty().Max() + 1;
            var payload = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(entry.GetRawText())!;
            payload["id"] = JsonSerializer.SerializeToElement(nextId);
            trash.Add(JsonSerializer.SerializeToElement(payload));
            Tables["papelera"] = trash;
            File.WriteAllText(_path, JsonSerializer.Serialize(Tables));
            return trash[^1];
        }
    }

    public JsonElement Restore(long id)
    {
        lock (_lock)
        {
            var trash = Tables.GetValueOrDefault("papelera", new());
            var entry = trash.FirstOrDefault(x => IdOf(x) == id);
            if (entry.ValueKind == JsonValueKind.Undefined) return default;
            var table = entry.GetProperty("resource").GetString()!;
            var record = entry.GetProperty("record");
            var target = Tables.GetValueOrDefault(table, new());
            target.Add(record);
            Tables[table] = target;
            trash.Remove(entry);
            if (table == "cotizaciones" && record.TryGetProperty("id", out var quoteId))
            {
                var archivedPayments = trash.Where(item => item.TryGetProperty("resource", out var resource) && resource.GetString() == "pagos" && item.TryGetProperty("record", out var payment) && payment.TryGetProperty("quoteId", out var paymentQuoteId) && paymentQuoteId.GetRawText() == quoteId.GetRawText()).ToList();
                foreach (var paymentEntry in archivedPayments)
                {
                    var payment = paymentEntry.GetProperty("record");
                    var payments = Tables.GetValueOrDefault("pagos", new());
                    payments.Add(payment);
                    Tables["pagos"] = payments;
                    trash.Remove(paymentEntry);
                }
            }
            Tables["papelera"] = trash;
            File.WriteAllText(_path, JsonSerializer.Serialize(Tables));
            return record;
        }
    }
}
