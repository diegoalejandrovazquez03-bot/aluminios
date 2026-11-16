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
import '../../widgets/avatar_widget.dart';
import '../../widgets/measure_field.dart';
import '../../widgets/request_widgets.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';
import 'measure_screen.dart';

/// Cotizador en tres pasos: 1) cliente, 2) piezas (cada una se cobra por su
/// área: ancho × alto × precio del m²) y 3) resumen. El total queda siempre
/// visible abajo junto al botón de guardar.
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
  final TextEditingController _discCtrl = TextEditingController();

  /// Solicitud del cliente que atiende esta cotización, si viene de una.
  QuoteRequest? _request;

  @override
  void initState() {
    super.initState();
    final preset = widget.state.presetClientId;
    // Solo se preselecciona si el cliente existe.
    if (widget.state.clients.any((c) => c.id == preset)) _clientId = preset;
    _request = widget.state.takeQuoteRequest();
    final r = _request;
    if (r == null) return;
    _clientId = r.clientId;
    // Si la pidió del catálogo, la pieza ya va con sus medidas.
    final product = widget.state.products
        .where((p) => p.id == r.productId)
        .firstOrNull;
    if (product != null && r.width != null && r.height != null) {
      _items.add(
        QuoteItem.byArea(
          productId: product.id,
          width: r.width!,
          height: r.height!,
          depth: product.depth,
          qty: r.qty,
          pricePerM2: product.price,
        ),
      );
    }
  }

  @override
  void dispose() {
    _discCtrl.dispose();
    super.dispose();
  }

  Client? get _client =>
      widget.state.clients.where((c) => c.id == _clientId).firstOrNull;

  Product? _productOf(QuoteItem item) =>
      widget.state.products.where((p) => p.id == item.productId).firstOrNull;

  double get _subtotal => _items.fold(0.0, (acc, it) => acc + it.subtotal);
  double get _discountAmount => _subtotal * _discount / 100.0;
  double get _total => _subtotal - _discountAmount;
  double get _totalArea => _items.fold(0.0, (acc, it) => acc + it.totalArea);
  int get _pieceCount => _items.fold(0, (acc, it) => acc + it.qty);

  // ---------------------------------------------------------------- Cliente

  /// Lista de clientes con buscador; también permite crear uno nuevo.
  void _pickClient() {
    var search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = search.trim().toLowerCase();
          final clients = widget.state.clients
              .where(
                (c) =>
                    q.isEmpty ||
                    c.name.toLowerCase().contains(q) ||
                    c.phone.contains(q),
              )
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * .75,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SheetHeader('Elegir cliente'),
                    const SizedBox(height: 6),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nombre o teléfono...',
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                      onChanged: (v) => setSheetState(() => search = v),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Nuevo cliente'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openNewClientSheet();
                      },
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: clients.isEmpty
                          ? ListView(
                              children: const [
                                EmptyState(
                                  icon: Icons.search_off,
                                  title: 'Ningún cliente coincide',
                                ),
                              ],
                            )
                          : ListView(
                              children: [
                                ListBox(
                                  children: [
                                    for (final c in clients)
                                      BoxRow(
                                        leading: AvatarWidget(
                                          name: c.name,
                                          size: 36,
                                        ),
                                        title: c.name,
                                        subtitle: c.phone,
                                        trailing: c.id == _clientId
                                            ? Icon(
                                                Icons.check,
                                                color: AppColors.blue,
                                              )
                                            : null,
                                        onTap: () {
                                          setState(() => _clientId = c.id);
                                          Navigator.pop(ctx);
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Alta rápida de cliente, con las mismas reglas que la pantalla Clientes.
  void _openNewClientSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    var showErrors = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final phoneError = PhoneInput.validate(phoneCtrl.text);
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHeader('Nuevo cliente'),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo *',
                    errorText: showErrors && nameCtrl.text.trim().isEmpty
                        ? 'Escribe el nombre del cliente'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: PhoneInput.formatters,
                  decoration: InputDecoration(
                    labelText: 'Teléfono (10 dígitos) *',
                    counterText: '${phoneCtrl.text.length}/10',
                    errorText: (showErrors || phoneCtrl.text.length == 10)
                        ? phoneError
                        : null,
                  ),
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: addressCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de la obra (opcional)',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final error = PhoneInput.validate(phoneCtrl.text);
                    if (nameCtrl.text.trim().isEmpty || error != null) {
                      setSheetState(() => showErrors = true);
                      showSheetMessage(
                        ctx,
                        error ?? 'Escribe el nombre del cliente',
                      );
                      return;
                    }
                    final newC = Client(
                      id: DateTime.now().millisecondsSinceEpoch,
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text,
                      address: addressCtrl.text.trim(),
                    );
                    widget.state.addClient(newC);
                    setState(() => _clientId = newC.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar y usar en la cotización'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------------- Piezas

  /// Abre la hoja de una pieza: nueva (sin [index]) o para editar.
  Future<void> _openPieceSheet({int? index}) async {
    if (widget.state.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero da de alta productos en el catálogo'),
        ),
      );
      return;
    }
    final result = await showModalBottomSheet<QuoteItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PieceSheet(
        products: widget.state.products,
        initial: index == null ? null : _items[index],
        showAdvice: widget.state.settings.ai,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
    });
  }

  void _duplicate(int index) {
    setState(() => _items.insert(index + 1, _items[index]));
  }

  void _remove(int index) {
    final removed = _items[index];
    setState(() => _items.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pieza quitada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => setState(
            () => _items.insert(index.clamp(0, _items.length), removed),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Guardar

  void _saveQuote() {
    final messenger = ScaffoldMessenger.of(context);
    if (_clientId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Paso 1: elige el cliente')),
      );
      return;
    }
    if (_items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Paso 2: agrega al menos una pieza')),
      );
      return;
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
    if (_request != null) {
      widget.state.linkRequestToQuote(_request!.id, newQuote.id);
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Cotización ${newQuote.folio} guardada')),
    );
    widget.onNavigate(AdminScreen.cotizaciones);
  }

  // ------------------------------------------------------------------ Vista

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sin avatar: tocarlo a media cotización perdería lo capturado.
      appBar: TopBar(title: 'Nueva cotización'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_request != null) ...[
            _requestCard(_request!),
            const SizedBox(height: 20),
          ],
          _stepHeader(1, 'Cliente', done: _client != null),
          _clientStep(),
          const SizedBox(height: 24),
          _stepHeader(
            2,
            'Piezas',
            done: _items.isNotEmpty,
            action: _items.isEmpty ? null : 'Agregar pieza',
            onAction: () => _openPieceSheet(),
          ),
          _piecesStep(),
          const SizedBox(height: 24),
          _stepHeader(3, 'Resumen', done: false),
          _summaryStep(),
        ],
      ),
      bottomNavigationBar: _totalBar(),
    );
  }

  /// Lo que pidió el cliente, a la vista mientras se arma la cotización.
  Widget _requestCard(QuoteRequest r) {
    final measures = requestMeasures(r);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOLICITUD DEL CLIENTE · ${r.type.toUpperCase()}',
            style: AppText.label(),
          ),
          const SizedBox(height: 6),
          Text(
            r.description,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          if (measures != null || r.wantsVisit) ...[
            const SizedBox(height: 6),
            Text(
              [
                ?measures,
                if (r.wantsVisit) 'Pide visita para medir',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          if (r.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            RequestPhotos(
              photos: r.photos,
              title: 'Solicitud de ${r.type.toLowerCase()}',
            ),
          ],
        ],
      ),
    );
  }

  /// Encabezado numerado de cada paso; el número se vuelve palomita al
  /// completarlo.
  Widget _stepHeader(
    int number,
    String title, {
    required bool done,
    String? action,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? AppColors.done : AppColors.navy,
            shape: BoxShape.circle,
          ),
          child: done
              ? Icon(Icons.check, size: 15, color: AppColors.onInk)
              : Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onInk,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SectionHeader(
            title,
            action: action,
            actionIcon: Icons.add,
            onAction: onAction,
          ),
        ),
      ],
    );
  }

  Widget _clientStep() {
    final client = _client;
    if (client == null) {
      return AppCard(
        onTap: _pickClient,
        child: Row(
          children: [
            const IconBadge(Icons.person_search_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¿Para quién es la cotización?',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ),
            Text(
              'Elegir',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.blue,
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: BoxRow(
        leading: AvatarWidget(name: client.name, size: 40),
        title: client.name,
        subtitle: [
          client.phone,
          if (client.address.isNotEmpty) client.address,
        ].join(' · '),
        trailing: Text(
          'Cambiar',
          style: TextStyle(fontSize: 13, color: AppColors.blue),
        ),
        onTap: _pickClient,
      ),
    );
  }

  Widget _piecesStep() {
    final ai = widget.state.settings.ai;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isEmpty)
          AppCard(
            child: Column(
              children: [
                Text(
                  'Agrega cada ventana, puerta o cancel con sus medidas. '
                  'El precio se calcula por m².',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar pieza'),
                  onPressed: () => _openPieceSheet(),
                ),
              ],
            ),
          )
        else
          ListBox(
            children: [for (int i = 0; i < _items.length; i++) _pieceRow(i)],
          ),
        if (ai) ...[
          const SizedBox(height: 10),
          ListBox(
            children: [
              BoxRow(
                leading: const IconBadge(Icons.straighten),
                title: 'Asesor de cotización',
                subtitle: 'Consulta sobre vidrios, medidas o materiales',
                trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AiChatSheet(
                    currentItems: _items,
                    products: widget.state.products,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Renglón de una pieza: tocarlo la edita; el menú la duplica o la quita.
  Widget _pieceRow(int index) {
    final item = _items[index];
    final name = _productOf(item)?.name ?? 'Pieza';
    final hasWarning =
        widget.state.settings.ai &&
        PieceAdvisor.advise(
          productName: name,
          widthCm: item.width,
          heightCm: item.height,
        ).any((a) => a.level == AdviceLevel.warning);

    return BoxRow(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: Text(
          '${item.qty}x',
          style: AppText.mono(fontSize: 12, color: AppColors.navy),
        ),
      ),
      title: item.note.isEmpty ? name : '$name · ${item.note}',
      subtitle: hasWarning
          ? '${AppState.itemDetail(item)}\nRevisa la sugerencia del asesor'
          : AppState.itemDetail(item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(AppState.formatMXN(item.subtotal)),
          PopupMenuButton<String>(
            tooltip: 'Opciones de la pieza',
            icon: Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
            onSelected: (v) {
              if (v == 'edit') _openPieceSheet(index: index);
              if (v == 'dup') _duplicate(index);
              if (v == 'del') _remove(index);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              const PopupMenuItem(value: 'dup', child: Text('Duplicar')),
              PopupMenuItem(
                value: 'del',
                child: Text(
                  'Quitar',
                  style: TextStyle(color: AppColors.cancelled),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _openPieceSheet(index: index),
    );
  }

  Widget _summaryStep() {
    final discountLabel = _discount == _discount.roundToDouble()
        ? _discount.toStringAsFixed(0)
        : _discount.toStringAsFixed(2);
    return AppCard(
      child: Column(
        children: [
          SummaryLine(
            'Piezas',
            '$_pieceCount · ${AppState.formatArea(_totalArea)}',
          ),
          SummaryLine('Subtotal', AppState.formatMXN(_subtotal)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Descuento',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
              SizedBox(
                width: 84,
                child: TextField(
                  controller: _discCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,3}(\.\d{0,2})?$'),
                    ),
                  ],
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '0',
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
          if (_discount > 0)
            SummaryLine(
              'Descuento ($discountLabel%)',
              '- ${AppState.formatMXN(_discountAmount)}',
              color: AppColors.cancelled,
            ),
          Divider(height: 20, color: AppColors.divider),
          SummaryLine('Total', AppState.formatMXN(_total), strong: true),
        ],
      ),
    );
  }

  /// Barra fija inferior: total y botón para guardar.
  Widget _totalBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  MoneyText(AppState.formatMXN(_total), fontSize: 20),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onPressed: _saveQuote,
              child: const Text('Guardar cotización'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja para agregar o editar una pieza: producto, medidas, cantidad y nota,
/// con el cálculo del precio por m² a la vista.
class _PieceSheet extends StatefulWidget {
  final List<Product> products;
  final QuoteItem? initial;
  final bool showAdvice;

  const _PieceSheet({
    required this.products,
    required this.initial,
    required this.showAdvice,
  });

  @override
  State<_PieceSheet> createState() => _PieceSheetState();
}

class _PieceSheetState extends State<_PieceSheet> {
  Product? _product;
  late final TextEditingController _width;
  late final TextEditingController _height;
  late final TextEditingController _qty;
  late final TextEditingController _note;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    _product = it == null
        ? null
        : widget.products.where((p) => p.id == it.productId).firstOrNull;
    _width = TextEditingController(text: MeasureInput.format(it?.width));
    _height = TextEditingController(text: MeasureInput.format(it?.height));
    _qty = TextEditingController(text: '${it?.qty ?? 1}');
    _note = TextEditingController(text: it?.note ?? '');
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _w => MeasureInput.parse(_width.text);
  double? get _h => MeasureInput.parse(_height.text);
  int get _q => int.tryParse(_qty.text) ?? 0;

  /// Precio del m²: el del producto; al editar una pieza sin cambiar de
  /// producto se conserva el que tenía.
  double get _pricePerM2 {
    final it = widget.initial;
    if (it != null && it.productId == _product?.id && it.pricePerM2 != null) {
      return it.pricePerM2!;
    }
    return _product?.price ?? 0;
  }

  void _selectProduct(Product? p) {
    setState(() {
      _product = p;
      // Si aún no hay medidas, se proponen las de referencia del producto.
      if (p != null && _width.text.isEmpty && _height.text.isEmpty) {
        _width.text = MeasureInput.format(p.width);
        _height.text = MeasureInput.format(p.height);
      }
    });
  }

  void _measureWithCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasureScreen(
          onConfirm: (w, h, _) => setState(() {
            _width.text = MeasureInput.format(w);
            _height.text = MeasureInput.format(h);
          }),
        ),
      ),
    );
  }

  void _submit() {
    final product = _product, w = _w, h = _h;
    if (product == null || w == null || h == null || _q < 1) {
      setState(() => _showErrors = true);
      showSheetMessage(
        context,
        product == null ? 'Elige el producto' : 'Revisa ancho, alto y cantidad',
      );
      return;
    }
    final keepsProduct = widget.initial?.productId == product.id;
    Navigator.pop(
      context,
      QuoteItem.byArea(
        productId: product.id,
        width: w,
        height: h,
        depth: keepsProduct ? widget.initial?.depth : product.depth,
        qty: _q,
        pricePerM2: _pricePerM2,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _w, h = _h;
    final ready = _product != null && w != null && h != null && _q >= 1;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              widget.initial == null ? 'Agregar pieza' : 'Editar pieza',
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _product?.id,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Producto *',
                errorText: _showErrors && _product == null
                    ? 'Elige el producto'
                    : null,
              ),
              items: [
                for (final p in widget.products)
                  DropdownMenuItem(
                    value: p.id,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: AppImage(p.img, width: 32, height: 26),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${AppState.formatMXN(p.price)}/m²',
                          style: AppText.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (id) => _selectProduct(
                widget.products.where((p) => p.id == id).firstOrNull,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MeasureField(
                    controller: _width,
                    label: 'Ancho',
                    errorText: (_showErrors || _width.text.isNotEmpty)
                        ? MeasureInput.validate(_width.text)
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MeasureField(
                    controller: _height,
                    label: 'Alto',
                    errorText: (_showErrors || _height.text.isNotEmpty)
                        ? MeasureInput.validate(_height.text)
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Medir con cámara'),
                onPressed: _measureWithCamera,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      errorText: _showErrors && _q < 1 ? 'Mín. 1' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      hintText: 'Ej. ventana de la cocina',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (ready) _calculation(w, h) else _calculationHint(),
            if (widget.showAdvice && ready) ..._advice(w, h),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _submit,
              child: Text(
                widget.initial == null
                    ? 'Agregar a la cotización'
                    : 'Guardar cambios',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Desglose en vivo: área, precio del m², precio por pieza e importe.
  Widget _calculation(double w, double h) {
    final area = QuoteItem.areaOf(w, h);
    final unit = QuoteItem.priceFor(w, h, _pricePerM2);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        children: [
          SummaryLine(
            '${(w / 100).toStringAsFixed(2)} × ${(h / 100).toStringAsFixed(2)} m',
            AppState.formatArea(area),
          ),
          SummaryLine('Precio del m²', '× ${AppState.formatMXN(_pricePerM2)}'),
          SummaryLine('Precio por pieza', AppState.formatMXN(unit)),
          if (_q > 1) SummaryLine('Cantidad', '× $_q'),
          Divider(height: 14, color: AppColors.divider),
          SummaryLine('Importe', AppState.formatMXN(unit * _q), strong: true),
        ],
      ),
    );
  }

  Widget _calculationHint() {
    return Text(
      'Elige el producto y escribe ancho y alto para ver el precio '
      '(ancho × alto × precio del m²).',
      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
    );
  }

  List<Widget> _advice(double w, double h) {
    final advice = PieceAdvisor.advise(
      productName: _product?.name ?? '',
      widthCm: w,
      heightCm: h,
    );
    return [
      for (final a in advice)
        Padding(
          padding: const EdgeInsets.only(top: 8),
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
