import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/partner.dart';
import '../../services/partner_service.dart';
import '../../widgets/partner_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _partnerService = PartnerService();

  List<Partner> _allPartners = [];
  List<Partner> _results = [];
  Position? _position;
  bool _loadingLocation = false;
  bool _loadingPartners = true;

  @override
  void initState() {
    super.initState();
    _loadPartners();
    _requestLocation();
  }

  Future<void> _loadPartners() async {
    final partners = await _partnerService.getAllPartners();
    if (!mounted) return;
    setState(() {
      _allPartners = partners;
      _loadingPartners = false;
      _applyFilter(_controller.text);
    });
  }

  Future<void> _requestLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (!mounted) return;
      setState(() {
        _position = pos;
        _applyFilter(_controller.text);
      });
    } catch (_) {
      // Location not available, continue without it
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    var list = q.isEmpty
        ? List<Partner>.from(_allPartners)
        : _allPartners.where((p) {
            return p.name.toLowerCase().contains(q) ||
                p.ort.toLowerCase().contains(q) ||
                p.plz.contains(q) ||
                p.kategorie.toLowerCase().contains(q) ||
                p.kategorien.any((k) => k.toLowerCase().contains(q));
          }).toList();

    if (_position != null) {
      list.sort((a, b) {
        final da = _distanceTo(a);
        final db = _distanceTo(b);
        if (da == null && db == null) return b.prioritaet.compareTo(a.prioritaet);
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    } else {
      list.sort((a, b) => b.prioritaet.compareTo(a.prioritaet));
    }

    setState(() => _results = list);
  }

  double? _distanceTo(Partner p) {
    if (p.lat == null || p.lng == null || _position == null) return null;
    return _haversine(_position!.latitude, _position!.longitude, p.lat!, p.lng!);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  String _distanceLabel(Partner p) {
    final d = _distanceTo(p);
    if (d == null) return '';
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Werkstatt, Ort, PLZ...',
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            filled: false,
            suffixIcon: _loadingLocation
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54),
                    ),
                  )
                : _position != null
                    ? const Icon(Icons.location_on, color: Colors.white54, size: 18)
                    : null,
          ),
          onChanged: _applyFilter,
        ),
      ),
      body: _loadingPartners
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _controller.text.isEmpty
                        ? 'Suchbegriff eingeben...'
                        : 'Keine Betriebe gefunden.',
                    style: const TextStyle(color: AppColors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    final label = _distanceLabel(p);
                    return PartnerCard(
                      partner: p,
                      distanceLabel: label.isEmpty ? null : label,
                    );
                  },
                ),
    );
  }
}
