import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class ParkingGame extends StatefulWidget {
  const ParkingGame({super.key});
  @override
  State<ParkingGame> createState() => _ParkingGameState();
}

class _ParkingGameState extends State<ParkingGame> {
  static const Offset _spotPos = Offset(0.5, 0.16);

  double get _spotW => max(0.12, 0.22 - _level * 0.025);
  double get _spotH => max(0.08, 0.15 - _level * 0.018);

  static const List<List<Rect>> _wallSets = [
    // Level 1 — weite Durchfahrt
    [
      Rect.fromLTWH(0.00, 0.42, 0.30, 0.05),
      Rect.fromLTWH(0.70, 0.42, 0.30, 0.05),
      Rect.fromLTWH(0.00, 0.63, 0.22, 0.05),
      Rect.fromLTWH(0.78, 0.63, 0.22, 0.05),
    ],
    // Level 2 — engere Lücke
    [
      Rect.fromLTWH(0.00, 0.38, 0.36, 0.05),
      Rect.fromLTWH(0.64, 0.38, 0.36, 0.05),
      Rect.fromLTWH(0.00, 0.57, 0.20, 0.05),
      Rect.fromLTWH(0.55, 0.57, 0.45, 0.05),
      Rect.fromLTWH(0.25, 0.74, 0.50, 0.05),
    ],
    // Level 3 — Zickzack
    [
      Rect.fromLTWH(0.00, 0.34, 0.40, 0.05),
      Rect.fromLTWH(0.65, 0.34, 0.35, 0.05),
      Rect.fromLTWH(0.28, 0.52, 0.44, 0.05),
      Rect.fromLTWH(0.00, 0.68, 0.28, 0.05),
      Rect.fromLTWH(0.65, 0.68, 0.35, 0.05),
      Rect.fromLTWH(0.18, 0.80, 0.64, 0.05),
    ],
    // Level 4 — sehr eng
    [
      Rect.fromLTWH(0.00, 0.30, 0.42, 0.05),
      Rect.fromLTWH(0.62, 0.30, 0.38, 0.05),
      Rect.fromLTWH(0.00, 0.48, 0.18, 0.05),
      Rect.fromLTWH(0.44, 0.48, 0.56, 0.05),
      Rect.fromLTWH(0.22, 0.64, 0.56, 0.05),
      Rect.fromLTWH(0.00, 0.76, 0.36, 0.05),
      Rect.fromLTWH(0.64, 0.76, 0.36, 0.05),
    ],
    // Level 5 — Doppelschlange
    [
      Rect.fromLTWH(0.20, 0.29, 0.60, 0.05),
      Rect.fromLTWH(0.00, 0.44, 0.55, 0.05),
      Rect.fromLTWH(0.35, 0.57, 0.65, 0.05),
      Rect.fromLTWH(0.00, 0.70, 0.50, 0.05),
      Rect.fromLTWH(0.58, 0.81, 0.42, 0.05),
    ],
    // Level 6 — Kreuzung
    [
      Rect.fromLTWH(0.00, 0.27, 0.38, 0.05),
      Rect.fromLTWH(0.62, 0.27, 0.38, 0.05),
      Rect.fromLTWH(0.45, 0.38, 0.05, 0.28),
      Rect.fromLTWH(0.00, 0.52, 0.34, 0.05),
      Rect.fromLTWH(0.58, 0.52, 0.42, 0.05),
      Rect.fromLTWH(0.14, 0.68, 0.60, 0.05),
      Rect.fromLTWH(0.00, 0.80, 0.28, 0.05),
      Rect.fromLTWH(0.72, 0.80, 0.28, 0.05),
    ],
    // Level 7 — enger Kanal
    [
      Rect.fromLTWH(0.00, 0.24, 0.44, 0.05),
      Rect.fromLTWH(0.56, 0.24, 0.44, 0.05),
      Rect.fromLTWH(0.00, 0.38, 0.05, 0.30),
      Rect.fromLTWH(0.95, 0.38, 0.05, 0.30),
      Rect.fromLTWH(0.00, 0.52, 0.30, 0.05),
      Rect.fromLTWH(0.55, 0.52, 0.45, 0.05),
      Rect.fromLTWH(0.18, 0.66, 0.64, 0.05),
      Rect.fromLTWH(0.00, 0.79, 0.40, 0.05),
      Rect.fromLTWH(0.60, 0.79, 0.40, 0.05),
    ],
    // Level 8 — Spirale
    [
      Rect.fromLTWH(0.10, 0.22, 0.80, 0.05),
      Rect.fromLTWH(0.85, 0.22, 0.05, 0.40),
      Rect.fromLTWH(0.10, 0.57, 0.75, 0.05),
      Rect.fromLTWH(0.10, 0.57, 0.05, 0.28),
      Rect.fromLTWH(0.15, 0.80, 0.60, 0.05),
      Rect.fromLTWH(0.00, 0.38, 0.30, 0.05),
      Rect.fromLTWH(0.60, 0.70, 0.40, 0.05),
    ],
    // Level 9 — Labyrinth
    [
      Rect.fromLTWH(0.00, 0.22, 0.46, 0.04),
      Rect.fromLTWH(0.54, 0.22, 0.46, 0.04),
      Rect.fromLTWH(0.30, 0.35, 0.04, 0.26),
      Rect.fromLTWH(0.66, 0.35, 0.04, 0.26),
      Rect.fromLTWH(0.00, 0.46, 0.24, 0.04),
      Rect.fromLTWH(0.76, 0.46, 0.24, 0.04),
      Rect.fromLTWH(0.34, 0.58, 0.32, 0.04),
      Rect.fromLTWH(0.00, 0.66, 0.46, 0.04),
      Rect.fromLTWH(0.54, 0.66, 0.46, 0.04),
      Rect.fromLTWH(0.18, 0.78, 0.64, 0.04),
    ],
    // Level 10 — Boss
    [
      Rect.fromLTWH(0.00, 0.20, 0.44, 0.04),
      Rect.fromLTWH(0.56, 0.20, 0.44, 0.04),
      Rect.fromLTWH(0.20, 0.31, 0.04, 0.22),
      Rect.fromLTWH(0.76, 0.31, 0.04, 0.22),
      Rect.fromLTWH(0.00, 0.40, 0.14, 0.04),
      Rect.fromLTWH(0.38, 0.40, 0.24, 0.04),
      Rect.fromLTWH(0.80, 0.40, 0.20, 0.04),
      Rect.fromLTWH(0.24, 0.52, 0.52, 0.04),
      Rect.fromLTWH(0.00, 0.62, 0.36, 0.04),
      Rect.fromLTWH(0.64, 0.62, 0.36, 0.04),
      Rect.fromLTWH(0.36, 0.72, 0.28, 0.04),
      Rect.fromLTWH(0.00, 0.82, 0.28, 0.04),
      Rect.fromLTWH(0.72, 0.82, 0.28, 0.04),
    ],
  ];

