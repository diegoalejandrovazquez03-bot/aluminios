using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/{resource}")]
public sealed class ResourcesController(Store store) : ControllerBase
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
            data.TryAdd("date", JsonSerializer.SerializeToElement(DateTime.UtcNow.ToString("O")));
            data.TryAdd("folio", JsonSerializer.SerializeToElement($"COT-{DateTime.UtcNow:yyyyMMddHHmmss}"));
        }
        if (resource == "solicitudes")
        {
            if (!data.TryGetValue("description", out var description) || description.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(description.GetString()))
                return BadRequest(new { error = "Describe lo que necesitas." });
            data.TryAdd("status", JsonSerializer.SerializeToElement("Enviada"));
            data.TryAdd("date", JsonSerializer.SerializeToElement(DateTime.UtcNow.ToString("yyyy-MM-dd")));
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
        return Ok(store.Save(resource, JsonSerializer.SerializeToElement(data)));
    }
    [HttpDelete("{id:long}")]
    public IActionResult Delete(string resource, long id) => !Session.IsAdmin ? Forbidden() : Allowed.Contains(resource) ? (store.Delete(resource, id) ? NoContent() : NotFound()) : NotFound();

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
