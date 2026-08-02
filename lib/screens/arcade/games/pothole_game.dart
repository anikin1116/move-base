import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class PotholeGame extends StatefulWidget {
  const PotholeGame({super.key});
  @override
  State<PotholeGame> createState() => _PotholeGameState();
}

class _PotholeGameState extends State<PotholeGame> {
  static const int _lanes = 3;
  static final _rng = Random();

  int _carLane = 1;
  final List<_Hole> _holes = [];
  bool _running = false;
  bool _gameOver = false;
  int _score = 0;
  int _best = 0;
  double _speed = 3.0;
  int _spawnCounter = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => setState(() => _best = p.getInt('hs_pothole') ?? 0));
  }

  // Wie viele Tick-Frames zwischen zwei Spawns (50ms/Frame)
  // Score 0 → 22 Frames = 1100ms, Score 600 → 6 Frames = 300ms
  int get _spawnEvery => max(6, 22 - _score ~/ 35);

  // Ab Score 300 kommt manchmal ein zweites Loch
  bool get _spawnDouble => _score >= 300 && _rng.nextDouble() < 0.55;

  void _start() {
    _tick?.cancel();
    _holes.clear();
    setState(() {
      _carLane = 1;
      _score = 0;
      _speed = 3.0;
      _spawnCounter = 0;
      _running = true;
      _gameOver = false;
    });

    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        // Schlaglöcher bewegen
        for (final h in _holes) h.y += _speed;
        _holes.removeWhere((h) => h.y > 105);

        // Kollision prüfen
        for (final h in _holes) {
          if (h.lane == _carLane && h.y > 78 && h.y < 98) {
            _end();
            return;
          }
        }

        // Score + Geschwindigkeit
        _score++;
        _speed = min(14.0, 3.0 + _score / 50.0);

        // Spawn
        _spawnCounter++;
        if (_spawnCounter >= _spawnEvery) {
          _spawnCounter = 0;
          _spawnHoles();
        }
      });
    });
  }

  void _spawnHoles() {
    final lane1 = _rng.nextInt(_lanes);
    _holes.add(_Hole(lane1));

    if (_spawnDouble) {
      // Zweites Loch in einer anderen Spur
      final others = List.generate(_lanes, (i) => i)..remove(lane1);
      _holes.add(_Hole(others[_rng.nextInt(others.length)]));
    }
  }

  void _end() {
    _tick?.cancel();
    setState(() { _running = false; _gameOver = true; });
    if (_score > _best) {
      _best = _score;
      SharedPreferences.getInstance()
          .then((p) => p.setInt('hs_pothole', _score));
    }
  }

  void _tap(TapDownDetails d) {
    if (!_running) return;
    final mid = MediaQuery.of(context).size.width / 2;
    setState(() {
      _carLane = (d.globalPosition.dx < mid ? _carLane - 1 : _carLane + 1)
          .clamp(0, _lanes - 1);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // Schwierigkeits-Label für Anzeige
  String get _difficulty {
    if (_score < 150) return '';
    if (_score < 300) return '🔶 Schneller';
    if (_score < 500) return '🔴 Doppelt!';
    return '💀 Wahnsinn';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2C),
        foregroundColor: Colors.white,
        title: const Text('Schlaglöcher'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_score m',
                  style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTapDown: _tap,
        child: LayoutBuilder(builder: (ctx, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final laneW = w / _lanes;
          return Stack(children: [
            Container(color: const Color(0xFF3A3A3A)),
            CustomPaint(painter: _LanePainter(), size: Size(w, h)),
            // Schlaglöcher
            ..._holes.map((hole) {
              final x = laneW * hole.lane + laneW / 2;
              final y = h * hole.y / 100;
              return Positioned(
                left: x - 20,
                top: y - 20,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade600, width: 3),
                  ),
                  child: const Center(
                      child: Text('⚠', style: TextStyle(fontSize: 18))),
                ),
              );
            }),
            // Auto — Vogelperspektive
            Positioned(
              left: laneW * _carLane + laneW / 2 - 18,
              bottom: h * 0.08,
              child: const _TopDownCar(),
            ),
            // Schwierigkeits-Label
            if (_running && _difficulty.isNotEmpty)
              Positioned(
                top: 8, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_difficulty,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
            // Overlays
            if (!_running && !_gameOver)
              _overlay(
                icon: '🏎️',
                msg: 'Tippe links/rechts\num auszuweichen!',
                btn: 'Starten',
                sub: _best > 0 ? 'Highscore: $_best m' : null,
              ),
            if (_gameOver)
              _overlay(
                icon: '💥',
                msg: '$_score m zurückgelegt',
                btn: 'Nochmal',
                sub: 'Highscore: $_best m',
              ),
          ]);
        }),
      ),
    );
  }

  Widget _overlay(
      {required String icon,
      required String msg,
      required String btn,
      String? sub}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.82),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 60)),
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
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white),
            child: Text(btn),
          ),
        ]),
      ),
    );
  }
}

class _Hole {
  final int lane;
  double y;
  _Hole(this.lane) : y = -5;
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

    final wp = Paint()..color = const Color(0xFF1A1A1A);
    for (final r in <Rect>[
      Rect.fromLTWH(-3, h * 0.09, 8, 13),
      Rect.fromLTWH(w - 5, h * 0.09, 8, 13),
      Rect.fromLTWH(-3, h * 0.73, 8, 13),
      Rect.fromLTWH(w - 5, h * 0.73, 8, 13),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(2)), wp);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.07, 0, w * 0.86, h),
        Radius.circular(w * 0.24),
      ),
      Paint()..color = const Color(0xFF1565C0),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.17, h * 0.09, w * 0.66, h * 0.19),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xCCADD8E6),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.72, w * 0.60, h * 0.13),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0x88ADD8E6),
    );

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

class _LanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.yellow.withOpacity(0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      double y = 0;
      while (y < size.height) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 20), p);
        y += 40;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
