import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

  late final TextEditingController _name;
  late final TextEditingController _adresse;
  late final TextEditingController _plz;
  late final TextEditingController _ort;
  late final TextEditingController _telefon;
  late final TextEditingController _website;
  late final TextEditingController _oeffnungszeiten;
  late final TextEditingController _leistungen;
  late final TextEditingController _ersatzwagenHinweis;

  late List<String> _selectedZusatz;
  String? _logoUrl;
  File? _pickedLogo;
  bool _saving = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final p = widget.partner;
    _name = TextEditingController(text: p.name);
    _adresse = TextEditingController(text: p.adresse);
    _plz = TextEditingController(text: p.plz);
    _ort = TextEditingController(text: p.ort);
    _telefon = TextEditingController(text: p.telefon);
    _website = TextEditingController(text: p.website);
    _oeffnungszeiten = TextEditingController(text: p.oeffnungszeiten);
    _leistungen = TextEditingController(text: p.leistungen);
    _ersatzwagenHinweis = TextEditingController(text: p.ersatzwagenHinweis);
    _selectedZusatz = List<String>.from(p.kategorien);
    _logoUrl = p.logo.isEmpty ? null : p.logo;
  }

  @override
  void dispose() {
    _name.dispose();
    _adresse.dispose();
    _plz.dispose();
    _ort.dispose();
    _telefon.dispose();
    _website.dispose();
    _oeffnungszeiten.dispose();
    _leistungen.dispose();
    _ersatzwagenHinweis.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (picked == null) return;
    setState(() {
      _pickedLogo = File(picked.path);
      _uploadingLogo = true;
    });
    try {
      final uid = context.read<AuthService>().currentUser!.uid;
      final ref = FirebaseStorage.instance.ref('logos/$uid');
      await ref.putFile(_pickedLogo!);
      final url = await ref.getDownloadURL();
      setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Logo-Upload fehlgeschlagen: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = context.read<AuthService>().currentUser!.uid;
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'adresse': _adresse.text.trim(),
        'plz': _plz.text.trim(),
        'ort': _ort.text.trim(),
        'telefon': _telefon.text.trim(),
        'website': _website.text.trim(),
        'oeffnungszeiten': _oeffnungszeiten.text.trim(),
        'leistungen': _leistungen.text.trim(),
        'ersatzwagenHinweis': _ersatzwagenHinweis.text.trim(),
        'kategorien': _selectedZusatz,
      };
      if (_logoUrl != null) data['logo'] = _logoUrl;
      await PartnerService().updateProfile(uid, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil gespeichert.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zusatzOptionen =
        kZusatzKategorien[widget.partner.kategorie] ?? [];

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
            // Logo
            _section('Logo'),
            GestureDetector(
              onTap: _uploadingLogo ? null : _pickLogo,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _uploadingLogo
                    ? const Center(child: CircularProgressIndicator())
                    : _pickedLogo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_pickedLogo!,
                                fit: BoxFit.contain),
                          )
                        : _logoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(_logoUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        _logoPlaceholder()),
                              )
                            : _logoPlaceholder(),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _uploadingLogo ? null : _pickLogo,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Logo auswählen'),
            ),
            const SizedBox(height: 20),

            // Stammdaten
            _section('Stammdaten'),
            _field(_name, 'Firmenname', Icons.business_outlined,
                required: true),
            _field(_adresse, 'Adresse', Icons.location_on_outlined,
                required: true),
            Row(children: [
              SizedBox(
                width: 110,
                child: _field(_plz, 'PLZ', Icons.markunread_mailbox_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(_ort, 'Ort', Icons.location_city_outlined)),
            ]),
            const SizedBox(height: 20),

            // Kontakt
            _section('Kontakt'),
            _field(_telefon, 'Telefon', Icons.phone_outlined),
            _field(_website, 'Website', Icons.language_outlined),
            const SizedBox(height: 20),

            // Zusatzkategorien
            if (zusatzOptionen.isNotEmpty) ...[
              _section('Zusatzleistungen'),
              ...zusatzOptionen.map((kat) => CheckboxListTile(
                    title: Text(kat),
                    value: _selectedZusatz.contains(kat),
                    activeColor: AppColors.navy,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedZusatz.add(kat);
                        } else {
                          _selectedZusatz.remove(kat);
                        }
                      });
                    },
                  )),
              const SizedBox(height: 20),
            ],

            // Öffnungszeiten
            _section('Öffnungszeiten'),
            _field(_oeffnungszeiten, 'z.B. Mo–Fr 8–17 Uhr',
                Icons.access_time_outlined,
                maxLines: 3),
            const SizedBox(height: 20),

            // Leistungen
            _section('Leistungsbeschreibung'),
            _field(_leistungen, 'Beschreiben Sie Ihre Leistungen...',
                Icons.description_outlined,
                maxLines: 5),
            const SizedBox(height: 20),

            // Ersatzwagen
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _logoPlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_photo_alternate_outlined,
              size: 36, color: AppColors.grey),
          SizedBox(height: 6),
          Text('Logo hochladen', style: TextStyle(color: AppColors.grey)),
        ],
      );

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.navy)),
      );

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        validator: required && maxLines == 1
            ? (v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null
            : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: maxLines == 1
              ? Icon(icon, color: AppColors.grey)
              : null,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
