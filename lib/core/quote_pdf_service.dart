import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

class QuotePdfService {
  static Future<File> create(
    Quote quote,
    Client? client,
    String businessName,
    String businessPhone,
    String businessAddress,
    String Function(int) productName,
  ) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            businessName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('$businessAddress | Tel. $businessPhone'),
          pw.SizedBox(height: 18),
          pw.Text(
            'Cotización ${quote.folio}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Cliente: ${client?.name ?? 'Sin cliente'}  |  Teléfono: ${client?.phone ?? '—'}',
          ),
          pw.Text('Fecha: ${quote.date}  |  Estado: ${quote.status.label}'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: [
              'Producto',
              'Medidas (cm)',
              'Cant.',
              'Precio unitario',
              'Importe',
            ],
            data: quote.items
                .map(
                  (item) => [
                    productName(item.productId),
                    '${item.width} × ${item.height}${item.depth == null ? '' : ' × ${item.depth}'}',
                    '${item.qty}',
                    '\$${item.unitPrice.toStringAsFixed(2)}',
                    '\$${item.subtotal.toStringAsFixed(2)}',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Subtotal: \$${quote.subtotal.toStringAsFixed(2)}'),
                if (quote.discount > 0)
                  pw.Text(
                    'Descuento (${quote.discount}%): -\$${quote.discountAmount.toStringAsFixed(2)}',
                  ),
                pw.Text(
                  'TOTAL: \$${quote.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/cotizacion-${quote.folio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')}.pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('No se pudo crear el PDF');
    }
    return file;
  }

  static Future<void> share(File file) => SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: 'Cotización en PDF'),
  );
}
