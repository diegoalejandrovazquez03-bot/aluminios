import 'package:aluminios_app/core/input_rules.dart';
import 'package:aluminios_app/core/quote_pdf_service.dart';
import 'package:aluminios_app/models/models.dart';
import 'package:aluminios_app/screens/admin/quote_detail_screen.dart';
import 'package:aluminios_app/state/app_state.dart';
import 'package:aluminios_app/widgets/sales_chart.dart';
import 'package:flutter_test/flutter_test.dart';

Quote _quote(int id, String date, QuoteStatus status, double price) => Quote(
  id: id,
  folio: '#$id',
  clientId: 1,
  date: date,
  status: status,
  items: [
    QuoteItem(productId: 1, width: 120, height: 100, qty: 1, unitPrice: price),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ventas por mes', () {
    final now = DateTime(2026, 3, 15);

    test('suma aprobado y cobrado de los últimos 6 meses', () {
      final data = monthlySales(
        [
          _quote(1, '10/03/2026', QuoteStatus.aprobada, 5000),
          _quote(2, '2026-03-02', QuoteStatus.entregado, 1000),
          _quote(3, '05/03/2026', QuoteStatus.pendiente, 9000),
          _quote(4, '05/03/2026', QuoteStatus.cancelada, 9000),
          _quote(5, '20/12/2025', QuoteStatus.aprobada, 2500),
          _quote(6, '20/08/2025', QuoteStatus.aprobada, 7777), // fuera
        ],
        [
          Payment(
            id: 1,
            quoteId: 1,
            date: '11/03/2026',
            amount: 2000,
            method: 'Efectivo',
          ),
          Payment(
            id: 2,
            quoteId: 5,
            date: '2026-01-04',
            amount: 500,
            method: 'Transferencia',
          ),
        ],
        now,
      );

      expect(data.length, 6);
      // Octubre 2025 ... marzo 2026 (el año cambia a mitad).
      expect(data.first.month, 10);
      expect(data.first.year, 2025);
      expect(data.last.month, 3);
      expect(data.last.year, 2026);

      expect(data.last.approved, 6000);
      expect(data.last.collected, 2000);
      expect(data[2].approved, 2500); // diciembre
      expect(data[3].collected, 500); // enero
      expect(data.fold<double>(0, (a, m) => a + m.approved), 8500);
    });

    test('fechas inválidas no rompen la gráfica', () {
      final data = monthlySales(
        [_quote(1, 'sin fecha', QuoteStatus.aprobada, 5000)],
        [],
        now,
      );
      expect(data.every((m) => m.approved == 0 && m.collected == 0), isTrue);
    });
  });

  group('Pagos', () {
    final quote = _quote(42, '01/11/2026', QuoteStatus.aprobada, 10000);
    final other = _quote(43, '01/11/2026', QuoteStatus.aprobada, 5000);
    final payments = [
      Payment(
        id: 1,
        quoteId: 42,
        date: '02/11/2026',
        amount: 4000,
        method: 'Efectivo',
      ),
      Payment(
        id: 2,
        quoteId: 43,
        date: '02/11/2026',
        amount: 100,
        method: 'Efectivo',
      ),
      Payment(
        id: 3,
        quoteId: 42,
        date: '05/11/2026',
        amount: 2500.5,
        method: 'Transferencia',
      ),
    ];

    test('el número de recibo cuenta solo los abonos de su cotización', () {
      expect(
        QuotePdfService.receiptCode(payments[0], quote, payments),
        'R-42-1',
      );
      expect(
        QuotePdfService.receiptCode(payments[2], quote, payments),
        'R-42-2',
      );
      expect(
        QuotePdfService.receiptCode(payments[1], other, payments),
        'R-43-1',
      );
    });

    test('el recibo se genera como PDF', () async {
      final bytes = await QuotePdfService.receiptBytes(
        payments[2],
        quote,
        Client(id: 1, name: 'José Martínez', phone: '9993409396'),
        payments,
        'Aluminios',
        '999 340 9396',
        'Mérida, Yucatán',
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('los montos muestran centavos solo cuando los hay', () {
      expect(AppState.formatMXN(12500), r'$ 12,500');
      expect(AppState.formatMXN(1850.5), r'$ 1,850.50');
      expect(AppState.formatMXN(0.1 + 0.2), r'$ 0.30');
      expect(AppState.formatMXN(99.999), r'$ 100');
    });

    test('el campo de monto acepta coma o punto y hasta 2 centavos', () {
      expect(MoneyInput.parse('1850,5'), 1850.5);
      expect(MoneyInput.parse('0'), isNull);
      expect(MoneyInput.parse(''), isNull);
      expect(MoneyInput.format(1500), '1500');
      expect(MoneyInput.format(1500.5), '1500.50');
    });

    test('el recordatorio incluye saldo, total y abonado', () {
      final text = QuoteDetailScreen.reminderMessage(
        bizName: 'Aluminios',
        quote: quote,
        client: Client(id: 1, name: 'José Martínez', phone: '9993409396'),
        paid: 6500.5,
        balance: 3499.5,
      );
      expect(text, startsWith('Hola José, le saludamos de Aluminios.'));
      expect(text, contains('#42'));
      expect(text, contains(r'*$ 3,499.50*'));
      expect(text, contains(r'Total: $ 10,000'));
      expect(text, contains(r'Abonado: $ 6,500.50'));
    });
  });

  test('El PDF de la cotización se genera con logo y acentos', () async {
    final bytes = await QuotePdfService.bytes(
      Quote(
        id: 1,
        folio: '#0042',
        clientId: 1,
        date: '04/11/2026',
        status: QuoteStatus.aprobada,
        discount: 10,
        items: [
          QuoteItem(
            productId: 1,
            width: 120.5,
            height: 100,
            qty: 2,
            unitPrice: 1850,
          ),
          QuoteItem(
            productId: 2,
            width: 90,
            height: 210,
            depth: 12,
            qty: 1,
            unitPrice: 12500,
          ),
        ],
      ),
      Client(
        id: 1,
        name: 'José Martínez',
        phone: '9993409396',
        address: 'Calle 60, Mérida',
      ),
      'Aluminios',
      '999 340 9396',
      'Mérida, Yucatán',
      (id) => id == 1 ? 'Ventana corrediza' : 'Puerta de baño',
    );
    expect(bytes.length, greaterThan(1000));
    // Encabezado de archivo PDF válido.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
