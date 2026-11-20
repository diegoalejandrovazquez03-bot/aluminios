using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/{resource}")]
public sealed class ResourcesController(Store store, Push push) : ControllerBase
{
    private static readonly HashSet<string> Allowed = ["clientes", "productos", "cotizaciones", "pedidos", "trabajos", "pagos", "perfil", "visitas", "solicitudes"];

    // ---- Permisos por rol ----
    // El administrador ve y modifica todo. Un cliente solo ve su ficha, sus
    // cotizaciones, pedidos, pagos, visitas y solicitudes, además del
    // catálogo; solo puede crear solicitudes de cotización y visitas a su
    // nombre y editar su propia ficha. Las cotizaciones con precio las hace
    // el taller: si el cliente las creara, podría aprobarlas él mismo.
    private SessionInfo Session => HttpContext.Session();

    private ObjectResult Forbidden() => StatusCode(403, new { error = "No tienes permiso para esta acción." });

    // El taller está en México: la fecha de una solicitud o cotización es la
    // del día allá, no la de UTC (que de noche ya va en el día siguiente).
    private static readonly TimeZoneInfo Mexico = FindMexico();

    private static TimeZoneInfo FindMexico()
    {
        try { return TimeZoneInfo.FindSystemTimeZoneById("America/Mexico_City"); }
        catch (Exception) { return TimeZoneInfo.CreateCustomTimeZone("Mexico", TimeSpan.FromHours(-6), "Mexico", "Mexico"); }
    }