  static const int _maxLevel = 10;

  List<Rect> get _walls =>
      _wallSets[_level.clamp(0, _wallSets.length - 1)];

  bool get _isLastLevel => _level >= _maxLevel - 1;

  int _level = 0;
  Offset _car = const Offset(0.5, 0.88);
  bool _started = false;
  bool _parked  = false;
  bool _crashed = false;
  bool _completed = false;
  int _elapsed  = 0;
  int _score    = 0;
  int _best     = 0;
  Timer? _timer;
  Size _size = const Size(400, 700);

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => setState(() => _best = p.getInt('hs_parking') ?? 0));
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _car      = const Offset(0.5, 0.88);
      _started  = true;
      _parked   = false;
      _crashed  = false;
      _completed = false;
      _elapsed  = 0;
      _score    = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _elapsed++); });
  }

  void _nextLevel() {
    setState(() => _level++);
    _start();
  }

  void _restartAll() {
    setState(() { _level = 0; _completed = false; });
    _start();
  }

  void _onPan(DragUpdateDetails d) {
    if (!_started || _parked || _crashed) return;
    final dx = d.delta.dx / _size.width;
    final dy = d.delta.dy / _size.height;
    final next = Offset(
      (_car.dx + dx).clamp(0.04, 0.96),
      (_car.dy + dy).clamp(0.04, 0.96),
    );

    for (final w in _walls) {
      if (w.contains(next)) {
        _timer?.cancel();
        setState(() { _crashed = true; _started = false; });
        return;
      }
    }

    setState(() => _car = next);

    final spotRect = Rect.fromCenter(
        center: _spotPos, width: _spotW, height: _spotH);
    if (spotRect.contains(next)) {
      _timer?.cancel();
      final s = (1000 / (_elapsed + 1)).round();
      if (_isLastLevel) {
        setState(() {
          _parked = true; _started = false; _score = s;
          _completed = true;
        });
      } else {
        setState(() { _parked = true; _started = false; _score = s; });
      }
      if (s > _best) {
        _best = s;
        SharedPreferences.getInstance()
            .then((p) => p.setInt('hs_parking', s));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF888888),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Einparken – Level ${_level + 1}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_elapsed}s',
                  style: const TextStyle(
                      color: AppColors.orange, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onPanUpdate: _onPan,
        child: LayoutBuilder(builder: (ctx, c) {
          _size = Size(c.maxWidth, c.maxHeight);
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(children: [
            Container(color: const Color(0xFF7A7A7A)),
            // Parking spot
            Positioned(
              left:   (_spotPos.dx - _spotW / 2) * w,
              top:    (_spotPos.dy - _spotH / 2) * h,
              width:  _spotW * w,
              height: _spotH * h,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.18),
                  border: Border.all(color: Colors.blue, width: 3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('P',
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            // Walls
            ..._walls.map((wall) => Positioned(
              left:   wall.left   * w,
              top:    wall.top    * h,
              width:  wall.width  * w,
              height: wall.height * h,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF5C3D1E),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )),
            // Car — Vogelperspektive
            Positioned(
              left: _car.dx * w - 18,
              top:  _car.dy * h - 29,
              child: _crashed
                  ? const Text('💥', style: TextStyle(fontSize: 36))
                  : const _TopDownCar(),
            ),
            if (_started && !_parked && !_crashed)
              Positioned(
                bottom: 10, left: 0, right: 0,
                child: const Center(
                  child: Text('↕ ↔  Ziehe das Auto in den Parkplatz',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
            // Overlays
            if (!_started && !_parked && !_crashed && !_completed)
              _overlay('🚗',
                  'Schiebe das Auto\nin den blauen Parkplatz!',
                  'Starten', null, _start),
            if (_parked && !_completed)
              _overlay('✅',
                  'Level ${_level} geschafft! 🎉\n$_score Punkte',
                  'Nächstes Level',
                  'Highscore: $_best Pkt.',
                  _nextLevel),
            if (_completed)
              _overlayComplete(),
            if (_crashed)
              _overlay('💥',
                  'Crash! Nochmal versuchen.',
                  'Nochmal',
                  _best > 0 ? 'Highscore: $_best Pkt.' : null,
                  _start),
          ]);
        }),
      ),
    );
  }

  Widget _overlay(String emoji, String msg, String btn, String? sub,
      VoidCallback onTap) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.80),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub,
                style: const TextStyle(color: AppColors.orange, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white),
            child: Text(btn),
          ),
        ]),
      ),
    );
  }

  Widget _overlayComplete() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 10),
          const Text('Alle 10 Level geschafft!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Highscore: $_best Pkt.',
              style: const TextStyle(color: AppColors.orange, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _restartAll,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange, foregroundColor: Colors.white),
            child: const Text('Nochmal von vorne'),
          ),
        ]),
      ),
    );
  }
}

