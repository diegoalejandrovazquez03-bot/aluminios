import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';

class MeasureScreen extends StatefulWidget {
  final Function(double width, double height, double? depth) onConfirm;

  const MeasureScreen({super.key, required this.onConfirm});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  // Steps: 'perm', 'camera', 'adjust', 'review'
  String _step = 'camera';
  final bool _isStable = true;
  final double _tiltX = 0.5;
  final double _tiltY = -0.8;
  final double _motion = 0.4;

  // 4 Quadrilateral corner points in percentage [0..100]
  final List<Offset> _pts = [
    const Offset(20, 22),
    const Offset(80, 22),
    const Offset(80, 78),
    const Offset(20, 78),
  ];

  int? _activeDragIndex;
  final double _simDepth = 7.5;
  bool _lidarDetected = true;

  final TextEditingController _wCtrl = TextEditingController();
  final TextEditingController _hCtrl = TextEditingController();
  final TextEditingController _dCtrl = TextEditingController();

  double _calcWidth() {
    final dTop = _dist(_pts[0], _pts[1]);
    final dBottom = _dist(_pts[3], _pts[2]);
    return ((dTop + dBottom) / 2.0) * 2.0;
  }

  double _calcHeight() {
    final dLeft = _dist(_pts[0], _pts[3]);
    final dRight = _dist(_pts[1], _pts[2]);
    return ((dLeft + dRight) / 2.0) * 2.0;
  }