    private static DateTime MexicoNow() => TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, Mexico);

    private static long ClientIdOf(JsonElement item) =>
        item.TryGetProperty("clientId", out var c) && c.ValueKind == JsonValueKind.Number && c.TryGetInt64(out var id) ? id : -1;

    private HashSet<string> OwnQuoteIds() => store.Get("cotizaciones")
        .Where(q => ClientIdOf(q) == Session.ClientId)
        .Select(q => q.GetProperty("id").GetRawText())
        .ToHashSet();

    private bool CanRead(string resource, JsonElement item, HashSet<string>? ownQuotes = null)
    {
        var session = Session;
        if (session.IsAdmin) return true;
        return resource switch
        {
            "productos" or "trabajos" or "perfil" => true,
            "clientes" => Store.IdOf(item) == session.ClientId,
            "cotizaciones" or "visitas" or "solicitudes" => ClientIdOf(item) == session.ClientId,
            "pagos" or "pedidos" => item.TryGetProperty("quoteId", out var q) && (ownQuotes ?? OwnQuoteIds()).Contains(q.GetRawText()),
            _ => false,
        };
    }

    [HttpGet("~/api/papelera")]
    public IActionResult Trash() => Session.IsAdmin ? Ok(store.Get("papelera")) : Forbidden();

    [HttpPost("{id:long}/cancelar")]
    public IActionResult Cancel(string resource, long id)
    {
        if (!Session.IsAdmin) return Forbidden();
        if (resource != "pedidos" && resource != "cotizaciones" && resource != "trabajos") return BadRequest(new { error = "Solo se pueden cancelar pedidos, cotizaciones o trabajos." });
        var archived = store.Archive(resource, id);
        if (archived.ValueKind == JsonValueKind.Undefined) return NotFound();
        var linkedQuoteId = resource == "cotizaciones" ? JsonSerializer.SerializeToElement(id) : archived.TryGetProperty("quoteId", out var quoteId) ? quoteId : default;
        if (linkedQuoteId.ValueKind != JsonValueKind.Undefined)
            foreach (var payment in store.Get("pagos").Where(x => x.TryGetProperty("quoteId", out var linked) && linked.GetRawText() == linkedQuoteId.GetRawText()).ToArray())
                store.Archive("pagos", Store.IdOf(payment));
        return Ok(archived);
    }

    [HttpPost("~/api/papelera/{id:long}/restaurar")]
    public IActionResult RestoreTrash(long id)
    {
        if (!Session.IsAdmin) return Forbidden();
        var record = store.Restore(id);
        return record.ValueKind == JsonValueKind.Undefined ? NotFound() : Ok(record);
    }

    [HttpDelete("~/api/papelera/{id:long}")]
    public IActionResult DeleteTrash(long id) => !Session.IsAdmin ? Forbidden() : store.Delete("papelera", id) ? NoContent() : NotFound();
    [HttpGet]
    public IActionResult List(string resource)
    {
        if (!Allowed.Contains(resource)) return NotFound();
        var ownQuotes = Session.IsAdmin ? null : OwnQuoteIds();
        return Ok(store.Get(resource).Where(item => CanRead(resource, item, ownQuotes)));
    }
    [HttpGet("{id:long}")]
    public IActionResult Get(string resource, long id)
    {
        if (!Allowed.Contains(resource)) return NotFound();
        var entity = store.Find(resource, id);
        return entity.ValueKind == JsonValueKind.Undefined || !CanRead(resource, entity) ? NotFound() : Ok(entity);
    }
    [HttpPost]
    public IActionResult Create(string resource, [FromBody] JsonElement input)
    {
        if (!Allowed.Contains(resource)) return NotFound();
        if (input.ValueKind != JsonValueKind.Object) return BadRequest(new { error = "Se esperaba un objeto JSON." });
        var requestedId = Store.IdOf(input);
        if (requestedId > 0 && store.Find(resource, requestedId).ValueKind != JsonValueKind.Undefined)
            return Conflict(new { error = $"Ya existe un registro con id {requestedId}. Usa PUT para modificarlo." });
        var data = input.Deserialize<Dictionary<string, JsonElement>>()!;
        if (!Session.IsAdmin)
        {
            if (resource != "solicitudes" && resource != "visitas") return Forbidden();
            // Un cliente solo crea registros a su nombre y siempre por revisar.
            data["clientId"] = JsonSerializer.SerializeToElement(Session.ClientId);
            if (resource == "visitas") data["status"] = JsonSerializer.SerializeToElement("Solicitada");
            if (resource == "solicitudes")
            {
                data["status"] = JsonSerializer.SerializeToElement("Enviada");
                data.Remove("quoteId");
                data.Remove("reason");
            }
        }
        if (resource == "cotizaciones")
        {
            if (ApplyQuoteTotals(data) is { } error) return BadRequest(new { error });
            data.TryAdd("status", JsonSerializer.SerializeToElement("Pendiente"));
            data.TryAdd("date", JsonSerializer.SerializeToElement(MexicoNow().ToString("dd/MM/yyyy")));
            data.TryAdd("folio", JsonSerializer.SerializeToElement($"COT-{DateTime.UtcNow:yyyyMMddHHmmss}"));
        }
        if (resource == "solicitudes")
        {
            if (!data.TryGetValue("description", out var description) || description.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(description.GetString()))
                return BadRequest(new { error = "Describe lo que necesitas." });
            data.TryAdd("status", JsonSerializer.SerializeToElement("Enviada"));
            data.TryAdd("date", JsonSerializer.SerializeToElement(MexicoNow().ToString("yyyy-MM-dd")));
        }
        if (resource == "pedidos")
        {
            if (!input.TryGetProperty("quoteId", out var quoteId)) return BadRequest(new { error = "El pedido debe referenciar una cotización." });
            var quote = store.Get("cotizaciones").FirstOrDefault(x => x.TryGetProperty("id", out var qid) && qid.GetRawText() == quoteId.GetRawText());
            if (quote.ValueKind == JsonValueKind.Undefined) return BadRequest(new { error = "La cotización no existe." });
            if (!quote.TryGetProperty("status", out var status) || !string.Equals(status.GetString(), "Aprobada", StringComparison.OrdinalIgnoreCase))
                return Conflict(new { error = "Solo se puede crear un pedido desde una cotización aprobada." });
            if (store.Get("pedidos").Any(x => x.TryGetProperty("quoteId", out var q) && q.GetRawText() == quoteId.GetRawText()))
                return Conflict(new { error = "Esta cotización ya tiene un pedido." });
        }
        var saved = store.Save(resource, JsonSerializer.SerializeToElement(data));
        Notify(resource, default, saved);
        return CreatedAtAction(nameof(Get), new { resource, id = Store.IdOf(saved) }, saved);
    }
    // PUT fusiona: los campos enviados reemplazan a los guardados y los omitidos se conservan (folio, fecha, etc.).
    [HttpPut("{id:long}")]
    public IActionResult Update(string resource, long id, [FromBody] JsonElement input)
    {
        if (!Allowed.Contains(resource)) return NotFound();
        if (input.ValueKind != JsonValueKind.Object) return BadRequest(new { error = "Se esperaba un objeto JSON." });
        var existing = store.Find(resource, id);
        if (!Session.IsAdmin)
        {
            var ownProfile = resource == "clientes" && id == Session.ClientId;
            if (!ownProfile && !IsQuoteResponse(resource, existing, input)) return Forbidden();
        }
        if (existing.ValueKind == JsonValueKind.Undefined) return NotFound();
        var data = existing.Deserialize<Dictionary<string, JsonElement>>()!;
        foreach (var property in input.EnumerateObject()) data[property.Name] = property.Value.Clone();
        data["id"] = JsonSerializer.SerializeToElement(id);
        if (resource == "cotizaciones" && ApplyQuoteTotals(data) is { } error) return BadRequest(new { error });
        var updated = store.Save(resource, JsonSerializer.SerializeToElement(data));
        Notify(resource, existing, updated);
        return Ok(updated);
    }
    [HttpDelete("{id:long}")]
    public IActionResult Delete(string resource, long id) => !Session.IsAdmin ? Forbidden() : Allowed.Contains(resource) ? (store.Delete(resource, id) ? NoContent() : NotFound()) : NotFound();

    // ---- Notificaciones en el teléfono ----
    // Se comparan el registro anterior ([before]; vacío al crear) y el nuevo.
    // Son los mismos avisos que la app genera por dentro.
    private void Notify(string resource, JsonElement before, JsonElement after)
    {
        var created = before.ValueKind == JsonValueKind.Undefined;
        var byAdmin = Session.IsAdmin;
        var id = Store.IdOf(after);
        var clientId = ClientIdOf(after);
        var status = Str(after, "status");
        var statusChanged = !created && Str(before, "status") != status;
        switch (resource)
        {
            case "solicitudes":
                var what = Str(after, "type").ToLowerInvariant();
                if (created && !byAdmin)
                    push.ToAdmins("Nueva solicitud", $"{ClientName(clientId)}: {what}.", new { requestId = id });
                else if (statusChanged && status == "Aceptada")
                    push.ToClient(clientId, Push.Kind.Orders, "Solicitud aceptada",
                        $"El taller aceptó tu solicitud de {what}. Pronto recibirás la cotización.", new { requestId = id });
                else if (statusChanged && status == "Rechazada")
                {
                    var reason = Str(after, "reason");
                    push.ToClient(clientId, Push.Kind.Orders, "Solicitud no aceptada",
                        reason.Length == 0 ? $"El taller no pudo aceptar tu solicitud de {what}." : reason, new { requestId = id });
                }
                break;
            case "cotizaciones":
                var folio = Str(after, "folio");
                if (created && byAdmin)
                    push.ToClient(clientId, Push.Kind.Orders, "Nueva cotización", $"Tienes una nueva cotización {folio}.", new { quoteId = id });
                else if (statusChanged && !byAdmin)
                    push.ToAdmins(status == "Aprobada" ? "Cotización aprobada" : "Cotización rechazada",
                        $"{ClientName(clientId)} {(status == "Aprobada" ? "aprobó" : "rechazó")} la cotización {folio}.", new { quoteId = id });
                else if (statusChanged)
                    push.ToClient(clientId, Push.Kind.Orders, "Tu pedido cambió", $"Tu pedido {folio} ahora está: {status}.", new { quoteId = id });
                if (!created && byAdmin && Count(after, "photos") > Count(before, "photos"))
                    push.ToClient(clientId, Push.Kind.Orders, "Fotos del avance", $"El taller agregó fotos del avance de {folio}.", new { quoteId = id });
                break;
            case "pagos" when created && byAdmin:
                var quote = after.TryGetProperty("quoteId", out var q) && q.TryGetInt64(out var quoteId) ? store.Find("cotizaciones", quoteId) : default;
                if (quote.ValueKind == JsonValueKind.Undefined) break;
                var amount = after.TryGetProperty("amount", out var am) && am.TryGetDecimal(out var value) ? value : 0;
                push.ToClient(ClientIdOf(quote), Push.Kind.Payments, "Abono registrado",
                    $"Se registró un abono de {amount.ToString("C2", Mxn)} en {Str(quote, "folio")}.", new { quoteId = Store.IdOf(quote) });
                break;
            case "visitas":
                if (created && !byAdmin)
                    push.ToAdmins("Visita solicitada", $"{ClientName(clientId)} pidió una visita el {Str(after, "date")}.");
                else if (statusChanged && status == "Confirmada")
                    push.ToClient(clientId, Push.Kind.Visits, "Visita confirmada",
                        $"El taller confirmó tu visita del {Str(after, "date")} ({Str(after, "start")}).");
                break;
        }
    }

    private static readonly CultureInfo Mxn = CultureInfo.GetCultureInfo("es-MX");

    private static string Str(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";

    private static int Count(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Array ? v.GetArrayLength() : 0;

    private string ClientName(long clientId)
    {
        var name = Str(store.Find("clientes", clientId), "name");
        return name.Length == 0 ? "Un cliente" : name;
    }

    // El cliente responde a SU cotización pendiente: solo puede cambiar el
    // estado a "Aprobada" o "Cancelada" (rechazo) y ningún otro campo.
    private bool IsQuoteResponse(string resource, JsonElement existing, JsonElement input)
    {
        if (resource != "cotizaciones" || existing.ValueKind == JsonValueKind.Undefined) return false;
        if (ClientIdOf(existing) != Session.ClientId) return false;
        if (!existing.TryGetProperty("status", out var current) || !string.Equals(current.GetString(), "Pendiente", StringComparison.OrdinalIgnoreCase)) return false;
        var fields = input.EnumerateObject().ToList();
        return fields.Count == 1 && fields[0].Name == "status"
            && fields[0].Value.GetString() is "Aprobada" or "Cancelada";
    }

    // Valida la cotización y recalcula subtotal/total en el servidor. Devuelve el mensaje de error o null.
    private static string? ApplyQuoteTotals(Dictionary<string, JsonElement> data)
    {
        if (!data.ContainsKey("clientId") || !data.TryGetValue("items", out var items) || items.ValueKind != JsonValueKind.Array || items.GetArrayLength() == 0)
            return "La cotización requiere cliente y al menos un concepto.";
        var subtotal = 0m;
        foreach (var item in items.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object || !item.TryGetProperty("qty", out var q) || !TryNumber(q, out var qty) || qty <= 0 || qty != decimal.Truncate(qty)
                || !item.TryGetProperty("unitPrice", out var p) || !TryNumber(p, out var price) || price < 0)
                return "Cantidad y precio deben ser válidos.";
            subtotal += qty * price;
        }
        var discount = data.TryGetValue("discount", out var d) && TryNumber(d, out var discountValue) ? discountValue : 0;
        if (discount < 0 || discount > 100) return "El descuento debe estar entre 0 y 100.";
        data["subtotal"] = JsonSerializer.SerializeToElement(subtotal);
        data["total"] = JsonSerializer.SerializeToElement(subtotal * (100 - discount) / 100);
        return null;
    }
    private static bool TryNumber(JsonElement element, out decimal value)
    {
        value = 0;
        return element.ValueKind == JsonValueKind.Number && element.TryGetDecimal(out value);
    }
}
