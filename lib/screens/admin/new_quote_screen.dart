import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

import '../../core/constants.dart';
import '../../core/input_rules.dart';
import '../../core/app_routes.dart';
import '../../core/piece_advisor.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/ai_chat_sheet.dart';
import '../../widgets/app_image.dart';
import '../../widgets/measure_field.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';

class NewQuoteScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const NewQuoteScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<NewQuoteScreen> createState() => _NewQuoteScreenState();
}

class _NewQuoteScreenState extends State<NewQuoteScreen> {
  int? _clientId;
  final List<QuoteItem> _items = [];
  // Un juego de controladores por pieza, creado una sola vez: si se crearan
  // en build(), cada tecla reiniciaría el campo y se perderían dígitos.
  final List<_ItemFields> _fields = [];
  double _discount = 0.0;
  final TextEditingController _discCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    final preset = widget.state.presetClientId;
    // Solo se preselecciona si el cliente existe; un valor que no está en la
    // lista hace fallar el selector.
    if (widget.state.clients.any((c) => c.id == preset)) _clientId = preset;
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    _discCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (acc, it) => acc + it.subtotal);
  double get _total => _subtotal - (_subtotal * _discount / 100.0);

  void _addItem(Product p) {
    final item = QuoteItem(
      productId: p.id,
      width: p.width ?? 120.0,
      height: p.height ?? 100.0,
      depth: p.depth,
      qty: 1,
      unitPrice: p.price,
    );
    setState(() {
      _items.add(item);
      _fields.add(_ItemFields(item));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _fields.removeAt(index).dispose();
    });
  }

  QuoteItem _withValues(
    QuoteItem item, {
    double? width,
    double? height,
    int? qty,
  }) {
    return QuoteItem(
      productId: item.productId,
      width: width ?? item.width,
      height: height ?? item.height,
      depth: item.depth,
      qty: qty ?? item.qty,
      unitPrice: item.unitPrice,
    );
  }

  void _openProductPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleccionar producto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.state.products.length,
                    itemBuilder: (ctx, i) {
                      final p = widget.state.products[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            p.img,
                            width: 48,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 48,
                              height: 40,
                              child: Icon(Icons.image, color: Colors.black26),
                            ),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          p.material,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          AppState.formatMXN(p.price),
                          style: TextStyle(
                            fontFamily: AppText.monoFamily,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _addItem(p);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openNewClientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

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
              'Nuevo Cliente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre completo *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (10 dígitos) *',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  showSheetMessage(ctx, 'Escribe el nombre del cliente');
                  return;
                }
                if (phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length < 10) {
                  showSheetMessage(ctx, 'El teléfono debe tener 10 dígitos');
                  return;
                }
                final newC = Client(
                  id: DateTime.now().millisecondsSinceEpoch,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                widget.state.addClient(newC);
                setState(() => _clientId = newC.id);
                Navigator.pop(ctx);
              },
              child: const Text('Guardar Cliente'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveQuote() {
    if (_clientId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }
    // Lo que se guarda debe coincidir con lo que se ve en los campos.
    for (int i = 0; i < _fields.length; i++) {
      final f = _fields[i];
      if (MeasureInput.validate(f.width.text) != null ||
          MeasureInput.validate(f.height.text) != null ||
          (int.tryParse(f.qty.text) ?? 0) < 1) {
        setState(() => f.showErrors = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Revisa las medidas de la pieza ${i + 1}: deben ser números mayores a 0.',
            ),
          ),
        );
        return;
      }
    }

    final newQuote = Quote(
      id: DateTime.now().millisecondsSinceEpoch,
      folio: '#${widget.state.nextFolioNum.toString().padLeft(4, '0')}',
      clientId: _clientId!,
      date: AppState.today(),
      status: QuoteStatus.pendiente,
      items: List.of(_items),
      discount: _discount,
    );

    widget.state.addQuote(newQuote);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cotización ${newQuote.folio} guardada')),
    );
    widget.onNavigate(AdminScreen.cotizaciones); // Go to quotes list
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // AI recommendation calculation
    final remainingProducts =
        state.products
            .where((p) => !_items.any((it) => it.productId == p.id))
            .toList()
          ..sort((a, b) => b.margin.compareTo(a.margin));
    final suggested = remainingProducts.isNotEmpty
        ? remainingProducts.first
        : null;

    return Scaffold(
      appBar: TopBar(title: 'Nueva Cotización'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI Assistant Banner
          if (state.settings.ai && suggested != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        color: AppColors.graphite,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Mayor margen disponible',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AppImage(suggested.img, width: 42, height: 36),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sugerido: ${suggested.name} (mayor margen de ganancia: ${suggested.margin.round()}%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _addItem(suggested),
                        child: const Text('Agregar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Client Selector Section
          Text(
            'CLIENTE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _clientId,
                      hint: Text(
                        'Seleccionar cliente...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      isExpanded: true,
                      items: state.clients.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _clientId = val),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                icon: Icon(Icons.person_add, color: AppColors.onInk, size: 20),
                onPressed: _openNewClientDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Products Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRODUCTOS / MEDIDAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${_items.length} pieza(s)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          for (int i = 0; i < _items.length; i++) _itemRow(i, isDark),

          // Add Product dashed button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: BorderSide(color: AppColors.borderStrong, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Agregar producto',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: _openProductPicker,
          ),
          const SizedBox(height: 14),

          // AI Chat Sheet trigger
          if (state.settings.ai)
            Material(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AiChatSheet(
                      currentItems: _items,
                      products: state.products,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.navy,
                        child: Icon(
                          Icons.straighten,
                          color: AppColors.onInk,
                          size: 16,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asesor de cotización',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Toca para consultar sobre vidrios, medidas o márgenes',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.navy),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Financial Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      AppState.formatMXN(_subtotal),
                      style: TextStyle(
                        fontFamily: AppText.monoFamily,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Descuento (%)',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      height: 36,
                      child: TextField(
                        controller: _discCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          suffixText: '%',
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? 0.0;
                          setState(() => _discount = parsed.clamp(0.0, 100.0));
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    Text(
                      AppState.formatMXN(_total),
                      style: TextStyle(
                        fontFamily: AppText.monoFamily,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submit
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _saveQuote,
            child: const Text(
              'Guardar cotización',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  /// Medida de una pieza: el valor solo pasa a la pieza cuando es válido; si
  /// no, se marca el error bajo el campo.
  Widget _measureField({
    required TextEditingController controller,
    required String label,
    required bool showError,
    required void Function(double value) onValid,
  }) {
    final error = MeasureInput.validate(controller.text);
    return MeasureField(
      controller: controller,
      label: label,
      errorText: (showError || controller.text.isNotEmpty) ? error : null,
      onChanged: (v) {
        final value = MeasureInput.parse(v);
        setState(() {
          if (value != null) onValid(value);
        });
      },
    );
  }

  Widget _itemRow(int index, bool isDark) {
    final item = _items[index];
    final fields = _fields[index];
    final prod = widget.state.products
        .where((p) => p.id == item.productId)
        .firstOrNull;

    return Container(
      key: ObjectKey(fields),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AppImage(prod?.img ?? '', width: 44, height: 38),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prod?.name ?? 'Pieza',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      prod?.material ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.cancelled,
                  size: 20,
                ),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _measureField(
                  controller: fields.width,
                  label: 'Ancho',
                  showError: fields.showErrors,
                  onValid: (v) =>
                      _items[index] = _withValues(_items[index], width: v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _measureField(
                  controller: fields.height,
                  label: 'Alto',
                  showError: fields.showErrors,
                  onValid: (v) =>
                      _items[index] = _withValues(_items[index], height: v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: fields.qty,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Cant.',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    errorText:
                        fields.showErrors &&
                            (int.tryParse(fields.qty.text) ?? 0) < 1
                        ? 'Mín. 1'
                        : null,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    setState(() {
                      if (n != null && n > 0) {
                        _items[index] = _withValues(_items[index], qty: n);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Importe línea:',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              Text(
                AppState.formatMXN(item.subtotal),
                style: TextStyle(
                  fontFamily: AppText.monoFamily,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (widget.state.settings.ai)
            ..._pieceAdvice(prod?.name ?? '', item.width, item.height),
        ],
      ),
    );
  }

  List<Widget> _pieceAdvice(String productName, double width, double height) {
    final advice = PieceAdvisor.advise(
      productName: productName,
      widthCm: width,
      heightCm: height,
    );
    if (advice.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Divider(height: 1, color: AppColors.divider),
      const SizedBox(height: 8),
      for (final a in advice)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                a.level == AdviceLevel.warning
                    ? Icons.error_outline
                    : Icons.straighten,
                size: 16,
                color: a.level == AdviceLevel.warning
                    ? AppColors.pending
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.text,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: a.level == AdviceLevel.warning
                        ? AppColors.pendingText
                        : AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

/// Controladores de texto de una pieza de la cotización.
class _ItemFields {
  final TextEditingController width;
  final TextEditingController height;
  final TextEditingController qty;
  bool showErrors = false;

  _ItemFields(QuoteItem item)
    : width = TextEditingController(text: MeasureInput.format(item.width)),
      height = TextEditingController(text: MeasureInput.format(item.height)),
      qty = TextEditingController(text: item.qty.toString());

  void dispose() {
    width.dispose();
    height.dispose();
    qty.dispose();
  }
}
