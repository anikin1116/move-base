import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/partner.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final Partner partner;
  const EditProfileScreen({super.key, required this.partner});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _telefon;
  late final TextEditingController _website;
  late final TextEditingController _oeffnungszeiten;
  late final TextEditingController _leistungen;
  late final TextEditingController _ersatzwagenHinweis;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.partner;
    _telefon = TextEditingController(text: p.telefon);
    _website = TextEditingController(text: p.website);
    _oeffnungszeiten = TextEditingController(text: p.oeffnungszeiten);
    _leistungen = TextEditingController(text: p.leistungen);
    _ersatzwagenHinweis = TextEditingController(text: p.ersatzwagenHinweis);
  }

  @override
  void dispose() {
    _telefon.dispose();
    _website.dispose();
    _oeffnungszeiten.dispose();
    _leistungen.dispose();
    _ersatzwagenHinweis.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = context.read<AuthService>().currentUser!.uid;
      await PartnerService().updateProfile(uid, {
        'telefon': _telefon.text.trim(),
        'website': _website.text.trim(),
        'oeffnungszeiten': _oeffnungszeiten.text.trim(),
        'leistungen': _leistungen.text.trim(),
        'ersatzwagenHinweis': _ersatzwagenHinweis.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil gespeichert.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil bearbeiten'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Speichern',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('Kontakt'),
            _field(_telefon, 'Telefon', Icons.phone_outlined),
            _field(_website, 'Website', Icons.language_outlined),
            const SizedBox(height: 20),
            _section('Öffnungszeiten'),
            _field(_oeffnungszeiten, 'z.B. Mo–Fr 8–17 Uhr',
                Icons.access_time_outlined,
                maxLines: 3),
            const SizedBox(height: 20),
            _section('Leistungsbeschreibung'),
            _field(_leistungen, 'Beschreiben Sie Ihre Leistungen...',
                Icons.description_outlined,
                maxLines: 5),
            const SizedBox(height: 20),
            _section('Ersatzwagen-Hinweis'),
            _field(_ersatzwagenHinweis, 'Hinweis zum Ersatzwagen...',
                Icons.directions_car_outlined,
                maxLines: 3),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.navy)),
      );

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
