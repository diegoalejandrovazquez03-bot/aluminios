using System.Text.Json;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;

/// Notificaciones en el teléfono (Firebase Cloud Messaging).
///
/// Cada teléfono registra su identificador de Firebase (FID) ligado a la sesión con la que
/// entró (tabla "dispositivos"): al cerrar sesión o al vencer, deja de
/// recibir avisos. Si el servidor no tiene credenciales de Firebase
/// (Firebase:CredentialsPath), no se envía nada y la app sigue con los
/// avisos internos.
public sealed class Push
{
    public const string DevicesTable = "dispositivos";

    /// Qué preferencia del cliente cubre cada aviso (Perfil › Avisos).
    public enum Kind { Orders, Payments, Visits }

    private readonly Store _store;
    private readonly ILogger<Push> _logger;
    private readonly FirebaseMessaging? _messaging;

    public Push(Store store, IConfiguration config, ILogger<Push> logger)
    {
        _store = store;
        _logger = logger;
        var path = config["Firebase:CredentialsPath"];
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            logger.LogWarning("Notificaciones desactivadas: falta Firebase:CredentialsPath (archivo de cuenta de servicio).");
            return;
        }
        var app = FirebaseApp.DefaultInstance ?? FirebaseApp.Create(new AppOptions
        {
            Credential = CredentialFactory.FromFile<ServiceAccountCredential>(path).ToGoogleCredential(),
        });
        _messaging = FirebaseMessaging.GetMessaging(app);
    }

    public bool Enabled => _messaging != null;

    /// Registra (o actualiza) el teléfono de la sesión [sessionHash].
    public void Register(SessionInfo session, string sessionHash, string token, bool orders, bool payments, bool visits)
    {
        // Un token es de un solo teléfono: si antes entró otra cuenta, se reemplaza.
        foreach (var d in Devices().Where(d => Text(d, "pushToken") == token).ToArray())
            _store.Delete(DevicesTable, Store.IdOf(d));
        _store.Save(DevicesTable, JsonSerializer.SerializeToElement(new
        {
            id = 0,
            pushToken = token,
            sessionHash,
            accountId = session.AccountId,
            orders,
            payments,
            visits,
        }));
    }

    /// Quita los teléfonos de una sesión cerrada.
    public void ForgetSession(string sessionHash)
    {
        foreach (var d in Devices().Where(d => Text(d, "sessionHash") == sessionHash).ToArray())
            _store.Delete(DevicesTable, Store.IdOf(d));
    }

    public void ForgetAccount(long accountId)
    {
        foreach (var d in Devices().Where(d => AccountOf(d) == accountId).ToArray())
            _store.Delete(DevicesTable, Store.IdOf(d));
    }

    /// Aviso a todos los teléfonos del taller.
    public void ToAdmins(string title, string body, object? data = null) =>
        Send(Recipients(a => Text(a, "role") == "admin", kind: null), title, body, data);

    /// Aviso al cliente [clientId], si lo quiere recibir.
    public void ToClient(long clientId, Kind kind, string title, string body, object? data = null) =>
        Send(Recipients(a => Text(a, "role") == "client" && ClientOf(a) == clientId, kind), title, body, data);

    // Tokens de los teléfonos de las cuentas elegidas que siguen con su
    // sesión abierta y no apagaron ese tipo de aviso.
    private List<string> Recipients(Func<JsonElement, bool> account, Kind? kind)
    {
        if (!Enabled) return [];
        var accounts = _store.Get(Sessions.AccountsTable).Where(account).Select(Store.IdOf).ToHashSet();
        var now = DateTimeOffset.UtcNow;
        var liveSessions = _store.Get(Sessions.SessionsTable)
            .Where(s => !(s.TryGetProperty("expiresAt", out var e) && e.TryGetDateTimeOffset(out var at) && at < now))
            .Select(s => Text(s, "tokenHash"))
            .ToHashSet();
        var flag = kind switch { Kind.Orders => "orders", Kind.Payments => "payments", Kind.Visits => "visits", _ => null };
        return Devices()
            .Where(d => accounts.Contains(AccountOf(d)) && liveSessions.Contains(Text(d, "sessionHash")))
            .Where(d => flag == null || !d.TryGetProperty(flag, out var on) || on.ValueKind != JsonValueKind.False)
            .Select(d => Text(d, "pushToken"))
            .Distinct()
            .ToList();
    }

    // Se envía en segundo plano: la respuesta a la app no espera a Firebase.
    private void Send(List<string> tokens, string title, string body, object? data)
    {
        if (_messaging == null || tokens.Count == 0) return;
        var payload = new Dictionary<string, string>();
        if (data != null)
            foreach (var p in JsonSerializer.SerializeToElement(data).EnumerateObject())
                payload[p.Name] = p.Value.ToString();
        var message = new MulticastMessage
        {
            Fids = tokens,
            Notification = new Notification { Title = title, Body = body },
            Data = payload,
            Android = new AndroidConfig
            {
                Priority = Priority.High,
                Notification = new AndroidNotification { ChannelId = "avisos" },
            },
        };
        _ = Task.Run(async () =>
        {
            try
            {
                var result = await _messaging.SendEachForMulticastAsync(message);
                // Tokens de teléfonos que ya desinstalaron la app: se olvidan.
                for (var i = 0; i < result.Responses.Count; i++)
                {
                    if (result.Responses[i].Exception?.MessagingErrorCode is MessagingErrorCode.Unregistered or MessagingErrorCode.InvalidArgument)
                        foreach (var d in Devices().Where(d => Text(d, "pushToken") == tokens[i]).ToArray())
                            _store.Delete(DevicesTable, Store.IdOf(d));
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudo enviar la notificación \"{Title}\".", title);
            }
        });
    }

    private List<JsonElement> Devices() => _store.Get(DevicesTable);

    private static string Text(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";

    private static long AccountOf(JsonElement d) =>
        d.TryGetProperty("accountId", out var v) && v.TryGetInt64(out var id) ? id : -1;

    private static long ClientOf(JsonElement a) =>
        a.TryGetProperty("clientId", out var v) && v.TryGetInt64(out var id) ? id : -1;
}
