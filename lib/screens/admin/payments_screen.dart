import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';

class PaymentsScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const PaymentsScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  void _openNewPaymentModal() {
    int? selectedQuoteId;
    final amountCtrl = TextEditingController();
    String method = 'Efectivo';
    final dateCtrl = TextEditingController(text: AppState.today());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          final selectedQuote = selectedQuoteId != null
              ? widget.state.quotes
                    .where((q) => q.id == selectedQuoteId)
                    .firstOrNull
              : null;
          final currentPaid = selectedQuote != null
              ? widget.state.paidOf(selectedQuote.id)
              : 0.0;
          final maxBalance = selectedQuote != null
              ? (selectedQuote.total - currentPaid).clamp(0.0, double.infinity)
              : 0.0;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Registrar Anticipo o Pago',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Select Quote
                  DropdownButtonFormField<int>(
                    initialValue: selectedQuoteId,
                    hint: const Text('Seleccionar pedido / cotización'),
                    items: widget.state.quotes
                        .where((q) => q.status != QuoteStatus.cancelada)
                        .map((q) {
                          final client = widget.state.clients
                              .where((c) => c.id == q.clientId)
                              .firstOrNull;
                          return DropdownMenuItem<int>(
                            value: q.id,
                            child: Text(
                              '${q.folio} - ${client?.name ?? ''} (${AppState.formatMXN(q.total)})',
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedQuoteId = val),
                  ),
                  if (selectedQuote != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Saldo pendiente actual: ${AppState.formatMXN(maxBalance)}',
                      style: TextStyle(
                        color: AppColors.pending,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto a abonar *',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                    ),
                    items: ['Efectivo', 'Transferencia', 'Tarjeta'].map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) =>
                        setModalState(() => method = val ?? 'Efectivo'),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fecha del pago (DD/MM/AAAA)',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      if (selectedQuoteId == null) {
                        showSheetMessage(ctx, 'Selecciona un pedido');
                        return;
                      }
                      final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                      if (amt <= 0) {
                        showSheetMessage(ctx, 'Ingresa un monto mayor a 0');
                        return;
                      }
                      if (amt > maxBalance) {
                        showSheetMessage(
                          ctx,
                          'El monto no puede superar el saldo pendiente (${AppState.formatMXN(maxBalance)})',
                        );
                        return;
                      }

                      final p = Payment(
                        id: DateTime.now().millisecondsSinceEpoch,
                        quoteId: selectedQuoteId!,
                        date: dateCtrl.text.trim().isNotEmpty
                            ? dateCtrl.text.trim()
                            : AppState.today(),
                        amount: amt,
                        method: method,
                      );
                      widget.state.addPayment(p);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Anticipo registrado exitosamente'),
                        ),
                      );
                    },
                    child: const Text('Registrar Pago'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double monthTotal = 0.0;
    for (final p in state.payments) {
      monthTotal += p.amount;
    }

    double pendingBalance = 0.0;
    for (final q in state.quotes) {
      if (q.status != QuoteStatus.cancelada) {
        final paid = state.paidOf(q.id);
        final rem = q.total - paid;
        if (rem > 0) pendingBalance += rem;
      }
    }

    return Scaffold(
      appBar: TopBar(
        title: 'Anticipos y Pagos',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Metrics Cards Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Cobrado',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppState.formatMXN(monthTotal),
                        style: TextStyle(
                          fontFamily: AppText.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.done,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo por Cobrar',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppState.formatMXN(pendingBalance),
                        style: TextStyle(
                          fontFamily: AppText.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pending,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Register button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Registrar nuevo anticipo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: _openNewPaymentModal,
          ),
          const SizedBox(height: 20),

          Text(
            'HISTORIAL DE ANTICIPOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          if (state.payments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Sin pagos registrados',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            for (final p in state.payments.reversed) ...[
              Builder(
                builder: (ctx) {
                  final q = state.quotes
                      .where((x) => x.id == p.quoteId)
                      .firstOrNull;
                  final c = q != null
                      ? state.clients
                            .where((x) => x.id == q.clientId)
                            .firstOrNull
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.completedBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.done,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${q?.folio ?? 'Cotización'} • ${c?.name ?? 'Cliente'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : AppColors.navy,
                                ),
                              ),
                              Text(
                                '${p.date} • ${p.method}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          AppState.formatMXN(p.amount),
                          style: TextStyle(
                            fontFamily: AppText.monoFamily,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.done,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}
