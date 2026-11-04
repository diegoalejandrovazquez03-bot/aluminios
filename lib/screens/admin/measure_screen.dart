import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../core/input_rules.dart';
import '../../core/photo_picker.dart';

/// Medición asistida por foto.
///
/// Una foto por sí sola no da centímetros reales (no hay escala ni
/// profundidad), así que el flujo es: foto real → marcar las 4 esquinas de la
/// pieza → escribir el ancho medido con flexómetro → el alto se calcula en
/// proporción. El resultado es aproximado y se puede corregir antes de usarlo.
class MeasureScreen extends StatefulWidget {
  final Function(double width, double height, double? depth) onConfirm;

  const MeasureScreen({super.key, required this.onConfirm});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

enum _Step { source, adjust, review }

class _MeasureScreenState extends State<MeasureScreen> {
  _Step _step = _Step.source;
  Uint8List? _photo;
  Size? _photoSize;
  bool _loading = false;

  // Esquinas de la pieza en % de la foto: sup-izq, sup-der, inf-der, inf-izq.
  final List<Offset> _pts = [
    const Offset(20, 20),
    const Offset(80, 20),
    const Offset(80, 80),
    const Offset(20, 80),
  ];
  int? _activeDragIndex;

  final _refCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  final _dCtrl = TextEditingController();
  bool _showErrors = false;

