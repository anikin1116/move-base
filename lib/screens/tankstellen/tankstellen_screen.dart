import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../generated/l10n/app_localizations.dart';
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
  final Set<String> _evFilter = {};
  String? _searchCityName;
  bool _usingSearch = false;
  String? _searchCountryCode;
  Map<String, double?> _countryAvgPrices = {};
  bool _avgPriceLoading = false;
  bool _slowLoading = false;
  Timer? _slowLoadTimer;
  bool _slowAvgLoading = false;
  Timer? _slowAvgTimer;
  Future<void>? _overpassFuture;
  bool _priceApiDown = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) setState(() {});
      });
    _init();
    _maybeReview('mb_ts_opens');
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

  @override
  void dispose() {
    _tabCtrl.dispose();
    _slowLoadTimer?.cancel();
    _slowAvgTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _usingSearch = false;
    _searchCityName = null;
    _searchCountryCode = null;
    _countryAvgPrices = {};
    _avgPriceLoading = false;
    _loadingTypes.clear();
    _overpassFuture = null;
    _priceApiDown = false;
    setState(() {
      _loading = true;
      _error = null;
      _cache.clear();
      _evStations = null;
      _evLoading = false;
      _slowLoading = false;
    });
    _slowLoadTimer?.cancel();
    _slowLoadTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _slowLoading = true);
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(AppLocalizations.of(context).tsGpsDisabled);
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception(AppLocalizations.of(context).tsLocationDenied);
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _lat = last.latitude;
        _lng = last.longitude;
        _slowLoadTimer?.cancel();
        if (mounted) setState(() { _loading = false; _slowLoading = false; });
        await Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
        _refreshPosition();
      } else {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.low));
        _lat = pos.latitude;
        _lng = pos.longitude;
        _slowLoadTimer?.cancel();
        if (mounted) setState(() { _loading = false; _slowLoading = false; });
        await Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
      }
    } catch (e) {
      _slowLoadTimer?.cancel();
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
          _slowLoading = false;
        });
      }
    }
  }

  Future<void> _refreshPosition() async {
    if (_usingSearch) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium));
      if (_usingSearch) return; // User könnte zwischenzeitlich Stadtsuche gestartet haben
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
    if (_usingSearch && _searchCountryCode != null && _searchCountryCode != 'at') {
      if (_searchCountryCode == 'fr') {
        await _loadFuelFrance(fuelType);
      } else if (_searchCountryCode == 'de') {
        await _loadFuelTankerKoenig(fuelType);
      } else {
        await _loadFuelOverpass(fuelType);
      }
      return;
    }
    _loadingTypes.add(fuelType);
    bool gotData = false;
    try {
      // 1. WKO Spritpreisrechner (primär)
      final wkoUri = Uri.parse(
          'https://www.spritpreisrechner.at/ts/public/search/gas-stations/by-address'
          '?latitude=$_lat&longitude=$_lng&fuelType=$fuelType&includeClosed=false');
      final wkoResp = await http
          .get(wkoUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (wkoResp.statusCode == 200) {
        final body = utf8.decode(wkoResp.bodyBytes);
        final List<dynamic> raw = jsonDecode(body);
        _cache[fuelType] = raw.map((j) => _Station.fromJson(j, fuelType)).toList();
        gotData = true;
      }
    } catch (_) {}
    if (!gotData) {
      try {
        // 2. e-control (sekundär)
        final uri = Uri.parse(
            'https://api.e-control.at/sprit/1.0/search/gas-stations/by-address'
            '?latitude=$_lat&longitude=$_lng&fuelType=$fuelType&includeClosed=false');
        final resp = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final body = utf8.decode(resp.bodyBytes);
          final List<dynamic> raw = jsonDecode(body);
          _cache[fuelType] = raw.map((j) => _Station.fromJson(j, fuelType)).toList();
          gotData = true;
        }
      } catch (_) {}
    }
    _loadingTypes.remove(fuelType);
    if (!gotData) {
      // 3. Overpass-Fallback (keine Preise)
      if (mounted) setState(() => _priceApiDown = true);
      await _loadFuelOverpass(fuelType);
      return;
    }
    _cache.putIfAbsent(fuelType, () => []);
    if (mounted) setState(() {});
  }

  Future<List<_Station>?> _fetchOverpassParallel(String encoded, double userLat, double userLng) async {
    final completer = Completer<List<_Station>?>();
    var remaining = _overpassHosts.length;
    final deadline = Timer(const Duration(seconds: 7), () {
      if (!completer.isCompleted) completer.complete(null);
    });
    for (final host in _overpassHosts) {
      (() async {
        try {
          final r = await http.get(
            Uri.parse('$host?data=$encoded'),
            headers: {'Accept': 'application/json', 'User-Agent': 'MoveBase-App/1.0'},
          ).timeout(const Duration(seconds: 8));
          if (r.statusCode == 200) {
            final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
            final parsed = (data['elements'] as List<dynamic>? ?? [])
                .map((e) => _Station.fromOsm(e as Map<String, dynamic>, userLat, userLng))
                .toList()..sort((a, b) => a.distance.compareTo(b.distance));
            if (parsed.isNotEmpty && !completer.isCompleted) {
              deadline.cancel();
              completer.complete(parsed);
              return;
            }
          }
        } catch (_) {}
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          deadline.cancel();
          completer.complete(null);
        }
      })();
    }
    return completer.future;
  }

  Future<void> _loadFuelOverpass(String fuelType) async {
    if (_cache.containsKey(fuelType)) return;
    for (final ft in _fuelTypes) {
      if (_cache.containsKey(ft)) { _cache[fuelType] = _cache[ft]!; if (mounted) setState(() {}); return; }
    }
    _overpassFuture ??= _doLoadFuelOverpass();
    await _overpassFuture;
    _cache.putIfAbsent(fuelType, () {
      for (final ft in _fuelTypes) { if (_cache.containsKey(ft)) return _cache[ft]!; }
      return [];
    });
    if (mounted) setState(() {});
  }

  Future<void> _doLoadFuelOverpass() async {
    final encoded = Uri.encodeQueryComponent('[out:json];(node["amenity"="fuel"](around:15000,$_lat,$_lng);way["amenity"="fuel"](around:15000,$_lat,$_lng););out center;');
    final capturedLat = _lat!;
    final capturedLng = _lng!;

    var stations = await _fetchOverpassParallel(encoded, capturedLat, capturedLng);
    // Wenn alle Hosts leer antworteten (Ratelimit), einmal nach 2 s wiederholen
    if (stations == null && mounted && _lat == capturedLat && _lng == capturedLng) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _lat == capturedLat && _lng == capturedLng) {
        stations = await _fetchOverpassParallel(encoded, capturedLat, capturedLng);
      }
    }

    if (!mounted || _lat != capturedLat || _lng != capturedLng) return;
    final result = stations ?? <_Station>[];
    for (final ft in _fuelTypes) { _cache[ft] = result; }
    if (mounted) setState(() {});
  }

  // TankerKönig API-Key (nur Deutschland) – echten Key eintragen:
  // https://creativecommons.tankerkoenig.de
  // Lizenz: CC BY 4.0 – Namensnennung erforderlich (www.tankerkoenig.de), auch im Store-Text
  static const _tankerKoenigKey = '8fc74f15-4a91-4b21-b448-aa22c65aa206';

  Future<void> _loadFuelTankerKoenig(String fuelType) async {
    if (_cache.containsKey(fuelType)) return;
    if (_loadingTypes.contains('_tankerkoenig')) return;
    _loadingTypes.add('_tankerkoenig');
    try {
      final uri = Uri.parse(
        'https://creativecommons.tankerkoenig.de/json/list.php'
        '?lat=$_lat&lng=$_lng&rad=15&sort=dist&type=all&apikey=$_tankerKoenigKey',
      );
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        if (data['ok'] == true) {
          final raw = (data['stations'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          for (final ft in _fuelTypes) {
            _cache[ft] = raw.map((j) => _Station.fromTankerKoenig(j, ft)).toList();
          }
        } else {
          for (final ft in _fuelTypes) { _cache.putIfAbsent(ft, () => []); }
        }
      }
    } catch (_) {
      for (final ft in _fuelTypes) { _cache.putIfAbsent(ft, () => []); }
    }
    _loadingTypes.remove('_tankerkoenig');
    if (mounted) setState(() {});
  }

  // Frankreich: data.economie.gouv.fr – kostenlose Regierungs-API mit Geo-Filter
  Future<void> _loadFuelFrance(String fuelType) async {
    if (_cache.containsKey(fuelType)) return;
    for (final ft in _fuelTypes) {
      if (_cache.containsKey(ft)) { _cache[fuelType] = _cache[ft]!; if (mounted) setState(() {}); return; }
    }
    if (_loadingTypes.contains('_fr')) return;
    _loadingTypes.add('_fr');
    try {
      final lat = _lat!;
      final lng = _lng!;
      final uri = Uri.https(
        'data.economie.gouv.fr',
        '/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records',
        {
          'limit': '100',
          'select': 'id,geom,adresse,ville,gazole_prix,sp95_prix,e10_prix,sp98_prix,gplc_prix',
          'where': "distance(geom, geom'POINT($lng $lat)', 15km)",
          'order_by': "distance(geom, geom'POINT($lng $lat)')",
        },
      );
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'MoveBase-App/1.0'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final results = (data['results'] as List<dynamic>?) ?? [];
        final List<_Station> dieList = [];
        final List<_Station> supList = [];
        final List<_Station> gasList = [];
        for (final r in results) {
          final m = r as Map<String, dynamic>;
          final geom = m['geom'] as Map<String, dynamic>?;
          final stLat = (geom?['lat'] as num?)?.toDouble() ?? 0.0;
          final stLng = (geom?['lon'] as num?)?.toDouble() ?? 0.0;
          final adresse = (m['adresse'] as String?) ?? '';
          final ville = (m['ville'] as String?) ?? '';
          final address = [adresse, ville].where((s) => s.isNotEmpty).join(', ');
          final dLat = (stLat - lat) * math.pi / 180;
          final dLng = (stLng - lng) * math.pi / 180;
          final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(lat * math.pi / 180) * math.cos(stLat * math.pi / 180) *
              math.sin(dLng / 2) * math.sin(dLng / 2);
          final dist = 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
          final gazole = (m['gazole_prix'] as num?)?.toDouble();
          final sup = (m['sp95_prix'] as num?)?.toDouble() ??
                     (m['e10_prix'] as num?)?.toDouble() ??
                     (m['sp98_prix'] as num?)?.toDouble();
          final gplc = (m['gplc_prix'] as num?)?.toDouble();
          final name = adresse.isNotEmpty ? adresse : 'Tankstelle';
          dieList.add(_Station(name: name, address: address, lat: stLat, lng: stLng, distance: dist, price: gazole));
          supList.add(_Station(name: name, address: address, lat: stLat, lng: stLng, distance: dist, price: sup));
          gasList.add(_Station(name: name, address: address, lat: stLat, lng: stLng, distance: dist, price: gplc));
        }
        _cache['DIE'] = dieList;
        _cache['SUP'] = supList;
        _cache['GAS'] = gasList;
      }
    } catch (_) {}
    for (final ft in _fuelTypes) { _cache.putIfAbsent(ft, () => []); }
    _loadingTypes.remove('_fr');
    if (mounted) setState(() {});
  }

  static const _overpassHosts = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  Future<List<_EvStation>?> _fetchEvParallel(double capLat, double capLng) async {
    final completer = Completer<List<_EvStation>?>();
    var remaining = 1 + _overpassHosts.length;
    final deadline = Timer(const Duration(seconds: 7), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    void onResult(List<_EvStation>? result) {
      if (completer.isCompleted) return;
      if (result != null && result.isNotEmpty) {
        deadline.cancel();
        completer.complete(result);
      } else {
        remaining--;
        if (remaining == 0) {
          deadline.cancel();
          completer.complete(null);
        }
      }
    }

    _tryOcm().then(onResult, onError: (_) => onResult(null));
    for (final host in _overpassHosts) {
      _tryOverpassHost(host).then(onResult, onError: (_) => onResult(null));
    }

    return completer.future;
  }

  Future<void> _loadEv() async {
    if (_evStations != null || _evLoading) return;
    _evLoading = true;
    if (mounted) setState(() {});

    final capLat = _lat!;
    final capLng = _lng!;

    var result = await _fetchEvParallel(capLat, capLng);
    // Wenn alle Quellen leer (Ratelimit), einmal nach 2 s wiederholen
    if (result == null && mounted && _lat == capLat && _lng == capLng) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _lat == capLat && _lng == capLng) {
        result = await _fetchEvParallel(capLat, capLng);
      }
    }

    if (!mounted || _lat != capLat || _lng != capLng) {
      _evLoading = false;
      return;
    }
    _evStations = result ?? [];
    _evLoading = false;
    if (mounted) setState(() {});
  }

  Future<List<_EvStation>?> _tryOcm() async {
    try {
      final uri = Uri.parse(
          'https://api.openchargemap.io/v3/poi/'
          '?latitude=$_lat&longitude=$_lng'
          '&maxresults=50&distance=15&distanceunit=KM'
          '&key=3f32206c-414e-481d-942f-ac1fdf352350');
      final r = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(utf8.decode(r.bodyBytes));
        return raw
            .map((j) => _EvStation.fromOcm(j as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));
      }
    } catch (_) {}
    return null;
  }

  Future<List<_EvStation>?> _tryOverpassHost(String host) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent(
          '[out:json];(node["amenity"="charging_station"](around:15000,$_lat,$_lng);'
          'way["amenity"="charging_station"](around:15000,$_lat,$_lng););out center;');
      final r = await http.get(
        Uri.parse('$host?data=$encodedQuery'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'MoveBase-App/1.0.4',
        },
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];
        final stations = elements
            .map((e) =>
                _EvStation.fromOsm(e as Map<String, dynamic>, _lat!, _lng!))
            .where((s) => s.lat != 0.0 || s.lng != 0.0)
            .toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));
        return stations.isEmpty ? null : stations;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadCountryAvgPrice(String countryCode) async {
    if (_avgPriceLoading) return;
    _avgPriceLoading = true;
    _slowAvgTimer?.cancel();
    _slowAvgLoading = false;
    _slowAvgTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _slowAvgLoading = true);
    });
    if (mounted) setState(() {});
    try {
      final cc = countryCode.toUpperCase();
      final uri = Uri.parse(
          'https://www.fuel-prices.eu/live/api.php?action=summary&country=$cc');
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'MoveBase/1.0'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        // Echte Antwortstruktur: {"ok":true,"data":{"countries":[{"fuels":{"diesel":{"avg":1.75},"sp95":{"avg":1.80},...}}]}}
        if (data is Map<String, dynamic> && data['ok'] == true) {
          final countries = (data['data']?['countries'] as List<dynamic>?) ?? [];
          if (countries.isNotEmpty) {
            final fuels = (countries[0]?['fuels'] as Map<String, dynamic>?) ?? {};
            double? getAvg(String key) {
              final v = fuels[key];
              if (v is Map<String, dynamic>) {
                final avg = v['avg'];
                if (avg is num) return avg.toDouble();
              }
              return null;
            }
            final die = getAvg('diesel');
            final sup = getAvg('sp95') ?? getAvg('sp98') ?? getAvg('e5');
            final gas = getAvg('e10') ?? getAvg('gpl') ?? getAvg('lpg');
            _countryAvgPrices = {
              if (die != null) 'DIE': die,
              if (sup != null) 'SUP': sup,
              if (gas != null) 'GAS': gas,
            };
          }
        }
      }
    } catch (_) {}
    _slowAvgTimer?.cancel();
    _slowAvgLoading = false;
    _avgPriceLoading = false;
    if (mounted) setState(() {});
  }

  List<_TsMapPoint> _buildAllPoints() {
    final pts = <_TsMapPoint>[];
    for (int i = 0; i < _fuelTypes.length; i++) {
      for (final s in (_cache[_fuelTypes[i]] ?? [])) {
        pts.add(_TsMapPoint(
          name: s.name, subtitle: s.address,
          lat: s.lat, lng: s.lng,
          distance: s.distance, price: s.price,
          isEv: false, fuelType: _fuelTypes[i],
        ));
      }
    }
    for (final s in (_evStations ?? [])) {
      pts.add(_TsMapPoint(
        name: s.name, subtitle: s.socketTypes.join(', '),
        lat: s.lat, lng: s.lng,
        distance: s.distance, price: null,
        isEv: true, fuelType: 'ev',
      ));
    }
    return pts;
  }

  Future<void> _selectCity(double lat, double lng, String name, {String countryCode = 'at'}) async {
    _lat = lat;
    _lng = lng;
    _searchCityName = name;
    _searchCountryCode = countryCode;
    _usingSearch = true;
    _loadingTypes.clear();
    _cache.clear();
    _evStations = null;
    _evLoading = false;
    _countryAvgPrices = {};
    _slowLoadTimer?.cancel();
    if (mounted) setState(() { _loading = false; _error = null; _slowLoading = false; });
    if (countryCode != 'at') _loadCountryAvgPrice(countryCode);
    await Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
  }

  Future<(List<_TsMapPoint>, double, double)> _selectCityForMap(double lat, double lng, String name, String countryCode) async {
    await _selectCity(lat, lng, name, countryCode: countryCode);
    return (_buildAllPoints(), _lat!, _lng!);
  }

  Future<(List<_TsMapPoint>, double, double)> _resetToGpsForMap() async {
    _usingSearch = false;
    _searchCityName = null;
    _searchCountryCode = null;
    _countryAvgPrices = {};
    _avgPriceLoading = false;
    _cache.clear();
    _evStations = null;
    _slowLoadTimer?.cancel();
    if (mounted) setState(() { _loading = false; _error = null; _slowLoading = false; });
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      _lat = pos.latitude;
      _lng = pos.longitude;
    } catch (_) {}
    await Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
    return (_buildAllPoints(), _lat!, _lng!);
  }

  Future<List<_TsMapPoint>> _reloadForMap() async {
    _loadingTypes.clear();
    _cache.clear();
    _evStations = null;
    _evLoading = false;
    if (mounted) setState(() {});
    await Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
    return _buildAllPoints();
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
                              final cc = ((s['address'] as Map<String, dynamic>?)?['country_code'] as String?) ?? 'at';
                              _selectCity(
                                double.parse(s['lat'] as String),
                                double.parse(s['lon'] as String),
                                title,
                                countryCode: cc,
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
        title: Text(
          AppLocalizations.of(context).tsTitle,
          style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.navy),
            onPressed: _openCitySearch,
          ),
          if (_searchCityName != null)
            IconButton(
              icon: const Icon(Icons.gps_fixed, color: Color(0xFFE8A020)),
              tooltip: 'Zurück zu meinem Standort',
              onPressed: () {
                _usingSearch = false;
                _searchCityName = null;
                _cache.clear();
                _init();
              },
            ),
          if (_lat != null)
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppColors.navy),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _TsMapScreen(
                    points: _buildAllPoints(),
                    userLat: _lat!, userLng: _lng!,
                    initialSearchCityName: _searchCityName,
                    onSearchCity: (lat, lng, name, countryCode) => _selectCityForMap(lat, lng, name, countryCode),
                    onResetToGps: () => _resetToGpsForMap(),
                    onReload: () => _reloadForMap(),
                  ),
                ));
                if (mounted) setState(() {});
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.navy),
            onPressed: () {
              if (_usingSearch) {
                _loadingTypes.clear();
                _overpassFuture = null;
                _priceApiDown = false;
                setState(() { _cache.clear(); _evStations = null; _evLoading = false; });
                Future.wait([..._fuelTypes.map(_loadFuel), _loadEv()]);
              } else {
                _init();
              }
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
            Tab(icon: const Icon(Icons.ev_station, size: 18), text: AppLocalizations.of(context).tsEvTab),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.navy),
                  if (_slowLoading) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'en'
                            ? 'One moment, taking a bit longer than usual…'
                            : 'Einen Moment, dauert etwas länger als gewöhnlich…',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    if (_searchCityName != null)
                      Container(
                        color: AppColors.navy,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.location_city, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_searchCityName!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                          GestureDetector(
                            onTap: () {
                              _usingSearch = false;
                              _searchCityName = null;
                              _cache.clear();
                              _init();
                            },
                            child: const Icon(Icons.close, color: Colors.white70, size: 18),
                          ),
                        ]),
                      ),
                    if (_searchCityName != null &&
                        _searchCountryCode != null &&
                        _searchCountryCode != 'at' &&
                        _searchCountryCode != 'de' &&
                        (_avgPriceLoading || _countryAvgPrices.isNotEmpty))
                      Builder(builder: (context) {
                        final lang = Localizations.localeOf(context).languageCode;
                        final isEn = lang == 'en';
                        String text;
                        if (_avgPriceLoading) {
                          text = _slowAvgLoading
                              ? (isEn ? 'One moment, taking a bit longer than usual…' : 'Einen Moment, dauert etwas länger als gewöhnlich…')
                              : (isEn ? 'Loading average prices…' : 'Durchschnittspreise werden geladen…');
                        } else {
                          final parts = <String>[];
                          final sup = _countryAvgPrices['SUP'];
                          final die = _countryAvgPrices['DIE'];
                          final gas = _countryAvgPrices['GAS'];
                          if (sup != null) parts.add('Super ${sup.toStringAsFixed(3)} €');
                          if (die != null) parts.add('Diesel ${die.toStringAsFixed(3)} €');
                          if (gas != null) parts.add('Gas ${gas.toStringAsFixed(3)} €');
                          final label = isEn ? 'Country average' : 'Landesdurchschnitt';
                          text = 'Ø ${_searchCountryCode!.toUpperCase()}: ${parts.join(' · ')} ($label)';
                        }
                        return Container(
                          color: const Color(0xFFFFF8E1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(children: [
                            const Icon(Icons.info_outline, size: 13, color: Color(0xFFE65100)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(text,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFE65100)))),
                          ]),
                        );
                      }),
                    if (_searchCountryCode == 'de')
                      Container(
                        color: const Color(0xFFF1F8E9),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(children: [
                          const Icon(Icons.verified_outlined, size: 13, color: Color(0xFF33691E)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            'Preisdaten: www.tankerkoenig.de (CC BY 4.0)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF33691E)),
                          )),
                        ]),
                      ),
                    if (_priceApiDown && _tabCtrl.index < 3)
                      Container(
                        color: const Color(0xFFFFF3E0),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE65100)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            Localizations.localeOf(context).languageCode == 'en'
                                ? 'Prices currently unavailable – e-control.at server temporarily down. Showing station locations only.'
                                : 'Preise derzeit nicht verfügbar – e-control.at Server vorübergehend nicht erreichbar. Nur Standorte werden angezeigt.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFE65100)),
                          )),
                        ]),
                      ),
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
                              return Center(
                                child: Text(AppLocalizations.of(context).tsNoFuelStations),
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
                                            Text(
                                              AppLocalizations.of(context).tsEvUnavailable,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              AppLocalizations.of(context).tsSearchInMaps,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
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
                                              label: Text(
                                                  AppLocalizations.of(context).tsOpenInMaps),
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
                                                setState(() { _evStations = null; });
                                                _loadEv();
                                              },
                                              icon: const Icon(Icons.refresh,
                                                  size: 16),
                                              label:
                                                  Text(AppLocalizations.of(context).tsTryAgain),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : _buildEvList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEvList() {
    final allTypes = <String>{};
    for (final s in _evStations!) {
      allTypes.addAll(s.socketTypes);
    }
    final types = allTypes.toList()..sort();

    final filtered = _evFilter.isEmpty
        ? _evStations!
        : _evStations!
            .where((s) => s.socketTypes.any((t) => _evFilter.contains(t)))
            .toList();

    return Column(
      children: [
        if (types.isNotEmpty)
          Container(
            color: AppColors.lightGrey.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(AppLocalizations.of(context).tsFilterLabel,
                      style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                  const SizedBox(width: 8),
                  ...types.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          selected: _evFilter.contains(t),
                          onSelected: (on) => setState(() {
                            on ? _evFilter.add(t) : _evFilter.remove(t);
                          }),
                          selectedColor:
                              const Color(0xFF2E7D32).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF2E7D32),
                          labelStyle: TextStyle(
                            color: _evFilter.contains(t)
                                ? const Color(0xFF2E7D32)
                                : AppColors.navy,
                            fontWeight: _evFilter.contains(t)
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )),
                ],
              ),
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context).tsNoEvFilter,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (_, idx) =>
                      _EvStationCard(station: filtered[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildSortBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(AppLocalizations.of(context).tsSortBy,
              style: const TextStyle(fontSize: 13, color: AppColors.grey)),
          const SizedBox(width: 10),
          _SortChip(
            label: AppLocalizations.of(context).tsSortPrice,
            selected: _sortByPrice,
            onTap: () => setState(() => _sortByPrice = true),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: AppLocalizations.of(context).tsSortDistance,
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
              label: Text(AppLocalizations.of(context).tsTryAgain),
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

  factory _EvStation.fromOsm(
      Map<String, dynamic> j, double userLat, double userLng) {
    // nodes: lat/lon direkt; ways (out center): unter j['center']
    final center = j['center'] as Map<String, dynamic>?;
    final lat = (j['lat'] as num?)?.toDouble() ??
        (center?['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (j['lon'] as num?)?.toDouble() ??
        (center?['lon'] as num?)?.toDouble() ?? 0.0;
    final tags = j['tags'] as Map<String, dynamic>? ?? {};
    final name = (tags['name'] as String?) ??
        (tags['operator'] as String?) ??
        'Ladestation';
    final capacityStr = tags['capacity'] as String?;
    final capacity = capacityStr != null ? int.tryParse(capacityStr) : null;

    final sockets = <String>[];
    if (tags.containsKey('socket:type2')) sockets.add('Type 2');
    if (tags.containsKey('socket:ccs')) sockets.add('CCS');
    if (tags.containsKey('socket:chademo')) sockets.add('CHAdeMO');
    if (tags.containsKey('socket:schuko')) sockets.add('Schuko');
    if (tags.containsKey('socket:type1')) sockets.add('Type 1');

    final dLat = (lat - userLat) * math.pi / 180;
    final dLng = (lng - userLng) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(userLat * math.pi / 180) *
            math.cos(lat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final dist = 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _EvStation(
      name: name,
      lat: lat,
      lng: lng,
      distance: dist,
      capacity: capacity,
      socketTypes: sockets,
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
                        Text('${station.capacity} ${AppLocalizations.of(context).tsChargingPoints}',
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

// ─── Map Point & Map Screen ───────────────────────────────────────────────────

class _TsMapPoint {
  final String name, subtitle, fuelType;
  final double lat, lng, distance;
  final double? price;
  final bool isEv;
  const _TsMapPoint({
    required this.name, required this.subtitle, required this.fuelType,
    required this.lat, required this.lng, required this.distance,
    this.price, required this.isEv,
  });
}

class _TsMapScreen extends StatefulWidget {
  final List<_TsMapPoint> points;
  final double userLat, userLng;
  final Future<(List<_TsMapPoint>, double, double)> Function(double, double, String, String)? onSearchCity;
  final Future<(List<_TsMapPoint>, double, double)> Function()? onResetToGps;
  final Future<List<_TsMapPoint>> Function()? onReload;
  final String? initialSearchCityName;
  const _TsMapScreen({
    required this.points,
    required this.userLat,
    required this.userLng,
    this.onSearchCity,
    this.onResetToGps,
    this.onReload,
    this.initialSearchCityName,
  });

  @override
  State<_TsMapScreen> createState() => _TsMapScreenState();
}

class _TsMapScreenState extends State<_TsMapScreen> {
  _TsMapPoint? _selected;
  final Set<String> _filters = {};
  late List<_TsMapPoint> _points;
  late double _centerLat, _centerLng;
  String? _searchCityName;
  bool _reloading = false;
  final _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    _points = widget.points;
    _centerLat = widget.userLat;
    _centerLng = widget.userLng;
    _searchCityName = widget.initialSearchCityName;
  }

  static const _filterDefs = [
    ('SUP', '⛽ Super 95', Color(0xFFE8A020)),
    ('DIE', '⛽ Diesel',   Color(0xFF8B4513)),
    ('GAS', '⛽ Gas',      Color(0xFF1565C0)),
    ('ev',  '⚡ Laden',    Color(0xFF2E7D32)),
  ];

  List<_TsMapPoint> get _visible => _filters.isEmpty
      ? _points
      : _points.where((p) => _filters.contains(p.fuelType)).toList();

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
                              final lng = double.parse(s['lon'] as String);
                              final cc = ((s['address'] as Map<String, dynamic>?)?['country_code'] as String?) ?? 'at';
                              setState(() { _reloading = true; _selected = null; });
                              try {
                                final (fresh, nlat, nlng) = await widget.onSearchCity!(lat, lng, title, cc);
                                if (mounted) {
                                  setState(() {
                                    _points = fresh;
                                    _centerLat = nlat; _centerLng = nlng;
                                    _searchCityName = title;
                                    _filters.clear();
                                    _reloading = false;
                                  });
                                  _mapCtrl.move(LatLng(nlat, nlng), 12);
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

  Color _markerColor(_TsMapPoint p) {
    switch (p.fuelType) {
      case 'DIE': return const Color(0xFF8B4513);
      case 'GAS': return const Color(0xFF1565C0);
      case 'ev':  return const Color(0xFF2E7D32);
      default:    return const Color(0xFFE8A020);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
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
            : const Text('Tankstellen & Laden',
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
                  final (fresh, lat, lng) = await widget.onResetToGps!();
                  if (mounted) {
                    setState(() {
                      _points = fresh; _centerLat = lat; _centerLng = lng;
                      _searchCityName = null; _filters.clear(); _reloading = false;
                    });
                    _mapCtrl.move(LatLng(lat, lng), 12);
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
                  if (mounted) setState(() { _points = fresh; _reloading = false; });
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
              initialCenter: LatLng(_centerLat, _centerLng),
              initialZoom: 12,
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
                    point: LatLng(_centerLat, _centerLng),
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
                  ...visible.map((p) => Marker(
                    point: LatLng(p.lat, p.lng),
                    width: 36, height: 36,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = p),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _markerColor(p),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Center(
                          child: Text(p.isEv ? '⚡' : '⛽',
                              style: const TextStyle(fontSize: 16)),
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
                    children: _filterDefs.map((def) {
                      final (key, label, color) = def;
                      final active = _filters.contains(key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FilterChip(
                          label: Text(label,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: active ? Colors.white : Colors.black87)),
                          selected: active,
                          selectedColor: color,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (_) => setState(() {
                            if (active) _filters.remove(key);
                            else _filters.add(key);
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
                        Text(_selected!.isEv ? '⚡' : '⛽',
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_selected!.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15))),
                        GestureDetector(
                          onTap: () => setState(() => _selected = null),
                          child: const Icon(Icons.close, size: 20, color: Colors.grey),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(_selected!.subtitle,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      if (_selected!.price != null) ...[
                        const SizedBox(height: 6),
                        Text('€ ${_selected!.price!.toStringAsFixed(3)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF022851))),
                      ],
                      const SizedBox(height: 6),
                      Text('${_selected!.distance.toStringAsFixed(1)} km entfernt',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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

  factory _Station.fromTankerKoenig(Map<String, dynamic> j, String fuelType) {
    final name = (j['name'] as String?)?.isNotEmpty == true
        ? j['name'] as String
        : (j['brand'] as String?) ?? 'Tankstelle';
    final street = (j['street'] as String?) ?? '';
    final nr = (j['houseNumber'] as String?) ?? '';
    final place = (j['place'] as String?) ?? '';
    final plz = j['postCode']?.toString() ?? '';
    final address = [
      [street, nr].where((s) => s.isNotEmpty).join(' '),
      [plz, place].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).join(', ');
    final lat = (j['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (j['lng'] as num?)?.toDouble() ?? 0.0;
    final dist = (j['dist'] as num?)?.toDouble() ?? 0.0;
    double? price;
    if (fuelType == 'SUP') {
      final raw = j['e5'];
      if (raw is num) price = raw.toDouble();
    } else if (fuelType == 'DIE') {
      final raw = j['diesel'];
      if (raw is num) price = raw.toDouble();
    }
    return _Station(name: name, address: address, lat: lat, lng: lng, distance: dist, price: price);
  }

  factory _Station.fromOsm(Map<String, dynamic> j, double userLat, double userLng) {
    final center = j['center'] as Map<String, dynamic>?;
    final lat = (j['lat'] as num?)?.toDouble() ?? (center?['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (j['lon'] as num?)?.toDouble() ?? (center?['lon'] as num?)?.toDouble() ?? 0.0;
    final tags = j['tags'] as Map<String, dynamic>? ?? {};
    final name = (tags['name'] ?? tags['brand'] ?? tags['operator'] ?? 'Tankstelle') as String;
    final street = (tags['addr:street'] as String?) ?? '';
    final city = (tags['addr:city'] as String?) ?? '';
    final address = [street, city].where((s) => s.isNotEmpty).join(', ');
    final dLat = (lat - userLat) * math.pi / 180;
    final dLng = (lng - userLng) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(userLat * math.pi / 180) * math.cos(lat * math.pi / 180) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final dist = 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _Station(name: name, address: address, lat: lat, lng: lng, distance: dist, price: null);
  }
}
