import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/server_refresh.dart';
import '../../widgets/top_bar.dart';

class QuotesScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const QuotesScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  String _filter = 'Todas';
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Minúsculas y sin acentos: "Martínez" se encuentra escribiendo "martinez".
  static String _norm(String text) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    var out = text.toLowerCase().trim();
    for (int i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  /// Coincide por folio (con o sin #), nombre o teléfono del cliente.
  bool _matchesSearch(Quote q) {
    final term = _norm(_search).replaceAll('#', '');
    if (term.isEmpty) return true;
    final client = widget.state.clients
        .where((c) => c.id == q.clientId)
        .firstOrNull;
    final digits = term.replaceAll(RegExp(r'\D'), '');
    return _norm(q.folio).replaceAll('#', '').contains(term) ||
        _norm(client?.name ?? '').contains(term) ||
        (digits.isNotEmpty &&
            digits.length == term.replaceAll(' ', '').length &&
            (client?.phone ?? '')
                .replaceAll(RegExp(r'\D'), '')
                .contains(digits));
  }

  void _showTrash() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // ListenableBuilder: la hoja se redibuja al restaurar o eliminar.
      builder: (ctx) => ListenableBuilder(
        listenable: widget.state,
        builder: (ctx, _) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Papelera',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.state.trash.where((entry) => entry['type'] == 'cotizacion').length} cotización(es)',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: widget.state.trash.isEmpty
                      ? const Center(child: Text('La papelera está vacía'))
                      : ListView.builder(
                          itemCount: widget.state.trash.length,
                          itemBuilder: (context, index) {
                            final entry = widget.state.trash[index];
                            final raw = entry['data'];
                            // Un registro incompleto no debe tumbar la papelera.
                            final data = raw is Map
                                ? Map<String, dynamic>.from(raw)
                                : <String, dynamic>{};
                            final title = switch (entry['type']) {
                              'cotizacion' => 'Cotización ${data['folio']}',
                              'trabajo' => 'Trabajo ${data['title']}',
                              _ => 'Pago ${data['method']}',
                            };
                            return ListTile(
                              title: Text(title),
                              subtitle: Text(
                                'Cancelado: ${entry['archivedAt']}',
                              ),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    tooltip: 'Restaurar',
                                    icon: const Icon(Icons.restore),
                                    onPressed: () {
                                      widget.state.restoreTrashEntry(entry);
                                      showSheetMessage(
                                        ctx,
                                        'Restaurado: $title',
                                      );
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar definitivamente',
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      widget.state.permanentlyDeleteTrashEntry(
                                        entry,
                                      );
                                      showSheetMessage(
                                        ctx,
                                        'Eliminado: $title',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _filter = widget.state.quoteFilter;
  }

  List<Quote> _getFilteredQuotes() {
    // Copia estable: la lista no cambia de tamaño mientras se dibuja aunque
    // en ese momento se cancele o restaure una cotización.
    if (_filter == 'Todas') return List.of(widget.state.quotes);
    if (_filter == 'Pendiente') {
      return widget.state.quotes
          .where((q) => q.status == QuoteStatus.pendiente)
          .toList();
    }
    if (_filter == 'Cancelada') {
      return widget.state.quotes
          .where((q) => q.status == QuoteStatus.cancelada)
          .toList();
    }
    // 'Aprobada' encompasses Aprobada, En proceso, Completado, Entregado
    return widget.state.quotes
        .where(
          (q) =>
              q.status != QuoteStatus.pendiente &&
              q.status != QuoteStatus.cancelada,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quotes = _getFilteredQuotes().where(_matchesSearch).toList();

    return Scaffold(
      appBar: TopBar(
        title: 'Cotizaciones',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(AdminScreen.perfil),
        actions: [
          IconButton(
            tooltip: 'Papelera',
            onPressed: _showTrash,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por folio, cliente o teléfono...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),

          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: ['Todas', 'Pendiente', 'Aprobada', 'Cancelada'].map((
                f,
              ) {
                final isSel = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSel,
                    selectedColor: AppColors.navy,
                    labelStyle: TextStyle(
                      color: isSel ? AppColors.onInk : AppColors.navy,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: isDark
                        ? AppColors.surfaceDark
                        : Colors.white,
                    side: BorderSide(
                      color: isSel ? Colors.transparent : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onSelected: (val) {
                      setState(() => _filter = f);
                      widget.state.setQuoteFilter(f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Quotes List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refreshFromServer(context, widget.state),
              child: quotes.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 120),
                      children: [
                        Center(
                          child: Text(
                            _search.trim().isEmpty
                                ? 'No hay cotizaciones con este filtro'
                                : 'Ninguna cotización coincide con "${_search.trim()}"',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: quotes.length,
                      itemBuilder: (context, i) {
                        final q = quotes[i];
                        final client = widget.state.clients
                            .where((c) => c.id == q.clientId)
                            .firstOrNull;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                widget.state.setSelectedQuoteId(q.id);
                                widget.onNavigate(
                                  AdminScreen.detalleCotizacion,
                                ); // DetallePedido
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.lightBlue,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.receipt_long,
                                                color: AppColors.navy,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              q.folio,
                                              style: TextStyle(
                                                fontFamily: AppText.monoFamily,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppColors.navy,
                                              ),
                                            ),
                                          ],
                                        ),
                                        StatusBadge(status: q.status),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      client?.name ?? 'Cliente desconocido',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${q.date}  •  ${q.items.length} pieza(s)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppState.formatMXN(q.total),
                                          style: TextStyle(
                                            fontFamily: AppText.monoFamily,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.navy,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onInk,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nueva cotización',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () => widget.onNavigate(AdminScreen.nuevaCotizacion),
      ),
    );
  }
}
