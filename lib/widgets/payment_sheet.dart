import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/input_rules.dart';
import '../core/quote_pdf_service.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'pdf_preview_screen.dart';
import 'sheet_message.dart';

/// Genera el recibo de un abono y lo abre en la vista previa.
Future<void> openReceipt(
  BuildContext context,
  AppState state,
  Payment payment,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final quote = state.quotes.where((q) => q.id == payment.quoteId).firstOrNull;
  if (quote == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('La cotización de este pago ya no existe.')),
    );
    return;
  }
  try {
    final file = await QuotePdfService.createReceipt(
      payment,
      quote,
      state.clients.where((c) => c.id == quote.clientId).firstOrNull,
      state.payments,
      state.settings.bizName,
      state.settings.bizPhone,
      state.settings.bizAddress,
    );
    if (!context.mounted) return;
    await showPdfPreview(
      context,
      file: file,
      title:
          'Recibo ${QuotePdfService.receiptCode(payment, quote, state.payments)}',
      shareText: 'Recibo de pago',
    );
  } catch (error) {
    debugPrint('No se pudo generar el recibo: $error');
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No se pudo generar el recibo. Inténtalo de nuevo.'),
      ),
    );
  }
}

/// Formulario para registrar un anticipo o abono. Con [quoteId] la
/// cotización ya viene elegida (se abre desde su detalle).
Future<void> showPaymentSheet(
  BuildContext context,
  AppState state, {
  int? quoteId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PaymentSheet(
      state: state,
      quoteId: quoteId,
      // El aviso y el recibo se muestran en la pantalla que abrió la hoja.
      parentContext: context,
    ),
  );
}

class _PaymentSheet extends StatefulWidget {
  final AppState state;
  final int? quoteId;
  final BuildContext parentContext;

  const _PaymentSheet({
    required this.state,
    required this.quoteId,
    required this.parentContext,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  static const _methods = ['Efectivo', 'Transferencia', 'Tarjeta'];

  final _amountCtrl = TextEditingController();
  late int? _quoteId = widget.quoteId;
  String _method = 'Efectivo';
  DateTime _date = DateTime.now();
  String? _amountError;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String get _dateText =>
      '${_date.day.toString().padLeft(2, '0')}/'
      '${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      // Un pago no puede registrarse con fecha futura.
      lastDate: now,
      helpText: 'Fecha del pago',
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save(double balance) {
    if (_quoteId == null) {
      showSheetMessage(context, 'Selecciona un pedido');
      return;
    }
    final amount = MoneyInput.parse(_amountCtrl.text);
    if (amount == null) {
      setState(() => _amountError = 'Ingresa un monto mayor a 0');
      return;
    }
    // Comparación en centavos para no fallar por decimales.
    if ((amount * 100).round() > (balance * 100).round()) {
      setState(
        () => _amountError =
            'No puede superar el saldo (${AppState.formatMXN(balance)})',
      );
      return;
    }

    final payment = Payment(
      id: DateTime.now().millisecondsSinceEpoch,
      quoteId: _quoteId!,
      date: _dateText,
      amount: amount,
      method: _method,
    );
    widget.state.addPayment(payment);
    Navigator.pop(context);

    final parent = widget.parentContext;
    if (!parent.mounted) return;
    ScaffoldMessenger.of(parent).showSnackBar(
      SnackBar(
        content: Text('Pago de ${AppState.formatMXN(amount)} registrado'),
        action: SnackBarAction(
          label: 'Ver recibo',
          onPressed: () {
            if (parent.mounted) openReceipt(parent, widget.state, payment);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quote = _quoteId == null
        ? null
        : state.quotes.where((q) => q.id == _quoteId).firstOrNull;
    final balance = quote == null
        ? 0.0
        : (quote.total - state.paidOf(quote.id)).clamp(0.0, double.infinity);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Registrar anticipo o pago',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (widget.quoteId == null)
                DropdownButtonFormField<int>(
                  initialValue: _quoteId,
                  isExpanded: true,
                  hint: const Text('Seleccionar pedido / cotización'),
                  items: state.quotes
                      .where((q) => q.status != QuoteStatus.cancelada)
                      .map((q) {
                        final client = state.clients
                            .where((c) => c.id == q.clientId)
                            .firstOrNull;
                        return DropdownMenuItem<int>(
                          value: q.id,
                          child: Text(
                            '${q.folio} - ${client?.name ?? ''} (${AppState.formatMXN(q.total)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      })
                      .toList(),
                  onChanged: (val) => setState(() {
                    _quoteId = val;
                    _amountError = null;
                  }),
                )
              else if (quote != null)
                Text(
                  'Cotización ${quote.folio} · Total ${AppState.formatMXN(quote.total)}',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),

              if (quote != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        balance > 0
                            ? 'Saldo pendiente: ${AppState.formatMXN(balance)}'
                            : 'Esta cotización ya está liquidada',
                        style: TextStyle(
                          color: AppColors.pendingText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (balance > 0)
                      TextButton(
                        onPressed: () => setState(() {
                          _amountCtrl.text = MoneyInput.format(balance);
                          _amountError = null;
                        }),
                        child: const Text('Liquidar todo'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              TextField(
                controller: _amountCtrl,
                keyboardType: MoneyInput.keyboard,
                inputFormatters: MoneyInput.formatters,
                decoration: InputDecoration(
                  labelText: 'Monto a abonar *',
                  prefixText: '\$ ',
                  errorText: _amountError,
                ),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
              ),
              const SizedBox(height: 14),

              Text(
                'Método de pago',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in _methods)
                    ChoiceChip(
                      label: Text(m),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(6),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha del pago',
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(_dateText),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: quote != null && balance <= 0
                    ? null
                    : () => _save(balance),
                child: const Text('Registrar pago'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
