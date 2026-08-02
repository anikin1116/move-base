import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class FuelGame extends StatefulWidget {
  const FuelGame({super.key});
  @override
  State<FuelGame> createState() => _FuelGameState();
}

class _FuelGameState extends State<FuelGame>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _running = false;
  bool _stopped = false;
  int _totalScore = 0;
  int _round = 0;
  int _lastScore = 0;
  String _feedback = '';
  int _best = 0;
  static const int _rounds = 5;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    SharedPreferences.getInstance()
        .then((p) => setState(() => _best = p.getInt('hs_fuel') ?? 0));
  }

  void _start() {
    setState(() {
      _running = true;
      _stopped = false;
      _totalScore = 0;
      _round = 0;
      _feedback = '';
    });
    _ctrl.repeat(reverse: true);
  }

  void _onTap() {
    if (!_running) { _start(); return; }
    if (_stopped) return;
    _ctrl.stop();

    // value 0→1: 0=E (left), 1=F (right)
    final v = _ctrl.value;
    int score;
    String fb;
    if (v >= 0.85) { score = 100; fb = '⛽ VOLL! 100 Pkt.'; }
    else if (v >= 0.70) { score = 75; fb = '👍 Fast voll – 75 Pkt.'; }
    else if (v >= 0.50) { score = 50; fb = '😐 Halbvoll – 50 Pkt.'; }
    else if (v >= 0.25) { score = 20; fb = '😬 Wenig – 20 Pkt.'; }
    else               { score = 0;  fb = '💀 Leer! 0 Pkt.'; }

    setState(() {
      _stopped = true;
      _lastScore = score;
      _totalScore += score;
      _feedback = fb;
      _round++;
    });

    if (_round >= _rounds) {
      Future.delayed(const Duration(milliseconds: 1800), _finish);
    } else {
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        setState(() => _stopped = false);
        _ctrl.repeat(reverse: true);
      });
    }
  }

  void _finish() {
    if (!mounted) return;
    setState(() => _running = false);
    if (_totalScore > _best) {
      _best = _totalScore;
      SharedPreferences.getInstance()
          .then((p) => p.setInt('hs_fuel', _totalScore));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Scaffold(
        backgroundColor: Colors.grey.shade900,
        appBar: AppBar(
          backgroundColor: Colors.grey.shade900,
          foregroundColor: Colors.white,
          title: Row(children: [
            const Text('⛽  Tanknadel'),
            const Spacer(),
            Text('$_totalScore Pkt.',
                style: const TextStyle(
                    color: AppColors.orange, fontWeight: FontWeight.bold)),
          ]),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_running)
                Text('Runde ${_round + 1} / $_rounds',
                    style: const TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => CustomPaint(
                  size: const Size(300, 170),
                  painter: _GaugePainter(_ctrl.value),
                ),
              ),
              const SizedBox(height: 32),
              _buildStatus(),
              const SizedBox(height: 12),
              if (_best > 0 && _running)
                Text('Highscore: $_best Pkt.',
                    style: const TextStyle(color: AppColors.orange, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    if (!_running && _round == 0) {
      return const Text(
        'Tippe um die Nadel\nbei ⛽ VOLL zu stoppen!',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 18),
      );
    }
    if (_stopped && _round < _rounds) {
      return Text(_feedback,
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));
    }
    if (!_running && _round >= _rounds) {
      return Column(children: [
        const Text('Gesamt', style: TextStyle(color: Colors.white54, fontSize: 14)),
        Text('$_totalScore Pkt.',
            style: const TextStyle(
                color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold)),
        Text('Highscore: $_best Pkt.',
            style: const TextStyle(color: AppColors.orange, fontSize: 14)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _start,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange, foregroundColor: Colors.white),
          child: const Text('Nochmal'),
        ),
      ]);
    }
    return const Text('TIPPEN!',
        style: TextStyle(color: Colors.white38, fontSize: 16));
  }
}

class _GaugePainter extends CustomPainter {
  final double value; // 0 = E, 1 = F
  const _GaugePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.92;
    final r = size.width * 0.44;
    const sw = 20.0;

    void arc(Color color, double startFrac, double sweepFrac) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        pi + pi * startFrac,
        pi * sweepFrac,
        false,
        Paint()
          ..color = color
          ..strokeWidth = sw
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(Colors.red.shade700, 0.0, 0.30);
    arc(Colors.yellow.shade700, 0.30, 0.30);
    arc(Colors.green.shade600, 0.60, 0.40);

    // Labels E / F
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String t, Offset pos) {
      tp.text = TextSpan(
          text: t,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    label('E', Offset(cx - r - 18, cy - 4));
    label('F', Offset(cx + r + 18, cy - 4));

    // Needle
    final angle = pi + value * pi;
    final nx = cx + (r - 12) * cos(angle);
    final ny = cy + (r - 12) * sin(angle);
    canvas.drawLine(
      Offset(cx, cy),
      Offset(nx, ny),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx, cy), 7,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}
