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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        toolbarHeight: 70,
        titleSpacing: 12,
        title: Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          padding: EdgeInsets.zero,
          child: Transform.scale(
            scale: 1.5,
            child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
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
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Testdaten einfügen',
              onPressed: () async {
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
          if (auth.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: () => context.push('/dashboard'),
            )
          else ...[
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('Registrieren',
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Login',
                  style: TextStyle(color: AppColors.orange)),
            ),
          ],
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
