import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/partner.dart';
import '../../services/partner_service.dart';
import '../../widgets/partner_card.dart';
import '../../widgets/category_chip.dart';
import '../../utils/seed_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _partnerService = PartnerService();
  String? _selectedCategory;

  void _openMenu(BuildContext context) {
    final auth = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              // Für Partnerbetriebe
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
                        const Text(
                          'Für Partnerbetriebe',
                          style: TextStyle(
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
                        title: const Text('Partner-Login'),
                        subtitle: const Text('Für bereits registrierte Betriebe'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/login');
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.app_registration, color: AppColors.orange),
                        title: const Text('Als Partner registrieren'),
                        subtitle: const Text('Jetzt Betrieb eintragen'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/register');
                        },
                      ),
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.dashboard_outlined, color: AppColors.navy),
                        title: const Text('Mein Dashboard'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/dashboard');
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined, color: AppColors.grey),
                  title: const Text('Testdaten einfügen'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await seedPartners();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Testdaten eingefügt!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
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
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        toolbarHeight: 70,
        titleSpacing: 12,
        title: Container(
          width: 56,
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/images/logo1.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text(
                'MB',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
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
            onPressed: () => _openMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(child: _buildPartnerList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () => context.push('/search'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: AppColors.grey),
              SizedBox(width: 10),
              Text('Werkstatt, Lackiererei suchen...',
                  style: TextStyle(color: AppColors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          CategoryChip(
            label: 'Alle',
            selected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          ...kCategories.map((c) => CategoryChip(
                label: c,
                selected: _selectedCategory == c,
                onTap: () => setState(() => _selectedCategory = c),
              )),
        ],
      ),
    );
  }

  Widget _buildPartnerList() {
    return StreamBuilder<List<Partner>>(
      stream: _partnerService.getPartners(category: _selectedCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final partners = snapshot.data ?? [];
        if (partners.isEmpty) {
          return const Center(
            child: Text('Keine Betriebe gefunden.',
                style: TextStyle(color: AppColors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: partners.length,
          itemBuilder: (_, i) => PartnerCard(partner: partners[i]),
        );
      },
    );
  }
}
