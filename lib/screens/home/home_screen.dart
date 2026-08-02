import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../generated/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../providers/locale_provider.dart';
import '../../models/partner.dart';
import '../../services/partner_service.dart';
import '../../widgets/partner_card.dart';
import '../../widgets/category_chip.dart';
import '../../utils/seed_data.dart';
import '../../utils/category_utils.dart';
import '../arcade/arcade_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _partnerService = PartnerService();
  String? _selectedCategory;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) setState(() => _position = pos);
    } catch (_) {}
  }

  double? _distanceKm(Partner p) {
    if (p.lat == null || p.lng == null || _position == null) return null;
    const r = 6371.0;
    final dLat = (p.lat! - _position!.latitude) * pi / 180;
    final dLng = (p.lng! - _position!.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_position!.latitude * pi / 180) *
            cos(p.lat! * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String? _distanceLabel(Partner p) {
    final km = _distanceKm(p);
    if (km == null) return null;
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  void _openArcade() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ArcadeScreen()));
  }

  void _showCrashLogDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo3kleinNew.png',
              width: 72,
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.apps, size: 72, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            const Text(
              'Möchtest du zu CrashLog wechseln?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _openCrashLog();
            },
            child: const Text('Öffnen'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCrashLog() async {
    if (kIsWeb) return;
    // Try crashlog:// custom scheme (works on both Android and iOS when installed)
    try {
      await launchUrl(Uri.parse('crashlog://'),
          mode: LaunchMode.externalApplication);
      return;
    } catch (_) {}
    // App not installed — go to store
    if (Platform.isAndroid) {
      try {
        await launchUrl(
            Uri.parse('market://details?id=com.mycompany.unfallbericht'),
            mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
      await launchUrl(
          Uri.parse('https://play.google.com/store/apps/details?id=com.mycompany.unfallbericht'),
          mode: LaunchMode.externalApplication);
    } else if (Platform.isIOS) {
      await launchUrl(
          Uri.parse('https://apps.apple.com/app/id19209005258'),
          mode: LaunchMode.externalApplication);
    }
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Consumer2<AuthService, LocaleProvider>(
        builder: (ctx, auth, lp, __) {
          final l10n = AppLocalizations.of(ctx);
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // drag handle
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
                    const SizedBox(height: 20),

                    // ── Für Partnerbetriebe ────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.navy.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.navy.withOpacity(0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                            child: Row(children: [
                              const Icon(Icons.business, size: 16, color: AppColors.navy),
                              const SizedBox(width: 8),
                              Text(
                                l10n.forPartners,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                  fontSize: 13,
                                ),
                              ),
                            ]),
                          ),
                          if (!auth.isLoggedIn) ...[
                            ListTile(
                              leading: const Icon(Icons.login, color: AppColors.navy),
                              title: Text(l10n.partnerLoginTitle),
                              subtitle: Text(l10n.partnerLoginSubtitle),
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                context.push('/login');
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading: const Icon(Icons.app_registration, color: AppColors.orange),
                              title: Text(l10n.registerAsPartner),
                              subtitle: Text(l10n.registerSubtitle),
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                context.push('/register');
                              },
                            ),
                          ] else ...[
                            ListTile(
                              leading: const Icon(Icons.dashboard_outlined, color: AppColors.navy),
                              title: Text(l10n.myDashboard),
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                context.push('/dashboard');
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Sprache ────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(children: [
                              const Icon(Icons.language, size: 16, color: AppColors.grey),
                              const SizedBox(width: 8),
                              Text(
                                l10n.language,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ]),
                          ),
                          Row(
                            children: [
                              _LangButton(
                                label: 'Deutsch',
                                active: lp.locale.languageCode == 'de',
                                onTap: () => lp.setLocale(const Locale('de')),
                              ),
                              _LangButton(
                                label: 'English',
                                active: lp.locale.languageCode == 'en',
                                onTap: () => lp.setLocale(const Locale('en')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Rechtliches ────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.description_outlined,
                                color: AppColors.grey, size: 20),
                            title: Text(l10n.agb,
                                style: const TextStyle(fontSize: 14)),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.grey, size: 18),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              context.push('/agb');
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.shield_outlined,
                                color: AppColors.grey, size: 20),
                            title: Text(l10n.datenschutz,
                                style: const TextStyle(fontSize: 14)),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.grey, size: 18),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              context.push('/datenschutz');
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.info_outline,
                                color: AppColors.grey, size: 20),
                            title: Text(l10n.impressum,
                                style: const TextStyle(fontSize: 14)),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.grey, size: 18),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              context.push('/impressum');
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── Version ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          '${l10n.version} 1.0.0',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ),
                    ),

                    if (kDebugMode) ...[
                      ListTile(
                        leading: const Icon(Icons.bug_report_outlined,
                            color: AppColors.grey),
                        title: const Text('Testdaten einfügen'),
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          try {
                            await seedPartners();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Testdaten eingefügt!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Fehler: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        toolbarHeight: 70,
        titleSpacing: 16,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: _openArcade,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/images/logo1.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'MB',
                    style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 36, color: Colors.grey.shade200),
            const SizedBox(width: 10),
            // CrashLog Logo — tappable
            GestureDetector(
              onTap: _showCrashLogDialog,
              child: Image.asset(
                'assets/images/logo3kleinNew.png',
                width: 52,
                height: 52,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.apps, color: AppColors.navy, size: 36),
              ),
            ),
          ],
        ),
        actions: [
          if (auth.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Dashboard',
              onPressed: () => context.push('/dashboard'),
            ),
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menü',
            onPressed: _openMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(l10n),
          _buildCategoryFilter(l10n),
          Expanded(child: _buildPartnerList(l10n)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.grey),
                    const SizedBox(width: 10),
                    Text(l10n.searchHintHome,
                        style: const TextStyle(color: AppColors.grey)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/map'),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.map_outlined, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(AppLocalizations l10n) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          CategoryChip(
            label: l10n.all,
            selected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          ...kCategories.map((c) => CategoryChip(
                label: localizedCategory(l10n, c),
                selected: _selectedCategory == c,
                onTap: () => setState(() => _selectedCategory = c),
              )),
        ],
      ),
    );
  }

  Widget _buildPartnerList(AppLocalizations l10n) {
    return StreamBuilder<List<Partner>>(
      stream: _partnerService.getPartners(category: _selectedCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        final partners = List<Partner>.from(snapshot.data ?? []);
        if (_position != null) {
          partners.sort((a, b) {
            final da = _distanceKm(a);
            final db = _distanceKm(b);
            if (da == null && db == null) return b.prioritaet.compareTo(a.prioritaet);
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        }
        if (partners.isEmpty) {
          return Center(
            child: Text(l10n.noBusinessesFound,
                style: const TextStyle(color: AppColors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: partners.length,
          itemBuilder: (_, i) => PartnerCard(
                partner: partners[i],
                distanceLabel: _distanceLabel(partners[i]),
              ),
        );
      },
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LangButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : AppColors.grey,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
