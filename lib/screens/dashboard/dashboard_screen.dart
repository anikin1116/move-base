import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/partner.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';

const _apiBase = 'https://www.crashlog.eu';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mein Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
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
            return const Center(
                child: Text('Kein Partnerprofil gefunden.',
                    style: TextStyle(color: AppColors.grey)));
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
    final paket = partner.paket.isEmpty ? 'basic' : partner.paket;
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
          'quantity': 1,
          'lang': 'de',
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
              content: Text('Checkout fehlgeschlagen: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openCustomerPortal(BuildContext context) async {
    final uri = Uri.parse('$_apiBase/api/customer-portal').replace(
      queryParameters: {'email': partner.email},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link konnte nicht geöffnet werden.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

        const SizedBox(height: 24),

        // Abo-Aktionen
        if (!partner.aktiv)
          _ActionCard(
            icon: Icons.payment,
            title: 'Abo noch nicht aktiv',
            subtitle: 'Schließen Sie Ihr CrashLog-Abo ab, um Ihr Profil zu aktivieren.',
            buttonLabel: 'Jetzt abschließen →',
            buttonColor: AppColors.orange,
            onTap: () => _openCheckout(context),
          )
        else
          _ActionCard(
            icon: Icons.workspace_premium,
            title: 'Paket: ${partner.paket.toUpperCase()}',
            subtitle: 'Abo aktiv. Kündigung oder Änderung jederzeit möglich.',
            buttonLabel: 'Abo verwalten',
            buttonColor: AppColors.navy,
            onTap: () => _openCustomerPortal(context),
          ),

        const SizedBox(height: 24),

        // Betriebsdaten
        const Text('Betriebsdaten',
            style: TextStyle(
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

        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined, color: AppColors.navy),
          label: const Text('Profil bearbeiten',
              style: TextStyle(color: AppColors.navy)),
          onPressed: () => context.push('/edit-profile', extra: partner),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.navy),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: aktiv ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        aktiv ? 'Aktiv' : 'Inaktiv',
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
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.navy)),
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
