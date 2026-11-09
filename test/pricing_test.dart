import 'package:aluminios_app/models/models.dart';
import 'package:aluminios_app/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cobro por m²', () {
    test('el precio de una pieza es ancho × alto × precio del m²', () {
      final item = QuoteItem.byArea(
        productId: 1,
        width: 120,
        height: 100,
        qty: 2,
        pricePerM2: 100,
      );
      expect(item.area, closeTo(1.2, 1e-9));
      expect(item.unitPrice, 120);
      expect(item.subtotal, 240);
      expect(item.totalArea, closeTo(2.4, 1e-9));
    });

    test('redondea a centavos', () {
      // 33.3 × 33.3 cm = 0.110889 m² × $100 = $11.0889 → $11.09
      expect(QuoteItem.priceFor(33.3, 33.3, 100), 11.09);
    });

    test('las piezas guardan precio del m² y nota', () {
      final item = QuoteItem.byArea(
        productId: 3,
        width: 80,
        height: 190,
        qty: 1,
        pricePerM2: 100,
        note: 'Baño principal',
      );
      final copy = QuoteItem.fromMap(item.toMap());
      expect(copy.pricePerM2, 100);
      expect(copy.note, 'Baño principal');
      expect(copy.unitPrice, item.unitPrice);
    });

    test('las cotizaciones anteriores conservan su precio por pieza', () {
      final old = QuoteItem.fromMap({
        'productId': 1,
        'width': 120,
        'height': 100,
        'qty': 1,
        'unitPrice': 1200,
      });
      expect(old.pricePerM2, isNull);
      expect(old.subtotal, 1200);
      expect(AppState.itemDetail(old), '120 × 100 cm · \$ 1,200 c/u');
    });

    test('la descripción de una pieza muestra área y precio del m²', () {
      final item = QuoteItem.byArea(
        productId: 1,
        width: 120,
        height: 100,
        qty: 1,
        pricePerM2: 100,
      );
      expect(AppState.itemDetail(item), '120 × 100 cm · 1.20 m² × \$ 100');
    });
  });
}
