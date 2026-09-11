import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';

class TankstellenScreen extends StatefulWidget {
  const TankstellenScreen({super.key});

  @override
  State<TankstellenScreen> createState() => _TankstellenScreenState();
}

class _TankstellenScreenState extends State<TankstellenScreen>
    with SingleTickerProviderStateMixin {
  static const _fuelTypes = ['SUP', 'DIE', 'GAS'];
  static const _fuelLabels = ['Super 95', 'Diesel', 'Gas/LPG'];
  static const _fuelIcons = [
    Icons.local_gas_station,
    Icons.opacity,
    Icons.gas_meter_outlined,
  ];

  late final TabController _tabCtrl;

  bool _loading = true;
  String? _error;
  double? _lat, _lng;

  final Map<String, List<_Station>> _cache = {};
  bool _sortByPrice = true;
  final Set<String> _loadingTypes = {};

  List<_EvStation>? _evStations;
  bool _evLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) setState(() {});
      });
    _init();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
      _cache.clear();
      _evStations = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('GPS deaktiviert. Bitte GPS einschalten.');
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Standortberechtigung verweigert.');
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _lat = last.latitude;
        _lng = last.longitude;
        if (mounted) setState(() => _loading = false);
        await Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
        _refreshPosition();
      } else {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.low));
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (mounted) setState(() => _loading = false);
        await Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium));
      if ((_lat! - pos.latitude).abs() > 0.002 ||
          (_lng! - pos.longitude).abs() > 0.002) {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _cache.clear();
        _evStations = null;
        await Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
      }
    } catch (_) {}
  }

  Future<void> _loadFuel(String fuelType) async {
    if (_cache.containsKey(fuelType)) return;
    if (_loadingTypes.contains(fuelType)) return;
    _loadingTypes.add(fuelType);
    try {
      final uri = Uri.parse(
          'https://api.e-control.at/sprit/1.0/search/gas-stations/by-address'
          '?latitude=$_lat&longitude=$_lng&fuelType=$fuelType&includeClosed=false');
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 10),
      );
      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes);
        final List<dynamic> raw = jsonDecode(body);
        _cache[fuelType] =
            raw.map((j) => _Station.fromJson(j, fuelType)).toList();
      }
    } catch (_) {}
    _loadingTypes.remove(fuelType);
    if (mounted) setState(() {});
  }

  Future<void> _loadEv() async {
    if (_evStations != null || _evLoading) return;
    _evLoading = true;
    if (mounted) setState(() {});
    try {
      final uri = Uri.parse(
          'https://api.openchargemap.io/v3/poi/'
          '?output=json'
          '&latitude=$_lat'
          '&longitude=$_lng'
          '&maxresults=50'
          '&distance=15'
          '&distanceunit=KM'
          '&countrycode=AT');
      final resp = await http.get(uri, headers: {
        'Accept': 'application/json',
        'X-API-Key': '3f32206c-414e-481d-942f-ac1fdf352350',
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final List<dynamic> raw =
            jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
        final stations = raw
            .map((j) => _EvStation.fromOcm(j as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));
        _evStations = stations;
      } else {
        _evStations = [];
      }
    } catch (_) {
      _evStations = [];
    }
    _evLoading = false;
    if (mounted) setState(() {});
  }

  List<_Station> _sorted(String fuelType) {
    final list = List<_Station>.from(_cache[fuelType] ?? []);
    if (_sortByPrice) {
      list.sort((a, b) {
        if (a.price == null && b.price == null) return 0;
        if (a.price == null) return 1;
        if (b.price == null) return -1;
        return a.price!.compareTo(b.price!);
      });
    } else {
      list.sort((a, b) => a.distance.compareTo(b.distance));
    }
    return list.take(30).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tankstellen',
          style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.navy),
            onPressed: () {
              _cache.clear();
              _init();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.orange,
          labelColor: AppColors.navy,
          unselectedLabelColor: Colors.grey,
          onTap: (i) {
            if (i < 3) {
              final ft = _fuelTypes[i];
              if (!_cache.containsKey(ft) && _lat != null) _loadFuel(ft);
            } else {
              if (_evStations == null && _lat != null) _loadEv();
            }
          },
          tabs: [
            ...List.generate(
                3,
                (i) => Tab(
                      icon: Icon(_fuelIcons[i], size: 18),
                      text: _fuelLabels[i],
                    )),
            const Tab(icon: Icon(Icons.ev_station, size: 18), text: 'Elektro'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy))
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    if (_tabCtrl.index < 3) _buildSortBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          ...List.generate(3, (i) {
                            final ft = _fuelTypes[i];
                            final stations = _sorted(ft);
                            if (!_cache.containsKey(ft)) {
                              return const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.navy));
                            }
                            if (stations.isEmpty) {
                              return const Center(
                                child: Text('Keine Tankstellen gefunden.'),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              itemCount: stations.length,
                              itemBuilder: (_, idx) => _StationCard(
                                station: stations[idx],
                                rank: _sortByPrice ? idx + 1 : null,
                                fuelLabel: _fuelLabels[i],
                              ),
                            );
                          }),
                          // Elektro Tab
                          _evLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.navy))
                              : (_evStations == null || _evStations!.isEmpty)
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.ev_station,
                                                size: 48,
                                                color: Color(0xFF2E7D32)),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Ladesäulen-Daten\nkurz nicht verfügbar.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Direkt in Google Maps suchen:',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.grey),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                final url = Uri.parse(
                                                    'https://www.google.com/maps/search/Elektro+Ladestation/@$_lat,$_lng,14z');
                                                launchUrl(url,
                                                    mode: LaunchMode
                                                        .externalApplication);
                                              },
                                              icon: const Icon(
                                                  Icons.map_outlined),
                                              label: const Text(
                                                  'In Google Maps öffnen'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF2E7D32),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            TextButton.icon(
                                              onPressed: () {
                                                _evStations = null;
                                                _loadEv();
                                              },
                                              icon: const Icon(Icons.refresh,
                                                  size: 16),
                                              label:
                                                  const Text('Erneut versuchen'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      itemCount: _evStations!.length,
                                      itemBuilder: (_, idx) =>
                                          _EvStationCard(
                                              station: _evStations![idx]),
                                    ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Sortieren:',
              style: TextStyle(fontSize: 13, color: AppColors.grey)),
          const SizedBox(width: 10),
          _SortChip(
            label: 'Preis',
            selected: _sortByPrice,
            onTap: () => setState(() => _sortByPrice = true),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Entfernung',
            selected: !_sortByPrice,
            onTap: () => setState(() => _sortByPrice = false),
          ),
          const Spacer(),
          if (_lat != null)
            Text(
              '~15 km',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined,
                size: 48, color: AppColors.navy),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : Colors.black87,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final _Station station;
  final int? rank;
  final String fuelLabel;

  const _StationCard({
    required this.station,
    required this.rank,
    required this.fuelLabel,
  });

  String get _distanceText {
    if (station.distance < 1) {
      return '${(station.distance * 1000).round()} m';
    }
    return '${station.distance.toStringAsFixed(1)} km';
  }

  Color get _priceColor {
    if (station.price == null) return Colors.grey;
    if (station.price! < 1.50) return const Color(0xFF2E7D32);
    if (station.price! < 1.80) return const Color(0xFFF57F17);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openMaps,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (rank != null && rank! <= 3)
                _MedalBadge(rank: rank!)
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_gas_station,
                      color: AppColors.navy, size: 20),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.navy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(station.address,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.near_me_outlined,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text(_distanceText,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (station.price != null)
                    Text(
                      '€ ${station.price!.toStringAsFixed(3)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: _priceColor),
                    )
                  else
                    Text('–',
                        style: TextStyle(fontSize: 17, color: Colors.grey[400])),
                  Text(fuelLabel,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Icon(Icons.open_in_new, size: 15, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMaps() {
    HapticFeedback.lightImpact();
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${station.lat},${station.lng}'
        '&travelmode=driving');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

class _MedalBadge extends StatelessWidget {
  final int rank;
  const _MedalBadge({required this.rank});

  static const _colors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _colors[rank - 1].withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _colors[rank - 1], width: 1.5),
      ),
      child: Center(
        child: Text('$rank',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _colors[rank - 1])),
      ),
    );
  }
}

