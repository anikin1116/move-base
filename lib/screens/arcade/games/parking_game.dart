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

  // Spot shrinks with level
  double get _spotW => max(0.12, 0.22 - _level * 0.03);
  double get _spotH => max(0.09, 0.15 - _level * 0.02);

  // Wall sets per level (normalized 0-1)
  static const List<List<Rect>> _wallSets = [
    // Level 1 — weite Durchfahrt
    [
      Rect.fromLTWH(0.00, 0.42, 0.30, 0.05),
      Rect.fromLTWH(0.70, 0.42, 0.30, 0.05),
      Rect.fromLTWH(0.00, 0.63, 0.22, 0.05),
      Rect.fromLTWH(0.78, 0.63, 0.22, 0.05),
    ],
    // Level 2 — engere Lücke + Extra-Wand
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
  ];

  List<Rect> get _walls =>
      _wallSets[_level.clamp(0, _wallSets.length - 1)];

  int _level = 0;
  Offset _car = const Offset(0.5, 0.88);
  bool _started = false;
  bool _parked  = false;
  bool _crashed = false;
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
      _car     = const Offset(0.5, 0.88);
      _started = true;
      _parked  = false;
      _crashed = false;
      _elapsed = 0;
      _score   = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _elapsed++); });
  }

  void _nextLevel() {
    setState(() => _level++);
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
      setState(() { _parked = true; _started = false; _score = s; });
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
        title: Row(children: [
          Text('🅿️  Einparken  –  Level ${_level + 1}'),
          const Spacer(),
          Text('${_elapsed}s',
              style: const TextStyle(
                  color: AppColors.orange, fontWeight: FontWeight.bold)),
        ]),
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
              left:  (_spotPos.dx - _spotW / 2) * w,
              top:   (_spotPos.dy - _spotH / 2) * h,
              width: _spotW * w,
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
            // Car (nach oben gedreht = Fahrtrichtung)
            Positioned(
              left: _car.dx * w - 22,
              top:  _car.dy * h - 22,
              child: Transform.rotate(
                angle: -pi / 2,
                child: Text(
                  _crashed ? '💥' : '🚗',
                  style: const TextStyle(fontSize: 44),
                ),
              ),
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
            if (!_started && !_parked && !_crashed)
              _overlay('🚗',
                  'Schiebe das Auto\nin den blauen Parkplatz!',
                  'Starten', null, _start),
            if (_parked)
              _overlay('✅',
                  'Level ${_level + 1} geschafft! 🎉\n$_score Punkte',
                  'Nächstes Level',
                  'Highscore: $_best Pkt.',
                  _nextLevel),
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
                style:
                    const TextStyle(color: AppColors.orange, fontSize: 13)),
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
}
