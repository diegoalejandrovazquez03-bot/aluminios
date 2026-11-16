import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/constants.dart';
import '../../core/input_rules.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/measure_field.dart';
import '../../widgets/app_image.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';

import 'measure_screen.dart';

class ProductsScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const ProductsScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _search = '';
  String _materialFilter = 'Todos';
  final String _sort = 'nombre'; // 'nombre' | 'precio-asc' | 'precio-desc'

  List<Product> _getFilteredProducts() {
    var list = widget.state.products.where((p) {
      final matchQuery =
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.material.toLowerCase().contains(_search.toLowerCase());
      final matchMaterial =
          _materialFilter == 'Todos' || p.material == _materialFilter;
      return matchQuery && matchMaterial;
    }).toList();

    if (_sort == 'precio-asc') {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sort == 'precio-desc') {
      list.sort((a, b) => b.price.compareTo(a.price));
    } else {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    return list;
  }

  void _openProductForm([Product? product]) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final matCtrl = TextEditingController(text: product?.material ?? '');
    // Producto nuevo: se propone el precio por m² del perfil del taller.
    final priceCtrl = TextEditingController(
      text: MoneyInput.format(
        product?.price ?? widget.state.settings.defaultPricePerM2,
      ),
    );
    final wCtrl = TextEditingController(
      text: MeasureInput.format(product?.width),
    );
    final hCtrl = TextEditingController(
      text: MeasureInput.format(product?.height),
    );
    final dCtrl = TextEditingController(
      text: MeasureInput.format(product?.depth),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetHeader(
                    product == null ? 'Crear producto' : 'Editar producto',
                  ),
                  const SizedBox(height: 6),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto *',
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: matCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Material / Perfil *',
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: priceCtrl,
                    keyboardType: MoneyInput.keyboard,
                    inputFormatters: MoneyInput.formatters,
                    decoration: const InputDecoration(
                      labelText: 'Precio por m² *',
                      prefixText: '\$ ',
                      suffixText: '/ m²',
                      helperText: 'Cada pieza se cobra por su área: ancho × alto × precio del m².',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Medidas de referencia (opcional)',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),

                  // Dimensions row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: MeasureField(controller: wCtrl, label: 'Ancho'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MeasureField(controller: hCtrl, label: 'Alto'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MeasureField(controller: dCtrl, label: 'Fondo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Button to measure with camera
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: BorderSide(color: AppColors.navy),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text(
                      'Medir con cámara',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MeasureScreen(
                            onConfirm: (w, h, d) {
                              setModalState(() {
                                wCtrl.text = MeasureInput.format(w);
                                hCtrl.text = MeasureInput.format(h);
                                if (d != null) {
                                  dCtrl.text = MeasureInput.format(d);
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty ||
                          matCtrl.text.trim().isEmpty) {
                        showSheetMessage(
                          ctx,
                          'Nombre y material son requeridos',
                        );
                        return;
                      }
                      final price = MoneyInput.parse(priceCtrl.text) ?? 0.0;
                      if (price <= 0) {
                        showSheetMessage(
                          ctx,
                          'Ingresa un precio por m² mayor a 0',
                        );
                        return;
                      }

                      // Medidas opcionales, pero si se escriben deben ser válidas.
                      for (final c in [wCtrl, hCtrl, dCtrl]) {
                        if (c.text.trim().isNotEmpty &&
                            MeasureInput.parse(c.text) == null) {
                          showSheetMessage(
                            ctx,
                            'Revisa las medidas: deben ser números mayores a 0 (máx. 1000 cm)',
                          );
                          return;
                        }
                      }
                      final w = MeasureInput.parse(wCtrl.text);
                      final h = MeasureInput.parse(hCtrl.text);
                      final d = MeasureInput.parse(dCtrl.text);

                      if (product == null) {
                        final newP = Product(
                          id: DateTime.now().millisecondsSinceEpoch,
                          name: nameCtrl.text.trim(),
                          material: matCtrl.text.trim(),
                          price: price,
                          margin: 25,
                          img: 'https://images.unsplash.com/photo-1710883734891-93709398496d?w=160&h=120&fit=crop&auto=format',
                          width: w,
                          height: h,
                          depth: d,
                        );
                        widget.state.addProduct(newP);
                      } else {
                        final updated = product.copyWith(
                          name: nameCtrl.text.trim(),
                          material: matCtrl.text.trim(),
                          price: price,
                          width: w,
                          height: h,
                          depth: d,
                        );
                        widget.state.updateProduct(updated);
                      }

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            product == null
                                ? 'Producto creado'
                                : 'Producto actualizado',
                          ),
                        ),
                      );
                    },
                    child: Text(
                      product == null
                          ? 'Guardar producto'
                          : 'Actualizar producto',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text('Se eliminará "${p.name}" del catálogo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cancelled,
            ),
            onPressed: () {
              widget.state.deleteProduct(p.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Producto eliminado')),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _getFilteredProducts();
    final materials = [
      'Todos',
      ...{...widget.state.products.map((p) => p.material)},
    ];

    return Scaffold(
      appBar: TopBar(
        title: 'Productos',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(AdminScreen.perfil),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: SectionHeader(
              'Precios por m²',
              action: 'Crear nuevo',
              actionIcon: Icons.add,
              onAction: () => _openProductForm(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar productos o materiales...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: PopupMenuButton<String>(
                  tooltip: 'Filtrar por material',
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: _materialFilter != 'Todos'
                        ? AppColors.blue
                        : AppColors.textMuted,
                  ),
                  onSelected: (val) => setState(() => _materialFilter = val),
                  itemBuilder: (ctx) => materials.map((m) {
                    return PopupMenuItem(
                      value: m,
                      child: Text(
                        m,
                        style: TextStyle(
                          fontWeight: m == _materialFilter
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: products.isEmpty
                ? ListView(
                    padding: const EdgeInsets.only(top: 40),
                    children: [
                      widget.state.products.isEmpty
                          ? EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'Aún no hay productos',
                              actionLabel: 'Crear producto',
                              onAction: () => _openProductForm(),
                            )
                          : const EmptyState(
                              icon: Icons.search_off,
                              title: 'No hay productos que coincidan',
                              message: 'Prueba con otro nombre o material.',
                            ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: products.length,
                    itemBuilder: (context, i) => _productCard(products[i]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de un producto: foto, nombre, material, precio y medidas, con
  /// menú para editar o eliminar.
  Widget _productCard(Product p) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      onTap: () => _openProductForm(p),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: SizedBox(
              width: 68,
              height: 60,
              child: AppImage(p.img, width: 68, height: 60),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  p.material,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoneyText('${AppState.formatMXN(p.price)} / m²'),

                    if (p.width != null && p.height != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${p.width!.round()}×${p.height!.round()} cm',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            icon: Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
            onSelected: (val) {
              if (val == 'edit') _openProductForm(p);
              if (val == 'del') _confirmDelete(p);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'del',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: AppColors.cancelled,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Eliminar',
                      style: TextStyle(color: AppColors.cancelled),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
