import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/partner.dart';
import '../../services/partner_service.dart';
import '../../widgets/partner_card.dart';

// AT PLZ → Bundesland
String? _bundeslandFromPlz(String plz, String land) {
  if (land != 'AT') return null;
  final n = int.tryParse(plz.length >= 4 ? plz.substring(0, 4) : plz);
  if (n == null) return null;
  if (n >= 1000 && n <= 1999) return 'Wien';
  if (n >= 2000 && n <= 3999) return 'Niederösterreich';
  if (n >= 4000 && n <= 4999) return 'Oberösterreich';
  if (n >= 5000 && n <= 5999) return 'Salzburg';
  if (n >= 6700 && n <= 6999) return 'Vorarlberg';
  if (n >= 6000 && n <= 6699) return 'Tirol';
  if (n >= 7000 && n <= 7999) return 'Burgenland';
  if (n >= 8000 && n <= 8999) return 'Steiermark';
  if (n >= 9000 && n <= 9999) return 'Kärnten';
  return null;
}

const _atBundeslaender = [
  'Wien', 'Niederösterreich', 'Oberösterreich', 'Salzburg',
  'Tirol', 'Vorarlberg', 'Burgenland', 'Steiermark', 'Kärnten',
];

const _lands = ['AT', 'DE', 'CH'];

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

  // Filter state
  final Set<String> _filterKategorien = {};
  final Set<String> _filterLaender = {};
  final Set<String> _filterBundeslaender = {};

  int get _activeFilterCount =>
      _filterKategorien.length + _filterLaender.length + _filterBundeslaender.length;

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
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();

    var list = _allPartners.where((p) {
      // Text filter
      if (q.isNotEmpty) {
        final match = p.name.toLowerCase().contains(q) ||
            p.ort.toLowerCase().contains(q) ||
            p.plz.contains(q) ||
            p.kategorie.toLowerCase().contains(q) ||
            p.kategorien.any((k) => k.toLowerCase().contains(q));
        if (!match) return false;
      }
      // Land filter
      if (_filterLaender.isNotEmpty && !_filterLaender.contains(p.land)) {
        return false;
      }
      // Kategorie filter
      if (_filterKategorien.isNotEmpty &&
          !_filterKategorien.contains(p.kategorie) &&
          !p.kategorien.any((k) => _filterKategorien.contains(k))) {
        return false;
      }
      // Bundesland filter (AT only via PLZ)
      if (_filterBundeslaender.isNotEmpty) {
        final bl = _bundeslandFromPlz(p.plz, p.land);
        if (bl == null || !_filterBundeslaender.contains(bl)) return false;
      }
      return true;
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

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        selectedKategorien: Set.from(_filterKategorien),
        selectedLaender: Set.from(_filterLaender),
        selectedBundeslaender: Set.from(_filterBundeslaender),
        onApply: (kat, land, bl) {
          setState(() {
            _filterKategorien
              ..clear()
              ..addAll(kat);
            _filterLaender
              ..clear()
              ..addAll(land);
            _filterBundeslaender
              ..clear()
              ..addAll(bl);
          });
          _applyFilter(_controller.text);
        },
      ),
    );
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
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filter',
                onPressed: _openFilter,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loadingPartners
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_activeFilterCount > 0)
                  Container(
                    color: AppColors.navy.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 16, color: AppColors.grey),
                        const SizedBox(width: 6),
                        Text('${_results.length} Ergebnisse',
                            style: const TextStyle(
                                color: AppColors.grey, fontSize: 13)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _filterKategorien.clear();
                              _filterLaender.clear();
                              _filterBundeslaender.clear();
                            });
                            _applyFilter(_controller.text);
                          },
                          child: const Text('Filter zurücksetzen',
                              style: TextStyle(
                                  color: AppColors.orange, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            _controller.text.isEmpty && _activeFilterCount == 0
                                ? 'Suchbegriff eingeben oder Filter wählen...'
                                : 'Keine Betriebe gefunden.',
                            style: const TextStyle(color: AppColors.grey),
                            textAlign: TextAlign.center,
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
                ),
              ],
            ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final Set<String> selectedKategorien;
  final Set<String> selectedLaender;
  final Set<String> selectedBundeslaender;
  final void Function(Set<String>, Set<String>, Set<String>) onApply;

  const _FilterSheet({
    required this.selectedKategorien,
    required this.selectedLaender,
    required this.selectedBundeslaender,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _kategorien;
  late Set<String> _laender;
  late Set<String> _bundeslaender;

  @override
  void initState() {
    super.initState();
    _kategorien = Set.from(widget.selectedKategorien);
    _laender = Set.from(widget.selectedLaender);
    _bundeslaender = Set.from(widget.selectedBundeslaender);
  }

  void _toggle(Set<String> set, String val) =>
      setState(() => set.contains(val) ? set.remove(val) : set.add(val));

  @override
  Widget build(BuildContext context) {
    final showBundesland =
        _laender.isEmpty || _laender.contains('AT');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Filter',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _kategorien.clear();
                  _laender.clear();
                  _bundeslaender.clear();
                }),
                child: const Text('Zurücksetzen',
                    style: TextStyle(color: AppColors.orange)),
              ),
            ]),
            Expanded(
              child: ListView(
                controller: ctrl,
                children: [
                  _sectionLabel('Kategorie'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: kCategories
                        .map((k) => FilterChip(
                              label: Text(k),
                              selected: _kategorien.contains(k),
                              onSelected: (_) => _toggle(_kategorien, k),
                              selectedColor: AppColors.navy.withOpacity(0.15),
                              checkmarkColor: AppColors.navy,
                              labelStyle: TextStyle(
                                color: _kategorien.contains(k)
                                    ? AppColors.navy
                                    : AppColors.grey,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Land'),
                  Wrap(
                    spacing: 8,
                    children: _lands
                        .map((l) => FilterChip(
                              label: Text(l),
                              selected: _laender.contains(l),
                              onSelected: (_) {
                                _toggle(_laender, l);
                                if (!_laender.contains('AT')) {
                                  setState(() => _bundeslaender.clear());
                                }
                              },
                              selectedColor: AppColors.navy.withOpacity(0.15),
                              checkmarkColor: AppColors.navy,
                              labelStyle: TextStyle(
                                color: _laender.contains(l)
                                    ? AppColors.navy
                                    : AppColors.grey,
                              ),
                            ))
                        .toList(),
                  ),
                  if (showBundesland) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Bundesland (Österreich)'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _atBundeslaender
                          .map((bl) => FilterChip(
                                label: Text(bl),
                                selected: _bundeslaender.contains(bl),
                                onSelected: (_) => _toggle(_bundeslaender, bl),
                                selectedColor: AppColors.navy.withOpacity(0.15),
                                checkmarkColor: AppColors.navy,
                                labelStyle: TextStyle(
                                  color: _bundeslaender.contains(bl)
                                      ? AppColors.navy
                                      : AppColors.grey,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_kategorien, _laender, _bundeslaender);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Anwenden'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.navy)),
      );
}
