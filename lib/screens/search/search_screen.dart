import 'package:flutter/material.dart';
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
  List<Partner> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    // TODO: LLM-powered search
    setState(() {
      _results = [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'z.B. Lackiererei nahe Wien...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _search,
        ),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(
                  child: Text('Suchbegriff eingeben...',
                      style: TextStyle(color: AppColors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  itemBuilder: (_, i) => PartnerCard(partner: _results[i]),
                ),
    );
  }
}
