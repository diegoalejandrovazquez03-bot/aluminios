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
import '../../widgets/ui.dart';

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
                                    icon: Icon(
                                      Icons.delete_forever,
                                      color: AppColors.cancelled,
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
    // "Terminada" junta las que ya se fabricaron o entregaron.
    if (_filter == 'Terminada') {
      return widget.state.quotes
          .where(
            (q) =>
                q.status == QuoteStatus.completado ||
                q.status == QuoteStatus.entregado,
          )
          .toList();
    }
    final status = QuoteStatus.values
        .where((s) => s.label == _filter)
        .firstOrNull;
    if (status != null) {
      return widget.state.quotes.where((q) => q.status == status).toList();
    }
    return List.of(widget.state.quotes);
  }

  @override
  Widget build(BuildContext context) {
    final quotes = _getFilteredQuotes().where(_matchesSearch).toList();

    return Scaffold(
      appBar: TopBar(
        title: 'Cotizaciones',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(AdminScreen.perfil),
        actions: [
          TextButton.icon(
            onPressed: _showTrash,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Papelera'),
            style: TextButton.styleFrom(foregroundColor: AppColors.navy),
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

          FilterBar(
            options: const [
              'Todas',
              'Pendiente',
              'Aprobada',
              'En proceso',
              'Terminada',
              'Cancelada',
            ],
            selected: _filter,
            onSelected: (f) {
              setState(() => _filter = f);
              widget.state.setQuoteFilter(f);
            },
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refreshFromServer(context, widget.state),
              child: quotes.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 40),
                      children: [
                        _search.trim().isEmpty
                            ? EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'No hay cotizaciones con este filtro',
                                actionLabel: _filter == 'Todas'
                                    ? 'Crear cotización'
                                    : null,
                                onAction: () => widget.onNavigate(
                                  AdminScreen.nuevaCotizacion,
                                ),
                              )
                            : EmptyState(
                                icon: Icons.search_off,
                                title:
                                    'Ninguna cotización coincide con "${_search.trim()}"',
                                message:
                                    'Prueba con otro folio, nombre o teléfono.',
                              ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Espacio abajo para que el botón flotante no tape la última.
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      itemCount: quotes.length,
                      itemBuilder: (context, i) => _quoteCard(quotes[i]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text(
          'Nueva cotización',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () => widget.onNavigate(AdminScreen.nuevaCotizacion),
      ),
    );
  }

  /// Tarjeta de una cotización: folio y estado arriba; cliente, fecha,
  /// piezas y total abajo. Si tiene saldo, una barra muestra cuánto se pagó.
  Widget _quoteCard(Quote q) {
    final client = widget.state.clients
        .where((c) => c.id == q.clientId)
        .firstOrNull;
    final paid = widget.state.paidOf(q.id);
    final showProgress =
        q.status != QuoteStatus.pendiente &&
        q.status != QuoteStatus.cancelada &&
        q.total > 0;
    final progress = showProgress ? (paid / q.total).clamp(0.0, 1.0) : 0.0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () {
        widget.state.setSelectedQuoteId(q.id);
        widget.onNavigate(AdminScreen.detalleCotizacion);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  q.folio,
                  style: AppText.mono(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              StatusBadge(status: q.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client?.name ?? 'Cliente desconocido',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.state.itemsSummary(q)} · ${AppState.displayDate(q.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MoneyText(AppState.formatMXN(q.total), fontSize: 15),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.lightBlue,
                color: progress >= 1 ? AppColors.done : AppColors.blue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              progress >= 1
                  ? 'Liquidada'
                  : 'Pagado ${AppState.formatMXN(paid)} de ${AppState.formatMXN(q.total)}',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
