using System.Text.Json;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
// En la nube (Render) el puerto llega en la variable PORT.
var port = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrWhiteSpace(port)) builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
builder.Services.AddControllers();
builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
// Datos: en Supabase/PostgreSQL si hay ConnectionStrings:Database (variable de
// entorno ConnectionStrings__Database); si no, en Data/database.json como antes.
builder.Services.AddSingleton(serviceProvider => new Store(
    serviceProvider.GetRequiredService<IWebHostEnvironment>().ContentRootPath,
    builder.Configuration.GetConnectionString("Database")));
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

/// <summary>
/// Guarda los registros de la app. Todo se lee desde memoria; cada cambio se
/// escribe registro por registro en PostgreSQL (tabla <c>registros</c>) o, sin
/// base de datos configurada, en Data/database.json.
/// </summary>
public sealed class Store
{
    private readonly string _path;
    private readonly string? _connectionString;
    private readonly object _lock = new();
    public Dictionary<string, List<JsonElement>> Tables { get; private set; } = new();

    /// <summary>Cambio pendiente de escribir: registro nuevo/actualizado o borrado.</summary>
    private readonly record struct Change(string Table, long Id, JsonElement? Data);

    public bool UsesDatabase => _connectionString is not null;

    public Store(string contentRoot, string? connectionString = null)
    {
        _path = Path.Combine(contentRoot, "Data", "database.json");
        _connectionString = string.IsNullOrWhiteSpace(connectionString) ? null : ToNpgsql(connectionString.Trim());
        if (_connectionString is null)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            if (File.Exists(_path)) Tables = JsonSerializer.Deserialize<Dictionary<string, List<JsonElement>>>(File.ReadAllText(_path)) ?? new();
            return;
        }
        using var connection = new NpgsqlConnection(_connectionString);
        connection.Open();
        using (var create = new NpgsqlCommand(
            "create table if not exists registros (tabla text not null, id bigint not null, datos jsonb not null, actualizado timestamptz not null default now(), primary key (tabla, id))",
            connection)) create.ExecuteNonQuery();
        using var read = new NpgsqlCommand("select tabla, datos::text from registros order by tabla, id", connection);
        using var reader = read.ExecuteReader();
        while (reader.Read())
        {
            var table = reader.GetString(0);
            if (!Tables.TryGetValue(table, out var list)) Tables[table] = list = new();
            list.Add(JsonDocument.Parse(reader.GetString(1)).RootElement.Clone());
        }
        reader.Close();
        // Primera vez con una base vacía: se suben los datos que había en el archivo.
        if (Tables.Count == 0 && File.Exists(_path))
        {
            Tables = JsonSerializer.Deserialize<Dictionary<string, List<JsonElement>>>(File.ReadAllText(_path)) ?? new();
            Persist([.. Tables.SelectMany(t => t.Value.Where(x => IdOf(x) > 0).Select(x => Upsert(t.Key, x)))]);
        }
    }

    /// <summary>Escribe los cambios: en una sola transacción en PostgreSQL, o el archivo completo.</summary>
    private void Persist(params Change[] changes)
    {
        if (_connectionString is null)
        {
            File.WriteAllText(_path, JsonSerializer.Serialize(Tables));
            return;
        }
        using var connection = new NpgsqlConnection(_connectionString);
        connection.Open();
        using var transaction = connection.BeginTransaction();
        foreach (var change in changes)
        {
            using var command = change.Data is { } data
                ? new NpgsqlCommand(
                    "insert into registros (tabla, id, datos) values (@t, @i, @d::jsonb) on conflict (tabla, id) do update set datos = excluded.datos, actualizado = now()",
                    connection, transaction)
                : new NpgsqlCommand("delete from registros where tabla = @t and id = @i", connection, transaction);
            command.Parameters.AddWithValue("t", change.Table);
            command.Parameters.AddWithValue("i", change.Id);
            if (change.Data is { } json) command.Parameters.AddWithValue("d", json.GetRawText());
            command.ExecuteNonQuery();
        }
        transaction.Commit();
    }

    /// <summary>Acepta la cadena de Supabase en formato URI (postgresql://usuario:clave@host:puerto/base).</summary>
    private static string ToNpgsql(string value)
    {
        if (!value.StartsWith("postgres://") && !value.StartsWith("postgresql://")) return value;
        var uri = new Uri(value);
        var userInfo = uri.UserInfo.Split(':', 2);
        return new NpgsqlConnectionStringBuilder
        {
            Host = uri.Host,
            Port = uri.IsDefaultPort || uri.Port <= 0 ? 5432 : uri.Port,
            Database = uri.AbsolutePath.Trim('/') is { Length: > 0 } db ? db : "postgres",
            Username = Uri.UnescapeDataString(userInfo[0]),
            Password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : null,
            SslMode = SslMode.Require,
        }.ConnectionString;
    }

    private static Change Upsert(string table, JsonElement data) => new(table, IdOf(data), data);
    private static Change Remove(string table, long id) => new(table, id, null);

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
            Persist(Upsert(table, saved));
            return saved;
        }
    }
    public bool Delete(string table, long id)
    {
        lock (_lock)
        {
            var list = Tables.GetValueOrDefault(table, new());
            var count = list.RemoveAll(x => IdOf(x) == id);
            Tables[table] = list;
            if (count > 0) Persist(Remove(table, id));
            return count > 0;
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
            Persist(Remove(table, id), Upsert("papelera", trash[^1]));
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
            var changes = new List<Change> { Upsert(table, record), Remove("papelera", id) };
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
                    changes.Add(Upsert("pagos", payment));
                    changes.Add(Remove("papelera", IdOf(paymentEntry)));
                }
            }
            Tables["papelera"] = trash;
            Persist([.. changes]);
            return record;
        }
    }
}
