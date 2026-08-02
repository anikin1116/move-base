import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../models/partner.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';

const _apiBase = 'https://crashlog.eu';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context);
    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.myDashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOut,
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: StreamBuilder<Partner?>(
        stream: PartnerService().watchMyProfile(auth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final partner = snapshot.data;
          if (partner == null) {
            return Center(
                child: Text(l10n.noPartnerProfile,
                    style: const TextStyle(color: AppColors.grey)));
          }
          return _DashboardContent(partner: partner, auth: auth);
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final Partner partner;
  final AuthService auth;
  const _DashboardContent({required this.partner, required this.auth});

  Future<void> _openCheckout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final paket = partner.paket.isEmpty ? 'basic' : partner.paket;
    final qty = partner.standorte.clamp(1, 99);
    final hasDiscount = qty >= 2;
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/api/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paket': paket,
          'billing': 'monthly',
          'uid': auth.currentUser!.uid,
          'email': partner.email,
          'firmaName': partner.name,
          'quantity': qty,
          if (hasDiscount) 'discountPercent': 20,
          'lang': 'de',
          'success_url': 'movebase://payment/success',
          'cancel_url': 'movebase://payment/cancel',
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw Exception(data['error'] ?? 'Unbekannter Fehler');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${l10n.checkoutFailed} $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openCustomerPortal(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.parse('$_apiBase/api/customer-portal').replace(
      queryParameters: {'email': partner.email},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotOpenLink)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Row(
          children: [
            if (partner.logo.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(partner.logo,
                    width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _logoPlaceholder()),
              )
            else
              _logoPlaceholder(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partner.name,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy)),
                  const SizedBox(height: 4),
                  _StatusBadge(aktiv: partner.aktiv),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Profil-Vollständigkeit
        _ProfileCompleteness(partner: partner),

        const SizedBox(height: 24),

        // Abo-Aktionen
        if (!partner.aktiv)
          _ActionCard(
            icon: Icons.payment,
            title: l10n.subscriptionNotActive,
            subtitle: l10n.subscriptionActiveInfo,
            buttonLabel: l10n.subscribeNow,
            buttonColor: AppColors.orange,
            onTap: () => _openCheckout(context),
          )
        else
          _ActionCard(
            icon: Icons.workspace_premium,
            title: '${l10n.packageLabel} ${partner.paket.toUpperCase()}',
            subtitle: l10n.subscriptionActiveDesc,
            buttonLabel: l10n.manageSubscription,
            buttonColor: AppColors.navy,
            onTap: () => _openCustomerPortal(context),
          ),

        const SizedBox(height: 24),

        // Betriebsdaten
        Text(l10n.businessData,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.navy)),
        const SizedBox(height: 12),
        _InfoRow(Icons.location_on_outlined, partner.fullAddress),
        _InfoRow(Icons.phone_outlined, partner.telefon),
        if (partner.email.isNotEmpty)
          _InfoRow(Icons.email_outlined, partner.email),
        if (partner.website.isNotEmpty)
          _InfoRow(Icons.language_outlined, partner.website),
        if (partner.oeffnungszeiten.isNotEmpty)
          _InfoRow(Icons.access_time_outlined, partner.oeffnungszeiten),
        if (partner.berater.isNotEmpty)
          _InfoRow(Icons.person_outline, partner.berater),

        const SizedBox(height: 24),

        // Klick-Statistiken
        StreamBuilder<Map<String, int>>(
          stream: PartnerService().watchKlicks(partner.id),
          builder: (context, snap) {
            final klicks = snap.data ?? {};
            if (klicks.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Statistiken',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy)),
                const SizedBox(height: 12),
                _StatsRow(klicks: klicks),
                const SizedBox(height: 24),
              ],
            );
          },
        ),

        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined, color: AppColors.navy),
          label: Text(l10n.editProfile,
              style: const TextStyle(color: AppColors.navy)),
          onPressed: () => context.push('/edit-profile', extra: partner),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.navy),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 32),

        // Website-Hinweis
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.grey),
                const SizedBox(width: 8),
                Text(l10n.accountManagement,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              Text(l10n.accountManagementNote,
                  style: const TextStyle(color: AppColors.grey, fontSize: 13)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://crashlog.eu/portal/login'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  l10n.openWebsite,
                  style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _logoPlaceholder() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.navy.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.business, color: AppColors.navy),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool aktiv;
  const _StatusBadge({required this.aktiv});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: aktiv ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        aktiv ? l10n.statusActive : l10n.statusInactive,
        style: TextStyle(
          color: aktiv ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: buttonColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, int> klicks;
  const _StatsRow({required this.klicks});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('👁', 'Aufrufe',  klicks['aufrufe'] ?? 0),
      ('📞', 'Anrufe',   klicks['anrufen'] ?? 0),
      ('🌐', 'Website',  klicks['website'] ?? 0),
      ('✉️', 'E-Mail',   klicks['email']   ?? 0),
    ];
    return Row(
      children: items.map((e) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03), blurRadius: 4),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.$1, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text('${e.$3}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy)),
                Text(e.$2,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.grey)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProfileCompleteness extends StatelessWidget {
  final Partner partner;
  const _ProfileCompleteness({required this.partner});

  List<String> get _missing {
    final items = <String>[];
    if (partner.logo.isEmpty) items.add('Logo');
    if (partner.leistungen.length < 30) items.add('Leistungsbeschreibung');
    if (partner.oeffnungszeiten.isEmpty) items.add('Öffnungszeiten');
    if (partner.website.isEmpty) items.add('Website');
    if (partner.email.isEmpty) items.add('E-Mail');
    if (partner.photos.isEmpty) items.add('Fotos');
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final total = 6;
    final done = total - _missing.length;
    final pct = done / total;
    final isComplete = _missing.isEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isComplete ? Icons.check_circle : Icons.edit_note,
                size: 18,
                color: isComplete ? Colors.green : AppColors.orange),
            const SizedBox(width: 8),
            Text('Profil-Vollständigkeit',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                    fontSize: 13)),
            const Spacer(),
            Text('$done/$total',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isComplete ? Colors.green : AppColors.orange,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                  isComplete ? Colors.green : AppColors.orange),
            ),
          ),
          if (_missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _missing
                  .map((m) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(m,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.orange)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.grey),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.grey))),
      ]),
    );
  }
}