// ─── EV Charging Station Model ───────────────────────────────────────────────

class _EvStation {
  final String name;
  final double lat, lng;
  final double distance;
  final int? capacity;
  final List<String> socketTypes;

  _EvStation({
    required this.name,
    required this.lat,
    required this.lng,
    required this.distance,
    this.capacity,
    required this.socketTypes,
  });

  factory _EvStation.fromOcm(Map<String, dynamic> j) {
    final addr = j['AddressInfo'] as Map<String, dynamic>? ?? {};
    final conns = j['Connections'] as List<dynamic>? ?? [];

    final lat = (addr['Latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (addr['Longitude'] as num?)?.toDouble() ?? 0.0;
    final dist = (addr['Distance'] as num?)?.toDouble() ?? 0.0;
    final name = addr['Title'] as String? ?? 'Ladestation';
    final capacity = j['NumberOfPoints'] as int?;

    final sockets = <String>{};
    for (final conn in conns) {
      final type = ((conn['ConnectionType'] as Map<String, dynamic>?)?['Title']
              as String?) ??
          '';
      if (type.contains('Type 2') || type.contains('IEC 62196-2')) {
        sockets.add('Type 2');
      } else if (type.contains('CCS') || type.contains('Combo')) {
        sockets.add('CCS');
      } else if (type.contains('CHAdeMO')) {
        sockets.add('CHAdeMO');
      } else if (type.contains('Schuko') || type.contains('CEE 7')) {
        sockets.add('Schuko');
      } else if (type.contains('Type 1') || type.contains('J1772')) {
        sockets.add('Type 1');
      }
    }

    return _EvStation(
      name: name,
      lat: lat,
      lng: lng,
      distance: dist,
      capacity: capacity,
      socketTypes: sockets.toList(),
    );
  }
}

// ─── EV Station Card ─────────────────────────────────────────────────────────

class _EvStationCard extends StatelessWidget {
  final _EvStation station;
  const _EvStationCard({required this.station});

  String get _distanceText {
    if (station.distance < 1) return '${(station.distance * 1000).round()} m';
    return '${station.distance.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          final url = Uri.parse(
              'https://www.google.com/maps/dir/?api=1'
              '&destination=${station.lat},${station.lng}'
              '&travelmode=driving');
          launchUrl(url, mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF2E7D32).withOpacity(0.4)),
                ),
                child: const Icon(Icons.ev_station,
                    color: Color(0xFF2E7D32), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.navy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.near_me_outlined,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text(_distanceText,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500])),
                      if (station.capacity != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.power, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text('${station.capacity} Ladepunkte',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ]),
                    if (station.socketTypes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: station.socketTypes
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF2E7D32)
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text(s,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w500)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 15, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fuel Station Model ───────────────────────────────────────────────────────

