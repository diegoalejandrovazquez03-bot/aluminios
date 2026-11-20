import 'package:flutter/material.dart';

import '../core/dates.dart';

import '../core/app_routes.dart';
import '../core/constants.dart';
import '../screens/admin/requests_screen.dart';
import '../screens/client/client_order_detail_screen.dart';
import '../screens/client/client_request_screen.dart';
import '../state/app_state.dart';

/// Campana de avisos: muestra cuántos hay sin leer y, al tocarla, la lista
/// (y los marca como leídos). Un aviso de un pedido o de una solicitud la
/// abre.
class NoticesButton extends StatelessWidget {
  final AppState state;

  /// Navegación del taller (abre el detalle de la cotización); el cliente
  /// abre sus pedidos encima de la pantalla actual.
  final Function(int)? onNavigate;

  const NoticesButton({super.key, required this.state, this.onNavigate});

  /// Lo que abre un aviso, o null si no lleva a ningún lado.
  VoidCallback? _target(BuildContext context, int? quoteId, int? requestId) {
    final quote = state.quoteById(quoteId);
    final request = state.requests.where((r) => r.id == requestId).firstOrNull;
    if (quote != null) {
      if (state.isAdmin) {
        return () {
          state.setSelectedQuoteId(quote.id);
          onNavigate?.call(AdminScreen.detalleCotizacion);
        };
      }
      return () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientOrderDetailScreen(quote: quote, state: state),
        ),
      );
    }
    if (request != null) {
      if (state.isAdmin) {
        return () => showAdminRequest(
          context,
          state,
          request,
          onNavigate: onNavigate ?? (_) {},
        );
      }
      return () => showClientRequest(context, request);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final unread = state.unreadNotices;
    return IconButton(
      tooltip: unread == 0 ? 'Avisos' : 'Avisos ($unread sin leer)',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none),
      ),
      onPressed: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    final notices = state.notices; // Antes de marcarlos como leídos.
    state.markNoticesRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Avisos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (notices.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Text(
                    state.isAdmin
                        ? 'No tienes avisos. Aquí verás las solicitudes nuevas y las respuestas de tus clientes.'
                        : 'No tienes avisos. Aquí verás los cambios de tus pedidos, solicitudes, abonos y visitas.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: notices.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (_, i) {
                      final n = notices[i];
                      final open = _target(context, n.quoteId, n.requestId);
                      return ListTile(
                        leading: Icon(
                          n.read
                              ? Icons.notifications_none
                              : Icons.notifications_active_outlined,
                          color: n.read ? AppColors.textMuted : AppColors.blue,
                        ),
                        title: Text(
                          n.text,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: n.read
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        subtitle: Text(
                          _when(n.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: open == null
                            ? null
                            : Icon(
                                Icons.chevron_right,
                                color: AppColors.textMuted,
                              ),
                        onTap: open == null
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                open();
                              },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _when(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return dmyDateTime(d);
  }
}
