import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import 'games/pothole_game.dart';
import 'games/traffic_light_game.dart';
import 'games/parking_game.dart';
import 'games/fuel_game.dart';

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> {
  int _hs_pothole = 0;
  int _hs_traffic = 0;
  int _hs_parking = 0;
  int _hs_fuel = 0;

  @override
  void initState() {
    super.initState();
    _loadHighscores();
  }

  Future<void> _loadHighscores() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hs_pothole = prefs.getInt('hs_pothole') ?? 0;
      _hs_traffic = prefs.getInt('hs_traffic') ?? 0;
      _hs_parking = prefs.getInt('hs_parking') ?? 0;
      _hs_fuel    = prefs.getInt('hs_fuel')    ?? 0;
    });
  }

  Future<void> _open(Widget game) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => game));
    _loadHighscores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('🎮  MoveBase Arcade'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wähle ein Spiel:',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 14),
            _GameCard(
              emoji: '🚗',
              title: 'Schlagloch-Ausweicher',
              description: 'Weiche Schlaglöchern aus!',
              highscore: _hs_pothole > 0 ? '$_hs_pothole m' : '-',
              onTap: () => _open(const PotholeGame()),
            ),
            const SizedBox(height: 10),
            _GameCard(
              emoji: '🚦',
              title: 'Ampel-Reaktionstest',
              description: 'Wie schnell bist du?',
              highscore: _hs_traffic > 0 ? '$_hs_traffic ms' : '-',
              onTap: () => _open(const TrafficLightGame()),
            ),
            const SizedBox(height: 10),
            _GameCard(
              emoji: '🅿️',
              title: 'Einparken',
              description: 'Parke ohne anzustoßen!',
              highscore: _hs_parking > 0 ? '$_hs_parking Pkt.' : '-',
              onTap: () => _open(const ParkingGame()),
            ),
            const SizedBox(height: 10),
            _GameCard(
              emoji: '⛽',
              title: 'Tanknadel',
              description: 'Stoppe die Nadel bei Voll!',
              highscore: _hs_fuel > 0 ? '$_hs_fuel Pkt.' : '-',
              onTap: () => _open(const FuelGame()),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final String highscore;
  final VoidCallback onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.highscore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  Text(description,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Highscore',
                    style: TextStyle(color: Colors.white30, fontSize: 10)),
                Text(highscore,
                    style: const TextStyle(
                        color: AppColors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