  double _hypot(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

  double _dist(Offset a, Offset b) {
    return _hypot(a.dx - b.dx, (a.dy - b.dy) * 1.33);
  }

  @override
  void initState() {
    super.initState();
    _wCtrl.text = _calcWidth().round().toString();
    _hCtrl.text = _calcHeight().round().toString();
    _dCtrl.text = _simDepth.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _step == 'camera'
              ? 'Encuadra la pieza'
              : _step == 'adjust'
              ? 'Ajusta las esquinas'
              : 'Validar medidas',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'AR SIMULADO',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _step == 'camera'
            ? _buildCameraView()
            : _step == 'adjust'
            ? _buildAdjustView()
            : _buildReviewView(),
      ),
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Simulated camera viewfinder preview
              Container(
                color: AppColors.surfaceDark,
                child: Center(
                  child: Container(
                    width: 240,
                    height: 280,
                    decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      border: Border.all(color: Colors.white38, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.window_rounded,
                          size: 70,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Alinea la ventana o cancel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Level indicator bubble at bottom
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isStable
                                ? AppColors.done
                                : AppColors.pending,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isStable
                                  ? AppColors.done
                                  : AppColors.pending,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isStable
                                  ? 'Estable y nivelado'
                                  : 'Nivela el teléfono',
                              style: TextStyle(
                                color: _isStable
                                    ? AppColors.completedBg
                                    : AppColors.pendingBg,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Giroscopio: $_tiltX° / $_tiltY°  •  Acelerómetro: $_motion m/s²',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Capture Button
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text(
                'Capturar pieza para medir',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                setState(() {
                  _step = 'adjust';
                  _wCtrl.text = _calcWidth().round().toString();
                  _hCtrl.text = _calcHeight().round().toString();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustView() {
    final w = _calcWidth().round();
    final h = _calcHeight().round();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: AppColors.bgDark,
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.done, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Arrastra los 4 círculos a las esquinas exactas de la pieza',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Interactive Quadrilateral adjustment area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boxW = constraints.maxWidth;
              final boxH = constraints.maxHeight;

              return GestureDetector(
                onPanDown: (details) {
                  final touchX = (details.localPosition.dx / boxW) * 100.0;
                  final touchY = (details.localPosition.dy / boxH) * 100.0;

                  int? nearestIdx;
                  double minDist = 15.0; // touch radius in %
                  for (int i = 0; i < _pts.length; i++) {
                    final d = _hypot(_pts[i].dx - touchX, _pts[i].dy - touchY);
                    if (d < minDist) {
                      minDist = d;
                      nearestIdx = i;
                    }
                  }
                  setState(() => _activeDragIndex = nearestIdx);
                },
                onPanUpdate: (details) {
                  if (_activeDragIndex == null) return;
                  final newX = (details.localPosition.dx / boxW * 100.0).clamp(
                    5.0,
                    95.0,
                  );
                  final newY = (details.localPosition.dy / boxH * 100.0).clamp(
                    5.0,
                    95.0,
                  );

                  setState(() {
                    _pts[_activeDragIndex!] = Offset(newX, newY);
                    _wCtrl.text = _calcWidth().round().toString();
                    _hCtrl.text = _calcHeight().round().toString();
                  });
                },
                onPanEnd: (_) => setState(() => _activeDragIndex = null),
                child: Container(
                  color: AppColors.surfaceDark,
                  child: Stack(
                    children: [
                      // Background mock frame
                      Center(
                        child: Container(
                          width: boxW * 0.7,
                          height: boxH * 0.6,
                          decoration: BoxDecoration(
                            color: AppColors.borderDark,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                      ),

                      // Connecting Polygon
                      CustomPaint(
                        size: Size(boxW, boxH),
                        painter: _PolygonPainter(
                          pts: _pts,
                          boxW: boxW,
                          boxH: boxH,
                        ),
                      ),

                      // Dimensions badges on edges
                      Positioned(
                        left: (boxW * ((_pts[0].dx + _pts[1].dx) / 200.0)) - 25,
                        top: (boxH * ((_pts[0].dy + _pts[1].dy) / 200.0)) - 12,
                        child: _dimBadge('$w cm'),
                      ),
                      Positioned(
                        left: (boxW * ((_pts[1].dx + _pts[2].dx) / 200.0)) - 25,
                        top: (boxH * ((_pts[1].dy + _pts[2].dy) / 200.0)) - 12,
                        child: _dimBadge('$h cm'),
                      ),

                      // 4 Corner draggable handles
                      for (int i = 0; i < _pts.length; i++)
                        Positioned(
                          left: (boxW * (_pts[i].dx / 100.0)) - 16,
                          top: (boxH * (_pts[i].dy / 100.0)) - 16,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.blue,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 6),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // LiDAR Depth box
        Container(
          color: AppColors.bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sensor de profundidad (LiDAR)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Profundidad estimada: $_simDepth cm',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _lidarDetected = !_lidarDetected),
                child: Text(
                  _lidarDetected ? 'Detectado' : 'Manual',
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Action Buttons
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
                  onPressed: () => setState(() => _step = 'camera'),
                  child: const Text('Repetir foto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                  ),
                  onPressed: () => setState(() => _step = 'review'),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewView() {
    return Container(
      color: AppColors.bgDark,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Medidas calculadas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Revisa y ajusta los valores finales antes de guardarlos en el producto:',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _wCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Ancho (cm)',
              labelStyle: TextStyle(color: Colors.white70),
              suffixText: 'cm',
              suffixStyle: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _hCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Alto (cm)',
              labelStyle: TextStyle(color: Colors.white70),
              suffixText: 'cm',
              suffixStyle: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _dCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Profundidad (cm)',
              labelStyle: TextStyle(color: Colors.white70),
              suffixText: 'cm',
              suffixStyle: TextStyle(color: Colors.white70),
            ),
          ),
          const Spacer(),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              final w = double.tryParse(_wCtrl.text) ?? 120.0;
              final h = double.tryParse(_hCtrl.text) ?? 100.0;
              final d = double.tryParse(_dCtrl.text);
              widget.onConfirm(w, h, d);
              Navigator.pop(context);
            },
            child: const Text(
              'Confirmar y aplicar medidas',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dimBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PolygonPainter extends CustomPainter {
  final List<Offset> pts;
  final double boxW;
  final double boxH;

  _PolygonPainter({required this.pts, required this.boxW, required this.boxH});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final p = Offset(boxW * (pts[i].dx / 100.0), boxH * (pts[i].dy / 100.0));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = AppColors.blue.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) => true;
}
