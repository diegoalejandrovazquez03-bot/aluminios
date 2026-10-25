import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/external_links.dart';
import '../core/quote_message_service.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';

/// Hoja para revisar y editar el mensaje de WhatsApp de una cotización antes
/// de enviarlo. Con el asesor activo lo redacta la IA del backend; si no está
/// disponible usa la plantilla.
class WhatsAppDraftSheet extends StatefulWidget {
  final AppState state;
  final Quote quote;
  final Client? client;
  final String phone;

  const WhatsAppDraftSheet({
    super.key,
    required this.state,
    required this.quote,
    required this.client,
    required this.phone,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState state,
    required Quote quote,
    required Client? client,
    required String phone,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => WhatsAppDraftSheet(
        state: state,
        quote: quote,
        client: client,
        phone: phone,
      ),
    );
  }

  @override
  State<WhatsAppDraftSheet> createState() => _WhatsAppDraftSheetState();
}

class _WhatsAppDraftSheetState extends State<WhatsAppDraftSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _fromAssistant = false;

  bool get _assistantEnabled => widget.state.settings.ai;

  @override
  void initState() {
    super.initState();
    _controller.text = QuoteMessageService.template(
      widget.state,
      widget.quote,
      widget.client,
    );
    if (_assistantEnabled) _draft();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _draft() async {
    setState(() => _loading = true);
    final text = await QuoteMessageService.draftWithAssistant(
      widget.state,
      widget.quote,
      widget.client,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _fromAssistant = text != null;
      if (text != null) _controller.text = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String status;
    if (_loading) {
      status = 'El asesor está redactando el mensaje…';
    } else if (_fromAssistant) {
      status = 'Redactado por el asesor. Revísalo antes de enviarlo.';
    } else if (_assistantEnabled) {
      status = 'El asesor no está disponible; se usó la plantilla.';
    } else {
      status = 'Mensaje con plantilla. Puedes editarlo.';
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mensaje para ${widget.client?.name ?? 'el cliente'}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: TextField(
              controller: _controller,
              enabled: !_loading,
              maxLines: null,
              minLines: 8,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_assistantEnabled) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _draft,
                    child: const Text('Redactar de nuevo'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          await ExternalLinks.whatsApp(
                            context,
                            widget.phone,
                            message: _controller.text.trim(),
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('Enviar por WhatsApp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Verifica montos y medidas: el mensaje se envía tal como aparece.',
            textAlign: TextAlign.center,
            style: AppText.label().copyWith(
              fontSize: 11,
              letterSpacing: 0,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
