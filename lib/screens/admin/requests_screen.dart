import 'package:flutter/material.dart';

import '../../core/dates.dart';

import '../../core/app_routes.dart';
import '../../core/constants.dart';
import '../../core/external_links.dart';
import '../../core/theme.dart';
import '../../core/input_rules.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/request_widgets.dart';
import '../../widgets/server_refresh.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';

/// Solicitudes de cotización de los clientes: el taller las revisa, las
/// acepta o rechaza y arma la cotización con su información.
class RequestsScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const RequestsScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  static const _filters = ['Por atender', 'Cotizadas', 'Rechazadas', 'Todas'];
  String _filter = _filters.first;

  bool _matches(QuoteRequest r) => switch (_filter) {
    'Por atender' => r.isOpen,
    'Cotizadas' => r.status == QuoteRequest.quoted,
    'Rechazadas' => r.status == QuoteRequest.rejected,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final requests = state.requests.where(_matches).toList();

    return Scaffold(
      appBar: TopBar(title: 'Solicitudes', showLogo: true),
      body: Column(
        children: [
          FilterBar(
            options: _filters,
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refreshFromServer(context, state),
              child: requests.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 40),
                      children: [
                        EmptyState(
                          icon: Icons.inbox_outlined,
                          title: _filter == _filters.first
                              ? 'No hay solicitudes por atender'
                              : 'No hay solicitudes con este filtro',
                          message:
                              'Aquí llegan las cotizaciones que piden tus '
                              'clientes desde la app.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: requests.length,
                      itemBuilder: (context, i) =>
                          _requestCard(context, requests[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(BuildContext context, QuoteRequest r) {
    final client = widget.state.clientById(r.clientId);
    final details = [
      ?requestMeasures(r),
      if (r.photos.isNotEmpty)
        AppState.plural(r.photos.length, 'foto', 'fotos'),
      if (r.wantsVisit) 'Pide visita',
    ];
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => showAdminRequest(
        context,
        widget.state,
        r,
        onNavigate: widget.onNavigate,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  client?.name ?? 'Cliente',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              RequestStatusBadge(r),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${r.type} · ${displayDate(r.date)}',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            r.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              details.join(' · '),
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Detalle de una solicitud para el taller, con las acciones que le tocan:
/// aceptar, rechazar (con motivo) y hacer la cotización.
void showAdminRequest(
  BuildContext context,
  AppState state,
  QuoteRequest request, {
  required Function(int) onNavigate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      // Se redibuja al aceptar o rechazar sin cerrar la hoja.
      listenable: state,
      builder: (ctx, _) {
        final r =
            state.requests.where((x) => x.id == request.id).firstOrNull ??
            request;
        final client = state.clientById(r.clientId);
        final product = state.productById(r.productId);
        final measures = requestMeasures(r);
        final quote = state.quoteById(r.quoteId);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        client?.name ?? 'Cliente',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    RequestStatusBadge(r),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.type} · ${displayDate(r.date)}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                if (client != null && client.phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        PhoneInput.display(client.phone),
                        style: AppText.mono(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('WhatsApp'),
                        onPressed: () => ExternalLinks.whatsApp(
                          context,
                          client.phone,
                          message:
                              'Hola ${client.name}, sobre tu solicitud de '
                              '${r.type.toLowerCase()}: ',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  r.description,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                if (product != null || measures != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    [?product?.name, ?measures].join(' · '),
                    style: AppText.mono(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (r.wantsVisit) ...[
                  const SizedBox(height: 8),
                  Text(
                    'El cliente pide que vayan a medir.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pendingText,
                    ),
                  ),
                ],
                if (r.status == QuoteRequest.rejected) ...[
                  const SizedBox(height: 8),
                  Text(
                    r.reason.isEmpty
                        ? 'Rechazada sin motivo.'
                        : 'Motivo del rechazo: ${r.reason}',
                    style: TextStyle(fontSize: 13, color: AppColors.cancelled),
                  ),
                ],
                if (r.photos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  RequestPhotos(
                    photos: r.photos,
                    title: 'Solicitud de ${client?.name ?? 'cliente'}',
                  ),
                ],
                const SizedBox(height: 20),
                if (r.isOpen) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('Hacer cotización'),
                    onPressed: () {
                      state.startQuoteFromRequest(r.id);
                      Navigator.pop(ctx);
                      onNavigate(AdminScreen.nuevaCotizacion);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _reject(ctx, state, r),
                          child: const Text('Rechazar'),
                        ),
                      ),
                      if (r.isNew) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              state.acceptRequest(r.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Solicitud aceptada. El cliente recibirá el aviso.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Aceptar'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (quote != null)
                  OutlinedButton(
                    onPressed: () {
                      state.setSelectedQuoteId(quote.id);
                      Navigator.pop(ctx);
                      onNavigate(AdminScreen.detalleCotizacion);
                    },
                    child: Text('Ver cotización ${quote.folio}'),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _reject(
  BuildContext context,
  AppState state,
  QuoteRequest r,
) async {
  var reason = '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Rechazar la solicitud?'),
      content: TextField(
        onChanged: (v) => reason = v,
        maxLines: 3,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Motivo (lo verá el cliente)',
          hintText: 'Ej. no trabajamos ese tipo de pieza',
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Rechazar'),
        ),
      ],
    ),
  );
  if (ok == true) state.rejectRequest(r.id, reason);
}
