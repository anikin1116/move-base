import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class VerkehrScreen extends StatefulWidget {
  const VerkehrScreen({super.key});

  @override
  State<VerkehrScreen> createState() => _VerkehrScreenState();
}

class _VerkehrScreenState extends State<VerkehrScreen> {
  static const _apiKey = 'zX9aptgGMDUF3melZZ7FE7wGxzKSPjQ9';
  static const _radiusKm = 40.0;

  List<_Incident>? _incidents;
  List<_Incident>? _filtered;
  final Set<int> _activeFilters = {};
  bool _loading = false;
  String? _error;
  double? _userLat, _userLon;
  String? _searchCityName;
  bool _usingSearch = false;

  @override
  void initState() {
    super.initState();
    _load();
    _maybeReview('mb_vk_opens');
  }

  Future<void> _maybeReview(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(key) ?? 0) + 1;
      await prefs.setInt(key, count);
      if (count % 5 == 0) {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_loading) return;
    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      double lat, lon;
      if (_usingSearch && _userLat != null && _userLon != null) {
        lat = _userLat!;
        lon = _userLon!;
      } else {
        final pos = await _getPosition();
        lat = pos.latitude; lon = pos.longitude;
        if (mounted) setState(() { _userLat = lat; _userLon = lon; });
      }
      final bbox = _bbox(lat, lon, _radiusKm);
      final url = Uri.parse(
        'https://api.tomtom.com/traffic/services/5/incidentDetails'
        '?key=$_apiKey'
        '&bbox=${bbox[0]},${bbox[1]},${bbox[2]},${bbox[3]}'
        '&language=de-DE'
        '&timeValidityFilter=present'
        '&fields={incidents{geometry{type,coordinates},properties{iconCategory,magnitudeOfDelay,from,to,roadNumbers,delay,events{description,iconCategory}}}}',
      );
      final resp = await http
          .get(url, headers: {'User-Agent': 'MoveBase-App/2.0.0'})
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final list = (data['incidents'] as List? ?? [])
            .map((e) => _Incident.fromJson(e, lat, lon))
            .where((i) => i.distanceKm <= _radiusKm && i.eventCode > 0)
            .toList()
          ..sort((a, b) {
            final byPrio = b.priority.compareTo(a.priority);
            if (byPrio != 0) return byPrio;
            return a.distanceKm.compareTo(b.distanceKm);
          });
        if (mounted) setState(() { _incidents = list; _filtered = list; _loading = false; });
      } else if (resp.statusCode == 403) {
        if (mounted) setState(() { _error = 'API-Kontingent erschöpft. Morgen wieder verfügbar.'; _loading = false; });
      } else {
        if (mounted) setState(() { _error = 'Fehler ${resp.statusCode}'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Keine Verbindung möglich.'; _loading = false; });
    }
  }

  Future<void> _selectCity(double lat, double lon, String name) async {
    _userLat = lat;
    _userLon = lon;
    _searchCityName = name;
    _usingSearch = true;
    _activeFilters.clear();
    await _load();
  }

  Future<(List<_Incident>, double, double)> _selectCityForMap(double lat, double lon, String name) async {
    await _selectCity(lat, lon, name);
    return (_incidents ?? [], _userLat!, _userLon!);
  }

  Future<(List<_Incident>, double, double)> _resetToGpsForMap() async {
    _usingSearch = false;
    _searchCityName = null;
    _activeFilters.clear();
    await _load();
    return (_incidents ?? [], _userLat ?? 48.2082, _userLon ?? 16.3738);
  }

  Future<List<_Incident>> _reloadForMap() async {
    await _load();
    return _incidents ?? [];
  }

  void _openCitySearch() {
    final ctrl = TextEditingController();
    final List<Map<String, dynamic>> suggestions = [];
    bool searching = false;
    Timer? debounce;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> fetchSuggestions(String q) async {
            if (q.length < 2) {
              setModalState(() { suggestions.clear(); searching = false; });
              return;
            }
            setModalState(() => searching = true);
            try {
              final url = Uri.parse(
                'https://nominatim.openstreetmap.org/search'
                '?q=${Uri.encodeComponent(q)}&format=json&limit=6&addressdetails=1',
              );
              final resp = await http.get(url, headers: {
                'User-Agent': 'MoveBase/1.0 (contact@movebase.eu)',
              }).timeout(const Duration(seconds: 5));
              if (resp.statusCode == 200) {
                final data = jsonDecode(resp.body) as List;
                setModalState(() {
                  suggestions..clear()..addAll(data.cast<Map<String, dynamic>>());
                  searching = false;
                });
              } else {
                setModalState(() => searching = false);
              }
            } catch (_) {
              setModalState(() => searching = false);
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ort suchen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Stadt, Ort oder PLZ…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) {
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 250),
                          () => fetchSuggestions(v.trim()));
                    },
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = suggestions[i];
                          final parts = (s['display_name'] as String).split(',');
                          final title = parts.first.trim();
                          final subtitle = parts.skip(1).take(2).map((e) => e.trim()).join(', ');
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined,
                                size: 20, color: AppColors.navy),
                            title: Text(title,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: subtitle.isNotEmpty
                                ? Text(subtitle, style: const TextStyle(fontSize: 11))
                                : null,
                            onTap: () {
                              debounce?.cancel();
                              Navigator.pop(ctx);
                              _selectCity(
                                double.parse(s['lat'] as String),
                                double.parse(s['lon'] as String),
                                title,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () { debounce?.cancel(); Navigator.pop(ctx); },
                      child: const Text('Abbrechen'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

  void _toggleFilter(int code) {
    setState(() {
      if (_activeFilters.contains(code)) {
        _activeFilters.remove(code);
      } else {
        _activeFilters.add(code);
      }
      _filtered = _activeFilters.isEmpty
          ? _incidents
          : _incidents?.where((i) => _activeFilters.contains(i.eventCode)).toList();
    });
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
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _openCitySearch,
          ),
          if (_searchCityName != null)
            IconButton(
              icon: const Icon(Icons.gps_fixed, color: Color(0xFFE8A020)),
              tooltip: 'Zurück zu meinem Standort',
              onPressed: () {
                _usingSearch = false;
                _searchCityName = null;
                _activeFilters.clear();
                _load();
              },
            ),
          if (!_loading && _incidents != null && _incidents!.isNotEmpty && _userLat != null)
            IconButton(
              icon: const Icon(Icons.map_outlined, color: Colors.white),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _VerkehrMapScreen(
                    incidents: _incidents!,
                    userLat: _userLat!,
                    userLon: _userLon!,
                    initialSearchCityName: _searchCityName,
                    onSearchCity: (lat, lon, name) => _selectCityForMap(lat, lon, name),
                    onResetToGps: () => _resetToGpsForMap(),
                    onReload: () => _reloadForMap(),
                  ),
                ));
                if (mounted) setState(() {});
              },
            ),
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
              'Keine Verkehrsstörungen\nim Umkreis von 40 km',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }
    final categories = _incidents!.map((i) => i.eventCode).toSet().toList()..sort();
    final display = _filtered ?? _incidents!;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: categories.map((code) {
              final active = _activeFilters.contains(code);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_Incident.categoryLabel(code), style: const TextStyle(fontSize: 12)),
                  selected: active,
                  onSelected: (_) => _toggleFilter(code),
                  selectedColor: AppColors.navy.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.navy,
                  side: BorderSide(color: active ? AppColors.navy : Colors.grey.shade300),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: display.isEmpty
                ? const Center(child: Text('Keine Einträge für diesen Filter.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: display.length,
                    itemBuilder: (context, i) => _IncidentCard(incident: display[i]),
                  ),
          ),
        ),
      ],
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
                        if (incident.severityLabel.isNotEmpty)
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

  int get priority {
    switch (eventCode) {
      case 1: return 5;
      case 8: return 4;
      case 7: return 3;
      case 6: return 2;
      case 9: return 1;
      default: return 0;
    }
  }

  Color get color {
    switch (magnitudeOfDelay) {
      case 1: return Colors.green.shade600;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      case 4: return Colors.red.shade900;
      default:
        switch (eventCode) {
          case 1: return Colors.red;
          case 8: return Colors.red.shade900;
          case 7: return Colors.orange;
          case 6: return Colors.orange;
          default: return Colors.amber.shade700;
        }
    }
  }

  String get severityLabel {
    switch (magnitudeOfDelay) {
      case 1: return 'Leichte Verzögerung';
      case 2: return 'Mittlere Verzögerung';
      case 3: return 'Starke Verzögerung';
      case 4: return 'Sehr starke Verzögerung';
      default: return '';
    }
  }

  static String categoryLabel(int code) {
    switch (code) {
      case 1: return 'Unfall';
      case 2: return 'Nebel';
      case 3: return 'Gefährlich';
      case 4: return 'Regen';
      case 5: return 'Glatteis';
      case 6: return 'Stau';
      case 7: return 'Fahrsperre';
      case 8: return 'Gesperrt';
      case 9: return 'Baustelle';
      case 10: return 'Sturm';
      case 11: return 'Überschwemmung';
      case 14: return 'Panne';
      default: return 'Sonstiges';
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

    final eventCode = (props['iconCategory'] as num?)?.toInt() ?? 0;
    final magnitudeOfDelay = (props['magnitudeOfDelay'] as num?)?.toInt() ?? 0;
    final delaySeconds = (props['delay'] as num?)?.toInt() ?? 0;
    final delayMin = (delaySeconds / 60).round();

    final events = props['events'] as List? ?? [];
    String desc = '';
    if (events.isNotEmpty) {
      desc = (events[0] as Map<String, dynamic>)['description'] as String? ?? '';
    }
    if (desc.isEmpty) desc = _fallbackLabel(eventCode);

    final from = (props['from'] as String?) ?? '';
    final to = (props['to'] as String?) ?? '';
    final roadNums = (props['roadNumbers'] as List? ?? []).map((e) => e.toString()).toList();
    String road = '';
    if (roadNums.isNotEmpty) road = roadNums.first;
    if (from.isNotEmpty && to.isNotEmpty) {
      road = road.isNotEmpty ? '$road: $from → $to' : '$from → $to';
    } else if (from.isNotEmpty) {
      road = road.isNotEmpty ? '$road: $from' : from;
    }

    return _Incident(
      description: desc,
      road: road,
      magnitudeOfDelay: magnitudeOfDelay,
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
      case 8: return 'Straße gesperrt';  // keep existing
      case 9: return 'Baustelle';
      case 10: return 'Sturm';
      case 11: return 'Überschwemmung';
      case 12: return 'Umleitung';
      case 14: return 'Liegengebliebenes Fahrzeug';
      default: return 'Verkehrsstörung';
    }
  }
}

