import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class VerkehrScreen extends StatefulWidget {
  const VerkehrScreen({super.key});

  @override
  State<VerkehrScreen> createState() => _VerkehrScreenState();
}

class _VerkehrScreenState extends State<VerkehrScreen> {
  static const _apiKey = 'zX9aptgGMDUF3melZZ7FE7wGxzKSPjQ9';
  static const _radiusKm = 20.0;

  List<_Incident>? _incidents;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      final pos = await _getPosition();
      final bbox = _bbox(pos.latitude, pos.longitude, _radiusKm);
      final url = Uri.parse(
        'https://api.tomtom.com/traffic/services/5/incidentDetails'
        '?key=$_apiKey'
        '&bbox=${bbox[0]},${bbox[1]},${bbox[2]},${bbox[3]}'
        '&language=de-DE'
        '&timeValidityFilter=present',
      );
      final resp = await http
          .get(url, headers: {'User-Agent': 'MoveBase-App/1.0.5'})
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final list = (data['incidents'] as List? ?? [])
            .map((e) => _Incident.fromJson(e, pos.latitude, pos.longitude))
            .where((i) => i.magnitudeOfDelay > 0)
            .toList()
          ..sort((a, b) => b.magnitudeOfDelay.compareTo(a.magnitudeOfDelay));
        if (mounted) setState(() { _incidents = list; _loading = false; });
      } else if (resp.statusCode == 403) {
        if (mounted) setState(() { _error = 'API-Kontingent erschöpft. Morgen wieder verfügbar.'; _loading = false; });
      } else {
        if (mounted) setState(() { _error = 'Fehler ${resp.statusCode}'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Keine Verbindung möglich.'; _loading = false; });
    }
  }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('GPS deaktiviert');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Standortberechtigung verweigert');
    }
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;
    return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
  }

  List<double> _bbox(double lat, double lon, double radiusKm) {
    final latDelta = radiusKm / 111.0;
    final lonDelta = radiusKm / (111.0 * cos(lat * pi / 180));
    return [lon - lonDelta, lat - latDelta, lon + lonDelta, lat + latDelta];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Verkehr & Staus',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _load,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 52, color: Colors.orange),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }
    if (_incidents == null || _incidents!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
            SizedBox(height: 14),
            Text(
              'Keine Verkehrsstörungen\nim Umkreis von 20 km',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _incidents!.length,
        itemBuilder: (context, i) => _IncidentCard(incident: _incidents![i]),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final _Incident incident;
  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: incident.lat != null
            ? () {
                final url = Uri.parse(
                    'https://maps.google.com/?q=${incident.lat},${incident.lon}');
                launchUrl(url, mode: LaunchMode.externalApplication);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: incident.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(incident.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.description,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (incident.road.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        incident.road,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (incident.delayMin > 0)
                          _Chip('+${incident.delayMin} Min', Colors.red.shade100,
                              Colors.red.shade800),
                        if (incident.distanceKm > 0)
                          _Chip('${incident.distanceKm} km', Colors.blue.shade50,
                              Colors.blue.shade700),
                        _Chip(incident.severityLabel,
                            incident.color.withValues(alpha: 0.15), incident.color),
                      ],
                    ),
                  ],
                ),
              ),
              if (incident.lat != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Chip(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _Incident {
  final String description;
  final String road;
  final int magnitudeOfDelay;
  final int delayMin;
  final double distanceKm;
  final double? lat;
  final double? lon;
  final int eventCode;

  const _Incident({
    required this.description,
    required this.road,
    required this.magnitudeOfDelay,
    required this.delayMin,
    required this.distanceKm,
    required this.lat,
    required this.lon,
    required this.eventCode,
  });

  Color get color {
    switch (magnitudeOfDelay) {
      case 1: return Colors.green.shade600;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      case 4: return Colors.red.shade900;
      default: return Colors.grey;
    }
  }

  String get severityLabel {
    switch (magnitudeOfDelay) {
      case 1: return 'Leicht';
      case 2: return 'Mittel';
      case 3: return 'Schwer';
      case 4: return 'Sehr schwer';
      default: return 'Unbekannt';
    }
  }

  String get icon {
    switch (eventCode) {
      case 1: return '💥';
      case 2: return '🌫️';
      case 3: return '⚠️';
      case 4: return '🌧️';
      case 5: return '🧊';
      case 6: return '🚗';
      case 7: return '🚧';
      case 8: return '🚫';
      case 9: return '🏗️';
      case 10: return '💨';
      case 11: return '🌊';
      case 14: return '🚨';
      default: return '⚠️';
    }
  }

  factory _Incident.fromJson(Map<String, dynamic> json, double userLat, double userLon) {
    final props = (json['properties'] as Map<String, dynamic>?) ?? {};
    final geo = json['geometry'] as Map<String, dynamic>?;

    double? incLat, incLon;
    if (geo != null) {
      final coords = geo['coordinates'] as List?;
      if (coords != null && coords.isNotEmpty) {
        if (geo['type'] == 'Point') {
          incLon = (coords[0] as num).toDouble();
          incLat = (coords[1] as num).toDouble();
        } else if (geo['type'] == 'LineString') {
          final first = coords[0] as List;
          incLon = (first[0] as num).toDouble();
          incLat = (first[1] as num).toDouble();
        } else if (geo['type'] == 'MultiLineString') {
          final firstLine = coords[0] as List;
          final first = firstLine[0] as List;
          incLon = (first[0] as num).toDouble();
          incLat = (first[1] as num).toDouble();
        }
      }
    }

    double distKm = 0;
    if (incLat != null && incLon != null) {
      distKm = _haversineKm(userLat, userLon, incLat, incLon);
    }

    final delaySeconds = (props['delay'] as num?)?.toInt() ?? 0;
    final delayMin = (delaySeconds / 60).round();

    final from = (props['from'] as String?) ?? '';
    final to = (props['to'] as String?) ?? '';
    final road = from.isNotEmpty && to.isNotEmpty
        ? '$from → $to'
        : (from.isNotEmpty ? from : to);

    final events = props['events'] as List? ?? [];
    String desc = '';
    int eventCode = 0;
    if (events.isNotEmpty) {
      final e = events[0] as Map<String, dynamic>;
      desc = (e['description'] as String?) ?? '';
      eventCode = (e['iconCategory'] as num?)?.toInt() ?? 0;
    }
    if (desc.isEmpty) desc = _fallbackLabel(eventCode);

    return _Incident(
      description: desc,
      road: road,
      magnitudeOfDelay: (props['magnitudeOfDelay'] as num?)?.toInt() ?? 0,
      delayMin: delayMin,
      distanceKm: double.parse(distKm.toStringAsFixed(1)),
      lat: incLat,
      lon: incLon,
      eventCode: eventCode,
    );
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static String _fallbackLabel(int code) {
    switch (code) {
      case 1: return 'Unfall';
      case 2: return 'Nebel';
      case 3: return 'Gefährliche Bedingungen';
      case 4: return 'Regen';
      case 5: return 'Glatteis';
      case 6: return 'Stau';
      case 7: return 'Fahrsperre';
      case 8: return 'Straße gesperrt';
      case 9: return 'Baustelle';
      case 10: return 'Sturm';
      case 11: return 'Überschwemmung';
      case 12: return 'Umleitung';
      case 14: return 'Liegengebliebenes Fahrzeug';
      default: return 'Verkehrsstörung';
    }
  }
}
