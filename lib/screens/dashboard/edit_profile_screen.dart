import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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
  List<String> _photoUrls = [];
  bool _uploadingPhotos = false;
  final Map<String, TextEditingController> _zusatzTelefon = {};
  final Map<String, TextEditingController> _zusatzInfo = {};

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
    _photoUrls = List<String>.from(p.photos);

    // Init per-category controllers for already-selected zusatz categories
    final zusatzOptionen = kZusatzKategorien[p.kategorie] ?? [];
    for (final kat in zusatzOptionen) {
      if (_selectedZusatz.contains(kat)) {
        _zusatzTelefon[kat] = TextEditingController(text: p.zusatzTelefon[kat] ?? '');
        _zusatzInfo[kat] = TextEditingController(text: p.zusatzInfo[kat] ?? '');
      }
    }
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
    for (final c in _zusatzTelefon.values) c.dispose();
    for (final c in _zusatzInfo.values) c.dispose();
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

  Future<void> _pickPhotos() async {
    if (_photoUrls.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximal 6 Fotos erlaubt.')),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1024);
    if (picked.isEmpty) return;
    final remaining = 6 - _photoUrls.length;
    final toUpload = picked.take(remaining).toList();
    setState(() => _uploadingPhotos = true);
    try {
      final uid = context.read<AuthService>().currentUser!.uid;
      for (final xfile in toUpload) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance.ref('photos/$uid/$ts');
        await ref.putFile(File(xfile.path));
        final url = await ref.getDownloadURL();
        setState(() => _photoUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto-Upload fehlgeschlagen: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhotos = false);
    }
  }

  Future<void> _deletePhoto(String url) async {
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {}
    setState(() => _photoUrls.remove(url));
  }

  Future<Map<String, double>?> _geocode(String adresse, String plz, String ort) async {
    try {
      final q = Uri.encodeComponent('$adresse, $plz $ort');
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$q&format=json&limit=1&countrycodes=at,de,ch');
      final resp = await http.get(url,
          headers: {'User-Agent': 'MoveBase/1.0 (contact@movebase.at)'});
      if (resp.statusCode == 200) {
        final results = jsonDecode(resp.body) as List;
        if (results.isNotEmpty) {
          final lat = double.tryParse(results[0]['lat']?.toString() ?? '');
          final lng = double.tryParse(results[0]['lon']?.toString() ?? '');
          if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
        }
      }
    } catch (_) {}
    return null;
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
        'zusatzTelefon': Map.fromEntries(
          _zusatzTelefon.entries
              .where((e) => e.value.text.trim().isNotEmpty)
              .map((e) => MapEntry(e.key, e.value.text.trim())),
        ),
        'zusatzInfo': Map.fromEntries(
          _zusatzInfo.entries
              .where((e) => e.value.text.trim().isNotEmpty)
              .map((e) => MapEntry(e.key, e.value.text.trim())),
        ),
      };
      if (_logoUrl != null) data['logo'] = _logoUrl;
      data['photos'] = _photoUrls;

      // Geocode address → save coordinates
      final coords = await _geocode(
          _adresse.text.trim(), _plz.text.trim(), _ort.text.trim());
      if (coords != null) {
        data['firmaLatitude'] = coords['lat'];
        data['firmaLongitude'] = coords['lng'];
      }

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

            // Fotos
            _section('Fotos (max. 6)'),
            if (_photoUrls.isNotEmpty) ...[
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _photoUrls[i],
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 110,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined,
                                color: AppColors.grey),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _deletePhoto(_photoUrls[i]),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_uploadingPhotos)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_photoUrls.length < 6)
              TextButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_photoUrls.isEmpty
                    ? 'Fotos hinzufügen'
                    : 'Weitere Fotos hinzufügen'),
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
              ...zusatzOptionen.map((kat) {
                final isSelected = _selectedZusatz.contains(kat);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text(kat),
                      value: isSelected,
                      activeColor: AppColors.navy,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedZusatz.add(kat);
                            _zusatzTelefon[kat] = TextEditingController();
                            _zusatzInfo[kat] = TextEditingController();
                          } else {
                            _selectedZusatz.remove(kat);
                            _zusatzTelefon[kat]?.dispose();
                            _zusatzTelefon.remove(kat);
                            _zusatzInfo[kat]?.dispose();
                            _zusatzInfo.remove(kat);
                          }
                        });
                      },
                    ),
                    if (isSelected) ...[
                      Container(
                        margin: const EdgeInsets.only(left: 12, bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.navy.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kat,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppColors.navy)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _zusatzTelefon[kat],
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: 'Separate Notfallnummer (optional)',
                                hintStyle:
                                    const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(
                                    Icons.phone_outlined,
                                    size: 18,
                                    color: AppColors.grey),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _zusatzInfo[kat],
                              decoration: InputDecoration(
                                hintText:
                                    'Info-Text (optional – z.B. Erreichbarkeit)',
                                hintStyle:
                                    const TextStyle(fontSize: 13),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }),
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
                maxLines: 5, maxLength: 700),
            const SizedBox(height: 20),

            // Ersatzwagen-Hinweis — nur wenn Ersatzwagen ausgewählt
            if (_selectedZusatz.contains('Ersatzwagen')) ...[
              _section('Ersatzwagen-Hinweis'),
              _field(_ersatzwagenHinweis, 'Hinweis zum Ersatzwagen...',
                  Icons.directions_car_outlined,
                  maxLines: 3, maxLength: 150),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 12),

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
      {int maxLines = 1, bool required = false, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        maxLength: maxLength,
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
