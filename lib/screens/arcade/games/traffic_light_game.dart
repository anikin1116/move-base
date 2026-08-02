import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

enum _Phase { idle, waiting, green, tooEarly, result, done }

class TrafficLightGame extends StatefulWidget {
  const TrafficLightGame({super.key});
  @override
  State<TrafficLightGame> createState() => _TrafficLightGameState();
}

class _TrafficLightGameState extends State<TrafficLightGame> {
  _Phase _phase = _Phase.idle;
  int _reactionMs = 0;
  int _best = 0;
  DateTime? _greenAt;
  Timer? _timer;
  final Random _rng = Random();
  int _round = 0;
  static const int _totalRounds = 3;
  final List<int> _results = [];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => setState(() => _best = p.getInt('hs_traffic') ?? 0));
  }

  void _startRound() {
    _timer?.cancel();
    setState(() => _phase = _Phase.waiting);
    final delay = 2000 + _rng.nextInt(3000);
    _timer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.green;
        _greenAt = DateTime.now();
      });
    });
  }

  void _onTap() {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.done:
        _results.clear();
        _round = 0;
        _startRound();
        break;
      case _Phase.waiting:
        _timer?.cancel();
        setState(() => _phase = _Phase.tooEarly);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _startRound();
        });
        break;
      case _Phase.green:
        final ms = DateTime.now().difference(_greenAt!).inMilliseconds;
        _results.add(ms);
        _round++;
        setState(() {
          _reactionMs = ms;
          _phase = _Phase.result;
        });
        if (_round >= _totalRounds) {
          Future.delayed(const Duration(seconds: 2), _finish);
        } else {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _startRound();
          });
        }
        break;
      case _Phase.tooEarly:
      case _Phase.result:
        break;
    }
  }

  void _finish() {
    if (!mounted) return;
    final avg = _results.reduce((a, b) => a + b) ~/ _results.length;
    setState(() => _phase = _Phase.done);
    if (_best == 0 || avg < _best) {
      _best = avg;
      SharedPreferences.getInstance().then((p) => p.setInt('hs_traffic', avg));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            const Text('🚦  Ampel-Reaktionstest'),
            const Spacer(),
            if (_round > 0 && _phase != _Phase.done)
              Text('$_round/$_totalRounds',
                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
          ]),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLight(),
              const SizedBox(height: 36),
              _buildMessage(),
              const SizedBox(height: 12),
              if (_best > 0 && _phase != _Phase.done)
                Text('Highscore: $_best ms',
                    style: const TextStyle(color: AppColors.orange, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLight() {
    final isRed    = _phase == _Phase.waiting || _phase == _Phase.tooEarly;
    final isGreen  = _phase == _Phase.green;
    return Container(
      width: 90,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade700, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dot(Colors.red, isRed),
          _dot(Colors.yellow, false),
          _dot(Colors.green, isGreen),
        ],
      ),
    );
  }

  Widget _dot(Color color, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withOpacity(0.12),
        boxShadow: active
            ? [BoxShadow(color: color.withOpacity(0.7), blurRadius: 20, spreadRadius: 3)]
            : [],
      ),
    );
  }

  Widget _buildMessage() {
    switch (_phase) {
      case _Phase.idle:
        return const Text('Tippe zum Starten',
            style: TextStyle(color: Colors.white, fontSize: 20));
      case _Phase.waiting:
        return const Text('Warte auf Grün …',
            style: TextStyle(color: Colors.white70, fontSize: 18));
      case _Phase.green:
        return const Text('JETZT!',
            style: TextStyle(
                color: Colors.green, fontSize: 42, fontWeight: FontWeight.bold));
      case _Phase.tooEarly:
        return const Text('Zu früh! 😅',
            style: TextStyle(color: Colors.red, fontSize: 26));
      case _Phase.result:
        final label = _reactionMs < 200
            ? '⚡ Blitzschnell!'
            : _reactionMs < 350
                ? '👍 Sehr gut!'
                : _reactionMs < 500
                    ? '😐 Geht so …'
                    : '🐢 Zu langsam';
        return Column(children: [
          Text('$_reactionMs ms',
              style: const TextStyle(
                  color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ]);
      case _Phase.done:
        final avg = _results.reduce((a, b) => a + b) ~/ _results.length;
        return Column(children: [
          const Text('Ø Reaktionszeit',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          Text('$avg ms',
              style: const TextStyle(
                  color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold)),
          Text('Highscore: $_best ms',
              style: const TextStyle(color: AppColors.orange, fontSize: 14)),
          const SizedBox(height: 16),
          const Text('Tippen zum Wiederholen',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ]);
    }
  }
}
