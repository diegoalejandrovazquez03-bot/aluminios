import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/input_rules.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/measure_field.dart';
import '../../widgets/request_widgets.dart';

/// Formulario para pedir una cotización describiendo lo que se necesita
/// (no solo piezas del catálogo). El taller la recibe como solicitud nueva.
class ClientRequestScreen extends StatefulWidget {
  final AppState state;

  /// Para ir al catálogo si el cliente prefiere elegir una pieza de ahí.
  final VoidCallback? onOpenCatalog;

  const ClientRequestScreen({
    super.key,
    required this.state,
    this.onOpenCatalog,
  });

  @override
  State<ClientRequestScreen> createState() => _ClientRequestScreenState();
}

class _ClientRequestScreenState extends State<ClientRequestScreen> {
  static const _minDescription = 10;

  String _type = QuoteRequest.types.first;
  final _description = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  List<String> _photos = [];
  bool _wantsVisit = false;
  // Los errores aparecen hasta el primer intento de enviar.
  bool _tried = false;

  @override
  void dispose() {
    _description.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  String? get _descriptionError {
    final text = _description.text.trim();
    if (text.isEmpty) return 'Cuéntanos qué necesitas';
    if (text.length < _minDescription) return 'Agrega un poco más de detalle';
    return null;
  }

  /// Las medidas son opcionales, pero si se escribe una van las dos.
  String? _measureError(
    TextEditingController field,
    TextEditingController other,
  ) {
    if (field.text.trim().isEmpty) {
      return other.text.trim().isEmpty ? null : 'Falta esta medida';
    }
    return MeasureInput.validate(field.text);
  }

  void _send() {
    setState(() => _tried = true);
    if (_descriptionError != null ||
        _measureError(_width, _height) != null ||
        _measureError(_height, _width) != null) {
      return;
    }
    final state = widget.state;
    state.addRequest(
      QuoteRequest(
        id: DateTime.now().millisecondsSinceEpoch,
        clientId: state.session!.clientId,
        date: AppState.today(),
        type: _type,
        description: _description.text.trim(),
        width: MeasureInput.parse(_width.text),
        height: MeasureInput.parse(_height.text),
        photos: _photos,
        wantsVisit: _wantsVisit,
      ),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Solicitud enviada. Te avisaremos cuando el taller la revise.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar cotización')),
      // Formulario corto: se arma completo (no por partes como una lista).
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Describe lo que necesitas y el taller te enviará la cotización '
              'con precio.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            Text('¿QUÉ NECESITAS?', style: AppText.label()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in QuoteRequest.types)
                  ChoiceChip(
                    label: Text(type),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Descripción',
                hintText:
                    'Ej. ventana corrediza para la cocina, aluminio negro, '
                    'con mosquitero',
                alignLabelWithHint: true,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                errorText: _tried ? _descriptionError : null,
              ),
              onChanged: (_) {
                if (_tried) setState(() {});
              },
            ),
            const SizedBox(height: 12),

            Text('MEDIDAS APROXIMADAS (OPCIONAL)', style: AppText.label()),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MeasureField(
                    controller: _width,
                    label: 'Ancho',
                    errorText: _tried ? _measureError(_width, _height) : null,
                    onChanged: (_) {
                      if (_tried) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MeasureField(
                    controller: _height,
                    label: 'Alto',
                    errorText: _tried ? _measureError(_height, _width) : null,
                    onChanged: (_) {
                      if (_tried) setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('FOTOS DEL LUGAR (OPCIONAL)', style: AppText.label()),
            const SizedBox(height: 8),
            RequestPhotos(
              photos: _photos,
              title: 'Fotos de tu solicitud',
              onChanged: (photos) => setState(() => _photos = photos),
            ),
            const SizedBox(height: 12),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Quiero que vayan a medir'),
              subtitle: const Text(
                'El taller te contactará para acordar el día.',
              ),
              value: _wantsVisit,
              onChanged: (v) => setState(() => _wantsVisit = v),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _send,
              child: const Text('Enviar solicitud'),
            ),
            if (widget.onOpenCatalog != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenCatalog!();
                },
                child: const Text('Prefiero elegir una pieza del catálogo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Abre el formulario de solicitud; desde él se puede ir al catálogo.
void openRequestForm(
  BuildContext context,
  AppState state, {
  VoidCallback? onOpenCatalog,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ClientRequestScreen(state: state, onOpenCatalog: onOpenCatalog),
    ),
  );
}

/// Detalle de una solicitud para el cliente: lo que pidió y qué pasó.
void showClientRequest(BuildContext context, QuoteRequest r) {
  final measures = requestMeasures(r);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Solicitud de ${r.type.toLowerCase()}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                RequestStatusBadge(r, forClient: true),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Enviada el ${r.date}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (r.status == QuoteRequest.rejected) ...[
              const SizedBox(height: 12),
              Text(
                r.reason.isEmpty
                    ? 'El taller no pudo aceptar esta solicitud. Escríbele si tienes dudas.'
                    : 'Motivo: ${r.reason}',
                style: TextStyle(fontSize: 13, color: AppColors.cancelled),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              r.description,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            if (measures != null) ...[
              const SizedBox(height: 8),
              Text(
                measures,
                style: AppText.mono(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
            if (r.wantsVisit) ...[
              const SizedBox(height: 8),
              Text(
                'Pediste que vayan a medir.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
            if (r.photos.isNotEmpty) ...[
              const SizedBox(height: 14),
              RequestPhotos(photos: r.photos, title: 'Fotos de tu solicitud'),
            ],
          ],
        ),
      ),
    ),
  );
}
