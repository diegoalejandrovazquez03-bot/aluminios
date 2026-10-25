import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/constants.dart';
import '../../core/piece_advisor.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/ai_chat_sheet.dart';
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
  double _discount = 0.0;
  final TextEditingController _discCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _clientId = widget.state.presetClientId;
  }

  double get _subtotal => _items.fold(0.0, (acc, it) => acc + it.subtotal);
  double get _total => _subtotal - (_subtotal * _discount / 100.0);

  void _addItem(Product p) {
    setState(() {
      _items.add(
        QuoteItem(
          productId: p.id,
          width: p.width ?? 120.0,
          height: p.height ?? 100.0,
          depth: p.depth,
          qty: 1,
          unitPrice: p.price,
        ),
      );
    });
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

    final newQuote = Quote(
      id: DateTime.now().millisecondsSinceEpoch,
      folio: '#${widget.state.nextFolioNum.toString().padLeft(4, '0')}',
      clientId: _clientId!,
      date: AppState.today(),
      status: QuoteStatus.pendiente,
      items: _items,
      discount: _discount,
    );

    widget.state.addQuote(newQuote);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cotización ${newQuote.folio} guardada')),
    );
    widget.onNavigate(3); // Go to quotes list
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
      appBar: TopBar(
        title: 'Nueva Cotización',
        onBack: () => widget.onNavigate(3),
      ),
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
                        child: Image.network(
                          suggested.img,
                          width: 42,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
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

  Widget _itemRow(int index, bool isDark) {
    final item = _items[index];
    final prod = widget.state.products
        .where((p) => p.id == item.productId)
        .firstOrNull;

    return Container(
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
                child: Image.network(
                  prod?.img ?? '',
                  width: 44,
                  height: 38,
                  fit: BoxFit.cover,
                ),
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
                onPressed: () => setState(() => _items.removeAt(index)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: item.width.round().toString(),
                  ),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ancho (cm)',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null) {
                      setState(
                        () => _items[index] = QuoteItem(
                          productId: item.productId,
                          width: n,
                          height: item.height,
                          depth: item.depth,
                          qty: item.qty,
                          unitPrice: item.unitPrice,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: item.height.round().toString(),
                  ),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Alto (cm)',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null) {
                      setState(
                        () => _items[index] = QuoteItem(
                          productId: item.productId,
                          width: item.width,
                          height: n,
                          depth: item.depth,
                          qty: item.qty,
                          unitPrice: item.unitPrice,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: item.qty.toString()),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cant.',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      setState(
                        () => _items[index] = QuoteItem(
                          productId: item.productId,
                          width: item.width,
                          height: item.height,
                          depth: item.depth,
                          qty: n,
                          unitPrice: item.unitPrice,
                        ),
                      );
                    }
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