// ─── Verkehr Map Screen ───────────────────────────────────────────────────────

class _VerkehrMapScreen extends StatefulWidget {
  final List<_Incident> incidents;
  final double userLat, userLon;
  final Future<(List<_Incident>, double, double)> Function(double, double, String)? onSearchCity;
  final Future<(List<_Incident>, double, double)> Function()? onResetToGps;
  final Future<List<_Incident>> Function()? onReload;
  final String? initialSearchCityName;
  const _VerkehrMapScreen({
    required this.incidents,
    required this.userLat,
    required this.userLon,
    this.onSearchCity,
    this.onResetToGps,
    this.onReload,
    this.initialSearchCityName,
  });

  @override
  State<_VerkehrMapScreen> createState() => _VerkehrMapScreenState();
}

class _VerkehrMapScreenState extends State<_VerkehrMapScreen> {
  _Incident? _selected;
  final Set<int> _filters = {};
  late List<_Incident> _incidents;
  late double _centerLat, _centerLon;
  String? _searchCityName;
  bool _reloading = false;
  final _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    _incidents = widget.incidents;
    _centerLat = widget.userLat;
    _centerLon = widget.userLon;
    _searchCityName = widget.initialSearchCityName;
  }

  List<_Incident> get _visible => _filters.isEmpty
      ? _incidents.where((i) => i.lat != null).toList()
      : _incidents.where((i) => i.lat != null && _filters.contains(i.eventCode)).toList();

  void _openMapSearch() {
    final ctrl = TextEditingController();
    final List<Map<String, dynamic>> suggestions = [];
    bool searching = false;
    Timer? debounce;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> fetchSuggestions(String q) async {
            if (q.length < 2) {
              setModalState(() { suggestions.clear(); searching = false; });
              return;
            }
            setModalState(() => searching = true);
            try {
              final url = Uri.parse(
                'https://nominatim.openstreetmap.org/search'
                '?q=${Uri.encodeComponent(q)}&format=json&limit=6&addressdetails=1',
              );
              final resp = await http.get(url, headers: {
                'User-Agent': 'MoveBase/1.0 (contact@movebase.eu)',
              }).timeout(const Duration(seconds: 5));
              if (resp.statusCode == 200) {
                final data = jsonDecode(resp.body) as List;
                setModalState(() {
                  suggestions..clear()..addAll(data.cast<Map<String, dynamic>>());
                  searching = false;
                });
              } else {
                setModalState(() => searching = false);
              }
            } catch (_) {
              setModalState(() => searching = false);
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ort suchen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Stadt, Ort oder PLZ…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) {
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 250),
                          () => fetchSuggestions(v.trim()));
                    },
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = suggestions[i];
                          final parts = (s['display_name'] as String).split(',');
                          final title = parts.first.trim();
                          final subtitle = parts.skip(1).take(2).map((e) => e.trim()).join(', ');
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined,
                                size: 20, color: AppColors.navy),
                            title: Text(title,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: subtitle.isNotEmpty
                                ? Text(subtitle, style: const TextStyle(fontSize: 11))
                                : null,
                            onTap: () async {
                              debounce?.cancel();
                              Navigator.pop(ctx);
                              if (widget.onSearchCity == null) return;
                              final lat = double.parse(s['lat'] as String);
                              final lon = double.parse(s['lon'] as String);
                              setState(() { _reloading = true; _selected = null; });
                              try {
                                final (fresh, nlat, nlon) = await widget.onSearchCity!(lat, lon, title);
                                if (mounted) {
                                  setState(() {
                                    _incidents = fresh;
                                    _centerLat = nlat; _centerLon = nlon;
                                    _searchCityName = title;
                                    _filters.clear();
                                    _reloading = false;
                                  });
                                  _mapCtrl.move(LatLng(nlat, nlon), 11);
                                }
                              } catch (_) {
                                if (mounted) setState(() => _reloading = false);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () { debounce?.cancel(); Navigator.pop(ctx); },
                      child: const Text('Abbrechen'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final allCodes = _incidents.map((i) => i.eventCode).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: _searchCityName != null
            ? Row(children: [
                const Icon(Icons.location_city, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(_searchCityName!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis)),
              ])
            : const Text('Verkehrskarte',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _openMapSearch,
          ),
          if (_searchCityName != null)
            IconButton(
              icon: const Icon(Icons.gps_fixed, color: Color(0xFFE8A020)),
              tooltip: 'Zurück zu meinem Standort',
              onPressed: () async {
                if (widget.onResetToGps == null) return;
                setState(() { _reloading = true; _selected = null; });
                try {
                  final (fresh, lat, lon) = await widget.onResetToGps!();
                  if (mounted) {
                    setState(() {
                      _incidents = fresh; _centerLat = lat; _centerLon = lon;
                      _searchCityName = null; _filters.clear(); _reloading = false;
                    });
                    _mapCtrl.move(LatLng(lat, lon), 11);
                  }
                } catch (_) {
                  if (mounted) setState(() => _reloading = false);
                }
              },
            ),
          if (_reloading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () async {
                if (widget.onReload == null) return;
                setState(() { _reloading = true; _selected = null; });
                try {
                  final fresh = await widget.onReload!();
                  if (mounted) setState(() { _incidents = fresh; _reloading = false; });
                } catch (_) {
                  if (mounted) setState(() => _reloading = false);
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: LatLng(_centerLat, _centerLon),
              initialZoom: 11,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'eu.movebase.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_centerLat, _centerLon),
                    width: 20, height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _searchCityName != null ? AppColors.navy : Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: _searchCityName != null
                          ? const Icon(Icons.location_city, color: Colors.white, size: 12)
                          : null,
                    ),
                  ),
                  ...visible.map((i) => Marker(
                    point: LatLng(i.lat!, i.lon!),
                    width: 36, height: 36,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: i.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Center(
                          child: Text(i.icon, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ],
          ),
          // Filter chips
          Positioned(
            top: 8, left: 8, right: 8,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allCodes.map((code) {
                      final active = _filters.contains(code);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FilterChip(
                          label: Text(_Incident.categoryLabel(code),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: active ? Colors.white : Colors.black87)),
                          selected: active,
                          selectedColor: AppColors.navy,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (_) => setState(() {
                            if (active) _filters.remove(code);
                            else _filters.add(code);
                            _selected = null;
                          }),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          if (_selected != null)
            Positioned(
              left: 12, right: 12, bottom: 24,
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Text(_selected!.icon, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_selected!.description,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                        GestureDetector(
                          onTap: () => setState(() => _selected = null),
                          child: const Icon(Icons.close, size: 20, color: Colors.grey),
                        ),
                      ]),
                      if (_selected!.road.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_selected!.road,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ],
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: [
                        if (_selected!.delayMin > 0)
                          _Chip('+${_selected!.delayMin} Min',
                              Colors.red.shade100, Colors.red.shade800),
                        if (_selected!.severityLabel.isNotEmpty)
                          _Chip(_selected!.severityLabel,
                              _selected!.color.withValues(alpha: 0.15), _selected!.color),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