// ── Vogelperspektive Auto ────────────────────────────────────────────────────

class _TopDownCar extends StatelessWidget {
  const _TopDownCar();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      height: 58,
      child: CustomPaint(painter: _CarPainter()),
    );
  }
}

class _CarPainter extends CustomPainter {
  const _CarPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Räder
    final wp = Paint()..color = const Color(0xFF1A1A1A);
    for (final r in <Rect>[
      Rect.fromLTWH(-3, h * 0.09, 8, 13),
      Rect.fromLTWH(w - 5, h * 0.09, 8, 13),
      Rect.fromLTWH(-3, h * 0.73, 8, 13),
      Rect.fromLTWH(w - 5, h * 0.73, 8, 13),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), wp);
    }

    // Karosserie (Rot für Einparken)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.07, 0, w * 0.86, h),
        Radius.circular(w * 0.24),
      ),
      Paint()..color = const Color(0xFFC62828),
    );

    // Frontscheibe (oben = Fahrtrichtung)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.17, h * 0.09, w * 0.66, h * 0.19),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xCCADD8E6),
    );

    // Heckscheibe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.72, w * 0.60, h * 0.13),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0x88ADD8E6),
    );

    // Motorhaubennaht
    canvas.drawLine(
      Offset(w * 0.28, h * 0.31),
      Offset(w * 0.72, h * 0.31),
      Paint()
        ..color = const Color(0x441A1A1A)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
