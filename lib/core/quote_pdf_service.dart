import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// PDF de la cotización con la marca del taller: franja carbón con el logo,
/// datos del cliente, tabla de piezas y totales.
class QuotePdfService {
  // Colores de la marca (los mismos de AppColors).
  static const _carbon = PdfColor.fromInt(0xFF1E2124);
  static const _aluminum = PdfColor.fromInt(0xFFB8BEC5);
  static const _muted = PdfColor.fromInt(0xFF5B6067);
  static const _soft = PdfColor.fromInt(0xFFF3F3F1);
  static const _line = PdfColor.fromInt(0xFFDEDDD8);

  static final _money = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  static String _mxn(num amount) => _money.format(amount);

  static String _measure(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  /// Arma el documento y devuelve sus bytes (sirve para la vista previa).
  static Future<Uint8List> bytes(
    Quote quote,
    Client? client,
    String businessName,
    String businessPhone,
    String businessAddress,
    String Function(int) productName,
  ) async {
    final logo = await _loadLogo();
    final document = pw.Document(
      title: 'Cotización ${quote.folio}',
      author: businessName,
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
        footer: _footer,
        build: (context) => [
          _header(
            'COTIZACIÓN',
            quote.folio,
            logo,
            businessName,
            businessPhone,
            businessAddress,
          ),
          pw.SizedBox(height: 18),
          _clientBlock(quote, client),
          pw.SizedBox(height: 18),
          _itemsTable(quote, productName),
          pw.SizedBox(height: 14),
          _totals(quote),
        ],
      ),
    );
    return document.save();
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Sin logo el PDF se genera igual, solo con el nombre del negocio.
      return null;
    }
  }

  /// Franja carbón con el logo y el negocio; a la derecha, qué documento es
  /// ([label]) y su número ([code]).
  static pw.Widget _header(
    String label,
    String code,
    pw.MemoryImage? logo,
    String businessName,
    String businessPhone,
    String businessAddress,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(
        color: _carbon,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.ClipRRect(
              horizontalRadius: 4,
              verticalRadius: 4,
              child: pw.Image(
                logo,
                width: 52,
                height: 52,
                fit: pw.BoxFit.cover,
              ),
            ),
            pw.SizedBox(width: 14),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  businessName.toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 4),
                if (businessAddress.isNotEmpty)
                  pw.Text(
                    businessAddress,
                    style: const pw.TextStyle(color: _aluminum, fontSize: 9),
                  ),
                if (businessPhone.isNotEmpty)
                  pw.Text(
                    'Tel. $businessPhone',
                    style: const pw.TextStyle(color: _aluminum, fontSize: 9),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  color: _aluminum,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                code,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _field(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 58,
          child: pw.Text(
            label,
            style: const pw.TextStyle(color: _muted, fontSize: 9),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );

  static pw.Widget _box(String title, List<pw.Widget> children) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: _soft,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _muted,
              fontSize: 8,
              letterSpacing: 1.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          ...children,
        ],
      ),
    ),
  );

  static pw.Widget _clientBox(Client? client) => _box('CLIENTE', [
    _field('Nombre', client?.name ?? 'Sin cliente'),
    if (client != null && client.phone.isNotEmpty)
      _field('Teléfono', client.phone),
    if (client != null && client.address.isNotEmpty)
      _field('Dirección', client.address),
  ]);

  static pw.Widget _clientBlock(Quote quote, Client? client) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _clientBox(client),
        pw.SizedBox(width: 12),
        _box('DATOS', [
          _field('Fecha', quote.date),
          _field('Estado', quote.status.label),
          _field(
            'Piezas',
            '${quote.items.fold<int>(0, (a, it) => a + it.qty)}',
          ),
        ]),
      ],
    );
  }

  static pw.Widget _itemsTable(Quote quote, String Function(int) productName) {
    const cellPadding = pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7);
    return pw.TableHelper.fromTextArray(
      headers: ['Producto', 'Medidas (cm)', 'Cant.', 'P. unitario', 'Importe'],
      data: quote.items
          .map(
            (item) => [
              productName(item.productId),
              '${_measure(item.width)} × ${_measure(item.height)}'
                  '${item.depth == null ? '' : ' × ${_measure(item.depth!)}'}',
              '${item.qty}',
              _mxn(item.unitPrice),
              _mxn(item.subtotal),
            ],
          )
          .toList(),
      border: null,
      headerDecoration: const pw.BoxDecoration(color: _carbon),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerPadding: cellPadding,
      cellPadding: cellPadding,
      oddRowDecoration: const pw.BoxDecoration(color: _soft),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: .5)),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headerAlignments: {
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _totals(Quote quote) => _summary(
    [
      ('Subtotal', _mxn(quote.subtotal)),
      if (quote.discount > 0)
        (
          'Descuento (${_measure(quote.discount)}%)',
          '-${_mxn(quote.discountAmount)}',
        ),
    ],
    'TOTAL',
    _mxn(quote.total),
  );

  /// Renglones de resumen alineados a la derecha y, al final, la cifra
  /// principal en una franja carbón.
  static pw.Widget _summary(
    List<(String, String)> rows,
    String mainLabel,
    String mainValue,
  ) {
    pw.Widget row(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: _muted, fontSize: 10),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 230,
        child: pw.Column(
          children: [
            for (final (label, value) in rows) row(label, value),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: const pw.BoxDecoration(
                color: _carbon,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    mainLabel,
                    style: pw.TextStyle(
                      color: _aluminum,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    mainValue,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: .5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Importes en pesos mexicanos (MXN). Gracias por su preferencia.',
            style: const pw.TextStyle(color: _muted, fontSize: 8),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(color: _muted, fontSize: 8),
          ),
        ],
      ),
    );
  }

  static Future<File> create(
    Quote quote,
    Client? client,
    String businessName,
    String businessPhone,
    String businessAddress,
    String Function(int) productName,
  ) async {
    final pdfBytes = await bytes(
      quote,
      client,
      businessName,
      businessPhone,
      businessAddress,
      productName,
    );
    return _save('cotizacion-${_safe(quote.folio)}', pdfBytes);
  }

  // ---- Recibo de pago ----

  /// Número de recibo: el folio de la cotización y el número de abono,
  /// p. ej. "R-0042-2" para el segundo pago de #0042.
  static String receiptCode(Payment payment, Quote quote, List<Payment> all) {
    final ofQuote = all.where((p) => p.quoteId == quote.id).toList();
    final index = ofQuote.indexWhere((p) => p.id == payment.id);
    return 'R-${_safe(quote.folio)}-${index < 0 ? ofQuote.length + 1 : index + 1}';
  }

  /// Recibo de un abono: monto pagado y cómo queda la cuenta después de él.
  /// [allPayments] son todos los pagos registrados (se toman los de la
  /// cotización hasta este, en el orden en que se registraron).
  static Future<Uint8List> receiptBytes(
    Payment payment,
    Quote quote,
    Client? client,
    List<Payment> allPayments,
    String businessName,
    String businessPhone,
    String businessAddress,
  ) async {
    final logo = await _loadLogo();
    final code = receiptCode(payment, quote, allPayments);
    final ofQuote = allPayments.where((p) => p.quoteId == quote.id).toList();
    final upTo = ofQuote.indexWhere((p) => p.id == payment.id);
    final paidSoFar =
        (upTo < 0 ? [...ofQuote, payment] : ofQuote.take(upTo + 1))
            .fold<double>(0, (a, p) => a + p.amount);
    final balance = (quote.total - paidSoFar).clamp(0.0, double.infinity);

    final document = pw.Document(title: 'Recibo $code', author: businessName);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
        footer: _footer,
        build: (context) => [
          _header(
            'RECIBO DE PAGO',
            code,
            logo,
            businessName,
            businessPhone,
            businessAddress,
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _clientBox(client),
              pw.SizedBox(width: 12),
              _box('PAGO', [
                _field('Fecha', payment.date),
                _field('Método', payment.method),
                _field('Concepto', 'Abono a la cotización ${quote.folio}'),
              ]),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'CANTIDAD RECIBIDA',
                  style: pw.TextStyle(
                    color: _muted,
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _mxn(payment.amount),
                  style: pw.TextStyle(
                    color: _carbon,
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          _summary(
            [
              ('Total de la cotización', _mxn(quote.total)),
              ('Pagado con este abono', _mxn(paidSoFar)),
            ],
            balance <= 0 ? 'LIQUIDADO' : 'SALDO',
            _mxn(balance),
          ),
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.only(top: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: _muted, width: .5),
                  ),
                ),
                child: pw.Text(
                  'Recibí · $businessName',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(color: _muted, fontSize: 9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return document.save();
  }

  static Future<File> createReceipt(
    Payment payment,
    Quote quote,
    Client? client,
    List<Payment> allPayments,
    String businessName,
    String businessPhone,
    String businessAddress,
  ) async {
    final pdfBytes = await receiptBytes(
      payment,
      quote,
      client,
      allPayments,
      businessName,
      businessPhone,
      businessAddress,
    );
    return _save(
      'recibo-${receiptCode(payment, quote, allPayments)}',
      pdfBytes,
    );
  }

  static String _safe(String text) =>
      text.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

  static Future<File> _save(String name, Uint8List pdfBytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$name.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('No se pudo crear el PDF');
    }
    return file;
  }

  static Future<void> share(File file, {String text = 'Cotización en PDF'}) =>
      SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: text),
      );
}
