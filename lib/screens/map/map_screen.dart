import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../models/partner.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/category_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  Partner? _selected;
  LatLng? _userPosition;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _userPosition = latLng);
      _mapController.move(latLng, 11);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.map),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _userPosition != null
            ? () => _mapController.move(_userPosition!, 13)
            : _locateUser,
        backgroundColor: AppColors.navy,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
      body: StreamBuilder<List<Partner>>(
        stream: PartnerService().getPartners(),
        builder: (context, snapshot) {
          final partners = (snapshot.data ?? [])
              .where((p) => p.lat != null && p.lng != null)
              .toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(47.5, 14.0),
                  initialZoom: 7,
                  onTap: (_, __) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.mycompany.moveBase',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_userPosition != null)
                        Marker(
                          point: _userPosition!,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ...partners.map((p) {
                        final isSelected = _selected?.id == p.id;
                        return Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: isSelected ? 48 : 36,
                          height: isSelected ? 48 : 36,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selected = p);
                              _mapController.move(
                                LatLng(p.lat!, p.lng!),
                                _mapController.camera.zoom < 10
                                    ? 12
                                    : _mapController.camera.zoom,
                              );
                            },
                            child: Icon(
                              Icons.location_pin,
                              color: isSelected
                                  ? AppColors.orange
                                  : AppColors.navy,
                              size: isSelected ? 48 : 36,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              if (_selected != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 80,
                  child: _PartnerPopup(
                    partner: _selected!,
                    onClose: () => setState(() => _selected = null),
                    onTap: () => context.push('/partner/${_selected!.id}'),
                  ),
                ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }
}

class _PartnerPopup extends StatelessWidget {
  final Partner partner;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _PartnerPopup({
    required this.partner,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (partner.logo.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16)),
                child: Image.network(
                  partner.logo,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _logoPlaceholder(),
                ),
              )
            else
              _logoPlaceholder(),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      partner.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localizedCategoryList(
                          l10n, partner.kategorien, partner.kategorie),
                      style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${partner.adresse}, ${partner.ort}',
                      style: const TextStyle(
                          color: AppColors.grey, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.grey, size: 20),
                  onPressed: onClose,
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, right: 8),
                  child: Icon(Icons.chevron_right, color: AppColors.navy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoPlaceholder() => Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius:
              BorderRadius.horizontal(left: Radius.circular(16)),
        ),
        child: const Icon(Icons.business, color: AppColors.grey, size: 32),
      );
}
