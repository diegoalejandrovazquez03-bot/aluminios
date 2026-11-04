using System.Globalization;
using System.Text;
using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Beta.Messages;
using Microsoft.AspNetCore.Mvc;

// Redacta con Claude el mensaje de WhatsApp con el que el taller envía una cotización.
// Si no hay ANTHROPIC_API_KEY configurada responde 503 y la app usa su plantilla.
[ApiController]
[Route("api/asistente")]
public sealed class AssistantController(IServiceProvider services, ILogger<AssistantController> logger) : ControllerBase
{
    private const string SystemPrompt = """
        Redactas el mensaje de WhatsApp con el que un taller de cancelería, aluminio y vidrio en México envía una cotización a su cliente.

        - Español de México, trato de usted, tono cordial y profesional. Sin emojis.
        - Se lee en el teléfono: breve y fácil de escanear. Saluda por su nombre, resume las piezas (producto, medidas en cm, cantidad), da el total y, si se indica, el anticipo y el saldo. Menciona la vigencia de la cotización si viene en los datos. Cierra invitando a confirmar o a resolver dudas y firma con el nombre del taller.
        - Usa solo los datos proporcionados. No inventes precios, tiempos de entrega, garantías ni descuentos; si un dato falta, omítelo.
        - Formato de WhatsApp: el total en *negritas* con asteriscos; nada más en negritas; sin encabezados ni markdown.
        - Responde únicamente con el texto del mensaje, listo para enviar.
        """;

    [HttpPost("mensaje-whatsapp")]
    public async Task<IActionResult> DraftWhatsAppMessage([FromBody] WhatsAppDraftRequest request, CancellationToken cancellationToken)
    {
        if (!HttpContext.Session().IsAdmin) return StatusCode(403, new { error = "No tienes permiso para esta acción." });
        var client = services.GetService<AnthropicClient>();
        if (client is null) return StatusCode(503, new { error = "El asistente no está configurado (falta ANTHROPIC_API_KEY)." });
        if (string.IsNullOrWhiteSpace(request.Cliente) || request.Piezas.Count == 0)
            return BadRequest(new { error = "Se requiere el cliente y al menos una pieza." });

        try
        {
            var response = await client.Beta.Messages.Create(new MessageCreateParams
            {
                Model = "claude-opus-5-5",
                MaxTokens = 16000,
                // Mensaje corto y sencillo: esfuerzo bajo basta y responde más rápido.
                OutputConfig = new BetaOutputConfig { Effort = Effort.Low },
                Betas = ["server-side-fallback-2026-07-01"],
                Fallbacks = new Default(),
                System = SystemPrompt,
                Messages = [new BetaUserMessageParam { Content = DescribeQuote(request) }],
            }, cancellationToken);

            if (response.StopReason == "refusal")
                return StatusCode(422, new { error = "El asistente no pudo redactar este mensaje." });

            var text = string.Concat(response.Content.Select(b => b.Value).OfType<BetaTextBlock>().Select(t => t.Text)).Trim();
            if (text.Length == 0) return StatusCode(502, new { error = "El asistente no devolvió texto." });
            return Ok(new { mensaje = text });
        }
        catch (AnthropicRateLimitException ex)
        {
            logger.LogWarning(ex, "Límite de uso del asistente alcanzado");
            return StatusCode(429, new { error = "El asistente está ocupado, intenta en un momento." });
        }
        catch (AnthropicApiException ex)
        {
            logger.LogError(ex, "Error al llamar al asistente");
            return StatusCode(502, new { error = "El asistente no está disponible." });
        }
        catch (HttpRequestException ex)
        {
            logger.LogError(ex, "Sin conexión con el asistente");
            return StatusCode(502, new { error = "El asistente no está disponible." });
        }
    }

    private static string DescribeQuote(WhatsAppDraftRequest r)
    {
        var mx = CultureInfo.GetCultureInfo("es-MX");
        string Money(double v) => v.ToString("C0", mx);
        var sb = new StringBuilder();
        sb.AppendLine("Datos de la cotización:");
        sb.AppendLine($"Taller: {r.Negocio ?? "el taller"}");
        if (!string.IsNullOrWhiteSpace(r.TelefonoNegocio)) sb.AppendLine($"Teléfono del taller: {r.TelefonoNegocio}");
        sb.AppendLine($"Cliente: {r.Cliente}");
        sb.AppendLine($"Folio: {r.Folio}");
        if (!string.IsNullOrWhiteSpace(r.Fecha)) sb.AppendLine($"Fecha: {r.Fecha}");
        if (!string.IsNullOrWhiteSpace(r.Estado)) sb.AppendLine($"Estado: {r.Estado}");
        if (r.VigenciaDias is > 0) sb.AppendLine($"Vigencia: {r.VigenciaDias} días");
        sb.AppendLine("Piezas:");
        foreach (var p in r.Piezas)
            sb.AppendLine($"- {p.Producto}: {p.Ancho:0.#} × {p.Alto:0.#} cm, cantidad {p.Cantidad}, importe {Money(p.Importe)}");
        sb.AppendLine($"Subtotal: {Money(r.Subtotal)}");
        if (r.Descuento > 0) sb.AppendLine($"Descuento: {r.Descuento:0.#}%");
        sb.AppendLine($"Total: {Money(r.Total)}");
        if (r.Pagado > 0)
        {
            sb.AppendLine($"Pagado: {Money(r.Pagado)}");
            sb.AppendLine($"Saldo: {Money(Math.Max(0, r.Total - r.Pagado))}");
        }
        else if (r.AnticipoPorcentaje is > 0)
        {
            sb.AppendLine($"Anticipo requerido: {r.AnticipoPorcentaje:0}% ({Money(r.Total * r.AnticipoPorcentaje.Value / 100)})");
        }
        return sb.ToString();
    }
}

public sealed record WhatsAppDraftPiece(string Producto, double Ancho, double Alto, int Cantidad, double Importe);

public sealed record WhatsAppDraftRequest(
    string Cliente,
    string Folio,
    string? Fecha,
    string? Estado,
    List<WhatsAppDraftPiece> Piezas,
    double Subtotal,
    double Descuento,
    double Total,
    double Pagado,
    string? Negocio,
    string? TelefonoNegocio,
    int? VigenciaDias,
    double? AnticipoPorcentaje);