class _Station {
  final String name;
  final String address;
  final double lat, lng;
  final double distance;
  final double? price;

  _Station({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distance,
    this.price,
  });

  factory _Station.fromJson(Map<String, dynamic> j, String fuelType) {
    final loc = j['location'] as Map<String, dynamic>? ?? {};
    final addr = j['address'] as Map<String, dynamic>? ?? {};
    final prices = j['prices'] as List<dynamic>? ?? [];

    final stLat = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
    final stLng = (loc['longitude'] as num?)?.toDouble() ?? 0.0;

    double? price;
    for (final p in prices) {
      if ((p['fuelType'] as String?)?.toUpperCase() == fuelType.toUpperCase()) {
        price = (p['amount'] as num?)?.toDouble();
        break;
      }
    }
    if (price == null && prices.isNotEmpty) {
      price = (prices[0]['amount'] as num?)?.toDouble();
    }

    final street = addr['street'] as String? ?? '';
    final city = addr['city'] as String? ?? '';
    final plz = addr['postalCode'] as String? ?? '';
    final addressStr =
        [street, '$plz $city'.trim()].where((s) => s.isNotEmpty).join(', ');

    final distRaw = (j['distance'] as num?)?.toDouble();
    final dist = distRaw ?? 0.0;

    return _Station(
      name: j['name'] as String? ?? 'Tankstelle',
      address: addressStr,
      lat: stLat,
      lng: stLng,
      distance: dist,
      price: price,
    );
  }
}
