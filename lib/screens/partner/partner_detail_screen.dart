import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../models/partner.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/category_utils.dart';

class PartnerDetailScreen extends StatefulWidget {
  final String partnerId;
  const PartnerDetailScreen({super.key, required this.partnerId});

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen> {
  late final Future<Partner?> _future;

  @override
  void initState() {
    super.initState();
    _future = PartnerService().getPartner(widget.partnerId).then((p) {
      if (p != null) {
        PartnerService().trackKlick(widget.partnerId, 'aufrufe');
      }
      return p;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<Partner?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final partner = snapshot.data;
        if (partner == null) {
          return Scaffold(body: Center(child: Text(l10n.businessNotFound)));
        }
        return _DetailView(partner: partner);
      },
    );
  }
}

class _DetailView extends StatelessWidget {
  final Partner partner;
  const _DetailView({required this.partner});

  Future<void> _call() {
    PartnerService().trackKlick(partner.id, 'anrufen');
    return launchUrl(Uri.parse('tel:${partner.telefon}'));
  }

  Future<void> _email() {
    PartnerService().trackKlick(partner.id, 'email');
    return launchUrl(Uri.parse('mailto:${partner.email}'));
  }

  Future<void> _website() {
    PartnerService().trackKlick(partner.id, 'website');
    var url = partner.website;
    if (!url.startsWith('http')) url = 'https://$url';
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _share() {
    final lines = [
      partner.name,
      partner.fullAddress,
      if (partner.telefon.isNotEmpty) '📞 ${partner.telefon}',
      if (partner.website.isNotEmpty) '🌐 ${partner.website}',
    ];
    Share.share(lines.join('\n'));
  }

  Future<void> _maps() {
    final Uri uri;
    if (partner.lat != null && partner.lng != null) {
      uri = Uri.parse('https://maps.google.com/?q=${partner.lat},${partner.lng}');
    } else {
      final q = Uri.encodeComponent(partner.fullAddress);
      uri = Uri.parse('https://maps.google.com/?q=$q');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(l10n),
                  const SizedBox(height: 20),
                  if (partner.photos.isNotEmpty) ...[
                    _buildPhotoGallery(context, l10n),
                    const SizedBox(height: 20),
                  ],
                  _buildActionButtons(l10n),
                  const SizedBox(height: 20),
                  if (partner.berater.isNotEmpty) ...[
                    _sectionTitle(l10n.yourAdvisor),
                    Row(children: [
                      const Icon(Icons.person_outline,
                          size: 18, color: AppColors.grey),
                      const SizedBox(width: 8),
                      Text(partner.berater,
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w500,
                              fontSize: 15)),
                    ]),
                    const SizedBox(height: 20),
                  ],
                  if (partner.oeffnungszeiten.isNotEmpty) ...[
                    _sectionTitle(l10n.openingHours),
                    Text(partner.oeffnungszeiten,
                        style: const TextStyle(color: AppColors.grey)),
                    const SizedBox(height: 20),
                  ],
                  if (partner.leistungen.isNotEmpty) ...[
                    _sectionTitle(l10n.services),
                    Text(partner.leistungen),
                    const SizedBox(height: 20),
                  ],
                  if (partner.kategorien.length > 1) ...[
                    _sectionTitle(l10n.categories),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: partner.kategorien
                          .map((s) => Chip(
                                label: Text(localizedCategory(l10n, s)),
                                backgroundColor: AppColors.orange.withOpacity(0.1),
                                labelStyle: const TextStyle(color: AppColors.navy),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (partner.ersatzwagenHinweis.isNotEmpty) ...[
                    _sectionTitle(l10n.replacementVehicle),
                    _InfoBox(partner.ersatzwagenHinweis),
                    const SizedBox(height: 20),
                  ],
                  if (partner.zusatzInfo.isNotEmpty) ...[
                    _sectionTitle(l10n.additionalServices),
                    ...partner.zusatzInfo.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy)),
                              const SizedBox(height: 4),
                              _InfoBox(e.value),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (partner.zusatzTelefon.isNotEmpty) ...[
                    _sectionTitle(l10n.directContacts),
                    ...partner.zusatzTelefon.entries.map((e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone, color: AppColors.orange),
                          title: Text(e.key),
                          subtitle: Text(e.value),
                          onTap: () => launchUrl(Uri.parse('tel:${e.value}')),
                        )),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    if (partner.logo.isNotEmpty) {
      return SliverAppBar(
        expandedHeight: 220,
        pinned: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: FlexibleSpaceBar(
          background: Image.network(
            partner.logo,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppColors.navy),
          ),
        ),
      );
    }
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.navy,
      expandedHeight: 80,
      flexibleSpace: const FlexibleSpaceBar(),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final catLabel = localizedCategoryList(l10n, partner.kategorien, partner.kategorie);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (partner.logo.isEmpty)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business, color: AppColors.navy, size: 32),
          ),
        if (partner.logo.isEmpty) const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(partner.name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              Text(catLabel,
                  style: const TextStyle(
                      color: AppColors.orange, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _maps,
                child: Row(children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(partner.fullAddress,
                        style: const TextStyle(
                            color: AppColors.grey,
                            decoration: TextDecoration.underline)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (partner.telefon.isNotEmpty)
          _ActionBtn(
            icon: Icons.phone,
            label: l10n.call,
            filled: true,
            onTap: _call,
          ),
        _ActionBtn(
          icon: Icons.directions,
          label: l10n.navigation,
          onTap: _maps,
        ),
        if (partner.website.isNotEmpty)
          _ActionBtn(
            icon: Icons.language,
            label: l10n.website,
            onTap: _website,
          ),
        if (partner.email.isNotEmpty)
          _ActionBtn(
            icon: Icons.email_outlined,
            label: l10n.email,
            onTap: _email,
          ),
        _ActionBtn(
          icon: Icons.share_outlined,
          label: 'Teilen',
          onTap: _share,
        ),
      ],
    );
  }

  Widget _buildPhotoGallery(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.photos),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: partner.photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openPhotoViewer(context, index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    partner.photos[index],
                    width: 240,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 240,
                      color: AppColors.navy.withOpacity(0.1),
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.grey, size: 40),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openPhotoViewer(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: partner.photos.length,
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: Image.network(
                    partner.photos[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 60),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.navy)),
      );
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orange.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.orange.withOpacity(0.2)),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.navy)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return OutlinedButton.icon(
      icon: Icon(icon, color: AppColors.navy),
      label: Text(label, style: const TextStyle(color: AppColors.navy)),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.navy),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
