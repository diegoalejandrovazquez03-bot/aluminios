import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/external_links.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';

class ClientsScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const ClientsScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _search = '';

  void _openClientFile(Client client) {
    final clientQuotes = widget.state.quotes
        .where((quote) => quote.clientId == client.id)
        .toList();
    final clientWorks = widget.state.works
        .where((work) => work.clientId == client.id)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .7,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                client.name,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(client.phone),
              const SizedBox(height: 20),
              const Text(
                'Cotizaciones',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              if (clientQuotes.isEmpty)
                const ListTile(title: Text('Aún no tiene cotizaciones')),
              for (final quote in clientQuotes)
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('${quote.folio} · ${quote.status.label}'),
                  subtitle: Text(
                    '${quote.date} · ${AppState.formatMXN(quote.total)}',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.state.setSelectedQuoteId(quote.id);
                    widget.onNavigate(9);
                  },
                ),
              const SizedBox(height: 12),
              const Text(
                'Trabajos asociados',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              if (clientWorks.isEmpty)
                const ListTile(title: Text('Aún no tiene trabajos asociados')),
              for (final work in clientWorks)
                ListTile(
                  leading: const Icon(Icons.handyman),
                  title: Text(work.title),
                  subtitle: Text(
                    [
                      if (work.width != null) 'Ancho ${work.width} cm',
                      if (work.height != null) 'Alto ${work.height} cm',
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _callPhone(String phone) => ExternalLinks.call(context, phone);

  void _openWhatsApp(String phone, String name) => ExternalLinks.whatsApp(
    context,
    phone,
    message:
        'Hola $name, un gusto saludarte de parte de ${widget.state.settings.bizName}.',
  );

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
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cliente guardado')),
                );
              },
              child: const Text('Guardar Cliente'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final clients = state.clients.where((c) {
      final q = _search.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    return Scaffold(
      appBar: TopBar(
        title: 'Clientes',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(8),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o teléfono...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),
          Expanded(
            child: clients.isEmpty
                ? Center(
                    child: Text(
                      'No hay clientes registrados',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: clients.length,
                    itemBuilder: (context, i) {
                      final c = clients[i];
                      final clientQuotes = state.quotes
                          .where((q) => q.clientId == c.id)
                          .toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onTap: () => _openClientFile(c),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: AvatarWidget(name: c.name, size: 42),
                            title: Text(
                              c.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark ? Colors.white : AppColors.navy,
                              ),
                            ),
                            subtitle: Text(
                              '${c.phone}  •  ${clientQuotes.length} pedido(s)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.phone_outlined,
                                    size: 20,
                                    color: AppColors.navy,
                                  ),
                                  onPressed: () => _callPhone(c.phone),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.chat_bubble_outline,
                                    size: 20,
                                    color: AppColors.done,
                                  ),
                                  onPressed: () =>
                                      _openWhatsApp(c.phone, c.name),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.note_add_outlined,
                                    size: 20,
                                    color: AppColors.blue,
                                  ),
                                  tooltip: 'Nueva cotización',
                                  onPressed: () {
                                    state.setPresetClientId(c.id);
                                    widget.onNavigate(2); // Go to new quote
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onInk,
        onPressed: _openNewClientDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
