import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class ParkingGame extends StatefulWidget {
  const ParkingGame({super.key});
  @override
  State<ParkingGame> createState() => _ParkingGameState();
}

class _ParkingGameState extends State<ParkingGame> {
  // Normalized positions (0.0 – 1.0)
  Offset _car = const Offset(0.5, 0.88);
  static const Offset _spot = Offset(0.5, 0.18);
  static const double _spotW = 0.20;
  static const double _spotH = 0.14;

  static const List<Rect> _walls = [
    Rect.fromLTWH(0.05, 0.38, 0.35, 0.055),
    Rect.fromLTWH(0.60, 0.38, 0.35, 0.055),
    Rect.fromLTWH(0.05, 0.58, 0.28, 0.055),
    Rect.fromLTWH(0.67, 0.58, 0.28, 0.055),
  ];

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
      _car = const Offset(0.5, 0.88);
      _started = true;
      _parked  = false;
      _crashed = false;
      _elapsed = 0;
      _score   = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  void _onPan(DragUpdateDetails d) {
    if (!_started || _parked || _crashed) return;
    final dx = d.delta.dx / _size.width;
    final dy = d.delta.dy / _size.height;
    final next = Offset(
      (_car.dx + dx).clamp(0.05, 0.95),
      (_car.dy + dy).clamp(0.05, 0.95),
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
        center: _spot, width: _spotW, height: _spotH);
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
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Row(children: [
          const Text('🅿️  Einparken'),
          const Spacer(),
          Text('${_elapsed}s',
              style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
        ]),
      ),
      body: GestureDetector(
        onPanUpdate: _onPan,
        child: LayoutBuilder(builder: (ctx, c) {
          _size = Size(c.maxWidth, c.maxHeight);
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(children: [
            // Asphalt background
            Container(color: const Color(0xFF8A8A8A)),
            // Parking spot
            Positioned(
              left:  (_spot.dx - _spotW / 2) * w,
              top:   (_spot.dy - _spotH / 2) * h,
              width: _spotW * w,
              height: _spotH * h,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  border: Border.all(color: Colors.blue, width: 3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('P',
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 28,
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
            // Car
            Positioned(
              left: _car.dx * w - 22,
              top:  _car.dy * h - 22,
              child: Text(
                _crashed ? '💥' : '🚗',
                style: const TextStyle(fontSize: 44),
              ),
            ),
            // Hint arrow
            if (_started && !_parked && !_crashed)
              Positioned(
                bottom: 12, left: 0, right: 0,
                child: const Center(
                  child: Text('↕ ↔  Ziehe das Auto in den Parkplatz',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
            // Overlays
            if (!_started && !_parked && !_crashed) _overlay('🚗',
                'Ziehe das Auto in\nden blauen Parkplatz!', 'Starten', null),
            if (_parked) _overlay('✅',
                'Eingeparkt! 🎉\n$_score Punkte', 'Nochmal',
                'Highscore: $_best Pkt.'),
            if (_crashed) _overlay('💥',
                'Crash! Probiere es nochmal.', 'Nochmal',
                _best > 0 ? 'Highscore: $_best Pkt.' : null),
          ]);
        }),
      ),
    );
  }

  Widget _overlay(String emoji, String msg, String btn, String? sub) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.78),
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
            onPressed: _start,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange, foregroundColor: Colors.white),
            child: Text(btn),
          ),
        ]),
      ),
    );
  }
}
