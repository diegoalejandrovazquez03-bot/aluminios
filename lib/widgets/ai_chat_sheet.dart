import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/models.dart';

class AiChatSheet extends StatefulWidget {
  final List<QuoteItem> currentItems;
  final List<Product> products;

  const AiChatSheet({
    super.key,
    required this.currentItems,
    required this.products,
  });

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  final List<Map<String, String>> _messages = [
    {
      'from': 'ai',
      'text': 'Consulta sobre tipos de cristal, perfiles de aluminio, márgenes o descuentos sugeridos.',
    },
  ];
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;

  String _generateReply(String input) {
    final t = input.toLowerCase();

    double maxArea = 0.0;
    double totalWeightedMargin = 0.0;
    double totalAmount = 0.0;

    for (final it in widget.currentItems) {
      final area = (it.width * it.height) / 10000.0;
      if (area > maxArea) maxArea = area;

      final prod = widget.products
          .where((p) => p.id == it.productId)
          .firstOrNull;
      final margin = prod?.margin ?? 25.0;
      final lineTotal = it.qty * it.unitPrice;
      totalWeightedMargin += margin * lineTotal;
      totalAmount += lineTotal;
    }

    final avgMargin = totalAmount > 0
        ? totalWeightedMargin / totalAmount
        : 25.0;

    if (t.contains('cristal') || t.contains('vidrio')) {
      if (maxArea > 1.5) {
        return 'Tu pieza más grande mide ${maxArea.toStringAsFixed(2)} m². Para más de 1.5 m² te conviene cristal templado de 8 mm por seguridad y rigidez estructural.';
      }
      return 'Para piezas de hasta 1.5 m² el cristal de 6 mm es suficiente y mantiene un excelente margen. Si es para cancel de baño o puerta de alto tráfico, usa siempre templado.';
    }

    if (t.contains('margen') || t.contains('ganancia')) {
      if (widget.currentItems.isEmpty) {
        return 'Aún no has agregado productos. Los perfiles con mayor margen en tu catálogo son el aluminio anodizado y la Ventana Pro-Max (hasta 38%).';
      }
      return 'El margen promedio ponderado de esta cotización es de ${avgMargin.toStringAsFixed(1)}%. ${avgMargin < 20 ? 'Es un margen bajo: te sugiero no otorgar descuentos adicionales.' : 'Es un margen muy saludable.'}';
    }

    if (t.contains('descuento') || t.contains('precio')) {
      if (widget.currentItems.isEmpty) {
        return 'Agrega primero productos a la cotización y te recomendaré un descuento que proteja tu rentabilidad.';
      }
      final maxD = (avgMargin - 15).clamp(0, 30).toInt();
      return 'Con tu margen actual de ${avgMargin.toStringAsFixed(1)}%, puedes ofrecer hasta un $maxD% de descuento manteniendo al menos un 15% de utilidad neta.';
    }

    if (t.contains('aluminio') ||
        t.contains('material') ||
        t.contains('perfil')) {
      return 'Guía de materiales:\n• Natural: Económico y versátil.\n• Blanco: Excelente acabado estético para interiores residenciales.\n• Anodizado: Máxima resistencia a salinidad y humedad (ideal para exteriores y costas).';
    }

    if (t.contains('medida') || t.contains('dimension')) {
      return 'Medidas estándar recomendadas:\n• Ventana corrediza: 120 × 100 cm\n• Puerta de aluminio: 90 × 210 cm\n• Cancel de baño: 80 × 190 cm\nVerifica siempre plomo y descuadre en obra.';
    }

    return 'Puedo asesorarte en selección de vidrios, espesores, resistencia de perfiles de aluminio y cálculo de márgenes. ¿Qué duda tienes sobre esta cotización?';
  }

  void _send(String text) {
    if (text.trim().isEmpty || _isTyping) return;
    _controller.clear();
    setState(() {
      _messages.add({'from': 'me', 'text': text.trim()});
      _isTyping = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add({'from': 'ai', 'text': _generateReply(text)});
        _isTyping = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.straighten,
                    color: AppColors.navy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asesor de cotización',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Optimización de perfiles, vidrio y margen',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length && _isTyping) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Escribiendo respuesta...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }

                final m = _messages[i];
                final isMe = m['from'] == 'me';

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.navy
                          : (isDark
                                ? AppColors.borderDark
                                : AppColors.lightBlue),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m['text']!,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : (isDark ? Colors.white : AppColors.textDark),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick prompt chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _chip('¿Qué vidrio me conviene?'),
                _chip('¿Cuál es mi margen?'),
                _chip('¿Cuánto descuento puedo dar?'),
                _chip('Tipos de aluminio'),
              ],
            ),
          ),

          // Input Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre materiales o precios...',
                        fillColor: isDark
                            ? AppColors.bgDark
                            : AppColors.lightBlue,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: AppColors.onInk,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: () => _send(_controller.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.lightBlue,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        onPressed: () => _send(label),
      ),
    );
  }
}
