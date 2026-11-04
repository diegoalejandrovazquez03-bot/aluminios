import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../screens/client/client_order_detail_screen.dart';
import '../state/app_state.dart';

/// Campana de avisos del cliente: muestra cuántos hay sin leer y, al
/// tocarla, la lista (y los marca como leídos). Un aviso de un pedido abre
/// ese pedido.
class NoticesButton extends StatelessWidget {
  final AppState state;

  const NoticesButton({super.key, required this.state});

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
                    'No tienes avisos. Aquí verás los cambios de tus pedidos, abonos y visitas.',
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
                      final quote = n.quoteId == null
                          ? null
                          : state.quotes
                                .where((q) => q.id == n.quoteId)
                                .firstOrNull;
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
                        trailing: quote == null
                            ? null
                            : Icon(
                                Icons.chevron_right,
                                color: AppColors.textMuted,
                              ),
                        onTap: quote == null
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClientOrderDetailScreen(
                                      quote: quote,
                                      state: state,
                                    ),
                                  ),
                                );
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
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · $hh:$mm';
  }
}
