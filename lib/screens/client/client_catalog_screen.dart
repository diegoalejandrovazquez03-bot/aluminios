import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/input_rules.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/app_image.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/measure_field.dart';
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
      text: MeasureInput.format(product.width ?? 120),
    );
    final hCtrl = TextEditingController(
      text: MeasureInput.format(product.height ?? 100),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: MeasureField(controller: wCtrl, label: 'Ancho'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: MeasureField(controller: hCtrl, label: 'Alto'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Cant.',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyCtrl.text) ?? 0;
                final w = MeasureInput.parse(wCtrl.text);
                final h = MeasureInput.parse(hCtrl.text);
                if (w == null || h == null || qty < 1) {
                  showSheetMessage(
                    ctx,
                    'Revisa ancho, alto y cantidad: deben ser números mayores a 0',
                  );
                  return;
                }

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
                onNavigate(ClientScreen.pedidos); // Mis pedidos
              },
              child: const Text('Solicitar cotización de esta pieza'),
            ),
          ],
        ),
      ),
    );
  }

  void _requestAppointment(BuildContext context) {
    // Se rellena con la dirección guardada en su perfil.
    final placeCtrl = TextEditingController(
      text: state.currentClient?.address ?? '',
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime date = today.add(const Duration(days: 1));
    // Horario preferido; el taller confirma la hora exacta.
    const slots = {
      'Mañana (9:00 – 12:00)': ['09:00', '12:00'],
      'Tarde (12:00 – 17:00)': ['12:00', '17:00'],
    };
    String slot = slots.keys.first;
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Solicitar visita técnica',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Un técnico de ${state.settings.bizName} acudirá a tu obra o domicilio para tomar medidas exactas. El taller confirmará la hora.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                // Fecha: no se permiten días anteriores a hoy.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('Fecha: ${date.day}/${date.month}/${date.year}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: today,
                      lastDate: DateTime(today.year + 1, 12, 31),
                      helpText: 'Fecha de la visita',
                      cancelText: 'Cancelar',
                      confirmText: 'Aceptar',
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: slot,
                  decoration: const InputDecoration(
                    labelText: 'Horario preferido',
                  ),
                  items: [
                    for (final s in slots.keys)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setSheetState(() => slot = v ?? slot),
                ),
                const SizedBox(height: 12),
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
                    if (date.isBefore(today)) {
                      showSheetMessage(
                        ctx,
                        'Elige una fecha de hoy en adelante',
                      );
                      return;
                    }
                    final clientId = state.session?.clientId;
                    if (clientId == null) return;
                    state.addVisit(
                      Visit(
                        id: DateTime.now().millisecondsSinceEpoch,
                        date: iso(date),
                        start: slots[slot]![0],
                        end: slots[slot]![1],
                        type: 'Toma de medidas',
                        clientId: clientId,
                        place: placeCtrl.text.trim(),
                        status: Visit.requested,
                      ),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Visita solicitada. El taller te confirmará el horario; la verás en "Mis visitas".',
                        ),
                      ),
                    );
                  },
                  child: const Text('Solicitar visita'),
                ),
              ],
            ),
          ),
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
        onAvatarTap: () => onNavigate(ClientScreen.perfil),
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
