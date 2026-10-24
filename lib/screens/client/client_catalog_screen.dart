import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/app_image.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';

class ClientCatalogScreen extends StatelessWidget {
  final AppState state;
  final Function(int) onNavigate;

  const ClientCatalogScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  void _requestOrder(BuildContext context, Product product) {
    final qtyCtrl = TextEditingController(text: '1');
    final wCtrl = TextEditingController(
      text: (product.width?.round() ?? 120).toString(),
    );
    final hCtrl = TextEditingController(
      text: (product.height?.round() ?? 100).toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AppImage(product.img, width: 50, height: 42),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        product.material,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: wCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ancho (cm)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: hCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Alto (cm)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyCtrl.text) ?? 1;
                final w = double.tryParse(wCtrl.text) ?? 120.0;
                final h = double.tryParse(hCtrl.text) ?? 100.0;

                final newQuote = Quote(
                  id: DateTime.now().millisecondsSinceEpoch,
                  folio: '#${state.nextFolioNum.toString().padLeft(4, '0')}',
                  clientId: state.session!.clientId,
                  date: AppState.today(),
                  status: QuoteStatus.pendiente,
                  items: [
                    QuoteItem(
                      productId: product.id,
                      width: w,
                      height: h,
                      depth: product.depth,
                      qty: qty,
                      unitPrice: product.price,
                    ),
                  ],
                  discount: 0,
                );

                state.addQuote(newQuote);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cotización ${newQuote.folio} solicitada con éxito',
                    ),
                  ),
                );
                onNavigate(2); // Mis pedidos
              },
              child: const Text('Solicitar cotización de esta pieza'),
            ),
          ],
        ),
      ),
    );
  }

  void _requestAppointment(BuildContext context) {
    final placeCtrl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Agendar Visita Técnica a Domicilio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Un técnico de Aluminios AV acudirá a tu obra o domicilio para tomar medidas exactas y asesorarte sin costo.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: placeCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección o colonia *',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                if (placeCtrl.text.trim().isEmpty) {
                  showSheetMessage(ctx, 'Escribe la dirección o colonia');
                  return;
                }

                final v = Visit(
                  id: DateTime.now().millisecondsSinceEpoch,
                  date:
                      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                  start: '10:00',
                  end: '11:00',
                  type: 'Toma de medidas',
                  clientId: state.session!.clientId,
                  place: placeCtrl.text.trim(),
                );

                state.addVisit(v);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Visita técnica solicitada. Te contactaremos para confirmar el horario.',
                    ),
                  ),
                );
              },
              child: const Text('Confirmar Solicitud de Visita'),
            ),
          ],
        ),
      ),
    );
  }

  void _openProductViewer(BuildContext context, Product p) {
    final hasSize = p.width != null && p.height != null;
    showImageViewer(
      context,
      images: [p.img],
      title: p.name,
      subtitle: '${p.material} • Desde ${AppState.formatMXN(p.price)}',
      details: hasSize
          ? 'Medidas base: ${p.width!.round()} × ${p.height!.round()} cm'
          : null,
      action: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
        onPressed: () {
          Navigator.pop(context);
          _requestOrder(context, p);
        },
        child: const Text('Cotizar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: TopBar(
        title: 'Catálogo de Diseños',
        showLogo: true,
        onAvatarTap: () => onNavigate(3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner for appointment
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.architecture,
                    color: AppColors.onInk,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Medidas especiales?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'Solicita que vayamos a medir a tu obra',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _requestAppointment(context),
                  child: const Text(
                    'Pedir visita',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'MODELOS DISPONIBLES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),

          for (final p in state.products)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openProductViewer(context, p),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AppImage(p.img, width: 74, height: 64),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openProductViewer(context, p),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          Text(
                            p.material,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Desde ${AppState.formatMXN(p.price)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _requestOrder(context, p),
                    child: const Text(
                      'Cotizar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