  @override
  void dispose() {
    _refCtrl.dispose();
    _wCtrl.dispose();
    _hCtrl.dispose();
    _dCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final bytes = await PhotoPicker.pick(context, source);
    if (bytes == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final image = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _photoSize = Size(image.width.toDouble(), image.height.toDouble());
        _step = _Step.adjust;
      });
      image.dispose();
    } catch (e) {
      debugPrint('MeasureScreen: no se pudo leer la foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer la foto. Prueba con otra.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _dist(Offset a, Offset b, Size box) {
    final dx = (a.dx - b.dx) / 100 * box.width;
    final dy = (a.dy - b.dy) / 100 * box.height;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Alto proporcional al ancho de referencia (en el espacio de la foto).
  double? _estimatedHeight() {
    final ref = MeasureInput.parse(_refCtrl.text);
    final size = _photoSize;
    if (ref == null || size == null) return null;
    final widthPx =
        (_dist(_pts[0], _pts[1], size) + _dist(_pts[3], _pts[2], size)) / 2;
    final heightPx =
        (_dist(_pts[0], _pts[3], size) + _dist(_pts[1], _pts[2], size)) / 2;
    if (widthPx <= 0) return null;
    return ref * heightPx / widthPx;
  }

  void _goToReview({double? width, double? height}) {
    setState(() {
      _wCtrl.text = MeasureInput.format(width);
      _hCtrl.text = height == null
          ? ''
          : MeasureInput.format((height * 10).round() / 10);
      _showErrors = false;
      _step = _Step.review;
    });
  }

  void _confirm() {
    final w = MeasureInput.parse(_wCtrl.text);
    final h = MeasureInput.parse(_hCtrl.text);
    final depthText = _dCtrl.text.trim();
    final d = depthText.isEmpty ? null : MeasureInput.parse(depthText);
    if (w == null || h == null || (depthText.isNotEmpty && d == null)) {
      setState(() => _showErrors = true);
      return;
    }
    widget.onConfirm(w, h, d);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.source => 'Medir pieza',
      _Step.adjust => 'Marca las esquinas',
      _Step.review => 'Revisar medidas',
    };
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.textOnDark,
        iconTheme: const IconThemeData(color: AppColors.textOnDark),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: switch (_step) {
          _Step.source => _buildSourceView(),
          _Step.adjust => _buildAdjustView(),
          _Step.review => _buildReviewView(),
        },
      ),
    );
  }

  Widget _buildSourceView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.straighten, size: 56, color: AppColors.aluminum),
        const SizedBox(height: 16),
        const Text(
          'Toma una foto de frente a la pieza o elige una de tu galería. '
          'Después marcarás sus esquinas y escribirás el ancho medido con '
          'flexómetro para calcular el alto.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedOnDark, height: 1.45),
        ),
        const SizedBox(height: 28),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (PhotoPicker.cameraAvailable) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textOnDark,
                foregroundColor: AppColors.bgDark,
              ),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tomar foto'),
              onPressed: () => _pickPhoto(ImageSource.camera),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textOnDark,
              side: const BorderSide(color: AppColors.borderDark),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Elegir de la galería'),
            onPressed: () => _pickPhoto(ImageSource.gallery),
          ),
          const SizedBox(height: 12),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedOnDark),
            onPressed: () => _goToReview(),
            child: const Text('Capturar medidas a mano'),
          ),
        ],
      ],
    );
  }

  Widget _buildAdjustView() {
    final photo = _photo!;
    final size = _photoSize!;
    final estimated = _estimatedHeight();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          color: AppColors.surfaceDark,
          child: const Text(
            'Arrastra los 4 círculos a las esquinas de la pieza.',
            style: TextStyle(color: AppColors.softOnDark, fontSize: 13),
          ),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: size.width / size.height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boxW = constraints.maxWidth;
                  final boxH = constraints.maxHeight;
                  return GestureDetector(
                    onPanDown: (details) {
                      final x = details.localPosition.dx / boxW * 100;
                      final y = details.localPosition.dy / boxH * 100;
                      int? nearest;
                      double best = 12; // radio de toque en %
                      for (int i = 0; i < _pts.length; i++) {
                        final d = (Offset(x, y) - _pts[i]).distance;
                        if (d < best) {
                          best = d;
                          nearest = i;
                        }
                      }
                      setState(() => _activeDragIndex = nearest);
                    },
                    onPanUpdate: (details) {
                      final i = _activeDragIndex;
                      if (i == null) return;
                      setState(() {
                        _pts[i] = Offset(
                          (details.localPosition.dx / boxW * 100).clamp(0, 100),
                          (details.localPosition.dy / boxH * 100).clamp(0, 100),
                        );
                      });
                    },
                    onPanEnd: (_) => setState(() => _activeDragIndex = null),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(photo, fit: BoxFit.fill),
                        ),
                        CustomPaint(
                          size: Size(boxW, boxH),
                          painter: _PolygonPainter(pts: _pts),
                        ),
                        for (int i = 0; i < _pts.length; i++)
                          Positioned(
                            left: boxW * _pts[i].dx / 100 - 16,
                            top: boxH * _pts[i].dy / 100 - 16,
                            child: IgnorePointer(
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent.withValues(
                                    alpha: _activeDragIndex == i ? 0.9 : 0.6,
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Container(
          color: AppColors.surfaceDark,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _refCtrl,
                keyboardType: MeasureInput.keyboard,
                inputFormatters: MeasureInput.formatters,
                style: const TextStyle(color: AppColors.textOnDark),
                decoration: _darkField(
                  'Ancho real medido (borde superior)',
                  error: _refCtrl.text.isEmpty
                      ? null
                      : MeasureInput.validate(_refCtrl.text),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Text(
                estimated == null
                    ? 'Escribe el ancho para calcular el alto.'
                    : 'Alto estimado: ${estimated.toStringAsFixed(1)} cm (aproximado)',
                style: const TextStyle(
                  color: AppColors.softOnDark,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textOnDark,
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                      onPressed: () => setState(() => _step = _Step.source),
                      child: const Text('Otra foto'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textOnDark,
                        foregroundColor: AppColors.bgDark,
                      ),
                      onPressed: estimated == null
                          ? null
                          : () => _goToReview(
                              width: MeasureInput.parse(_refCtrl.text),
                              height: estimated,
                            ),
                      child: const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewView() {
    String? errorFor(TextEditingController c, {bool optional = false}) {
      if (optional && c.text.trim().isEmpty) return null;
      if (!_showErrors && c.text.isEmpty) return null;
      return MeasureInput.validate(c.text);
    }

    Widget field(
      TextEditingController c,
      String label, {
      bool optional = false,
    }) {
      return TextField(
        controller: c,
        keyboardType: MeasureInput.keyboard,
        inputFormatters: MeasureInput.formatters,
        style: const TextStyle(color: AppColors.textOnDark, fontSize: 16),
        decoration: _darkField(label, error: errorFor(c, optional: optional)),
        onChanged: (_) => setState(() {}),
      );
    }

    // Desplazable: con el teclado abierto los campos nunca se enciman.
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Revisa y corrige las medidas antes de aplicarlas al producto.',
          style: TextStyle(color: AppColors.mutedOnDark, height: 1.4),
        ),
        if (_photo != null) ...[
          const SizedBox(height: 6),
          const Text(
            'Las medidas calculadas desde la foto son aproximadas; '
            'verifícalas con flexómetro.',
            style: TextStyle(color: AppColors.mutedOnDark, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        field(_wCtrl, 'Ancho'),
        const SizedBox(height: 16),
        field(_hCtrl, 'Alto'),
        const SizedBox(height: 16),
        field(_dCtrl, 'Profundidad (opcional)', optional: true),
        const SizedBox(height: 28),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textOnDark,
            foregroundColor: AppColors.bgDark,
          ),
          onPressed: _confirm,
          child: const Text('Aplicar medidas'),
        ),
      ],
    );
  }

  /// Estilo de campo para el fondo oscuro de esta pantalla (independiente
  /// del tema claro/oscuro de la app, para que el texto siempre se lea).
  InputDecoration _darkField(String label, {String? error}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      suffixText: 'cm',
      errorText: error,
      errorMaxLines: 2,
      filled: true,
      fillColor: AppColors.bgDark,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      labelStyle: const TextStyle(color: AppColors.mutedOnDark),
      floatingLabelStyle: const TextStyle(color: AppColors.softOnDark),
      suffixStyle: const TextStyle(color: AppColors.mutedOnDark),
      errorStyle: const TextStyle(color: Color(0xFFE08A7E)),
      border: border(AppColors.borderDark),
      enabledBorder: border(AppColors.borderDark),
      focusedBorder: border(AppColors.textOnDark, 1.5),
      errorBorder: border(const Color(0xFFE08A7E)),
      focusedErrorBorder: border(const Color(0xFFE08A7E), 1.5),
    );
  }
}

class _PolygonPainter extends CustomPainter {
  final List<Offset> pts;

  _PolygonPainter({required this.pts});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final p = Offset(
        size.width * pts[i].dx / 100,
        size.height * pts[i].dy / 100,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) => true;
}
