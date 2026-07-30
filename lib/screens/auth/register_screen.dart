import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../models/partner.dart';

// CrashLog backend base URL
const _apiBase = 'https://www.crashlog.eu';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1 – Firmendaten
  final _nameCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _plzCtrl = TextEditingController();
  final _ortCtrl = TextEditingController();
  final _telefonCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _oeffnungCtrl = TextEditingController();
  final _beraterCtrl = TextEditingController();
  final _leistungenCtrl = TextEditingController();
  String _kategorie = kCategories.first;
  String _land = 'AT';
  List<String> _zusatzKategorien = [];
  Map<String, TextEditingController> _zusatzTelefonCtrl = {};

  // Step 2 – Paket
  String? _selectedPaketId;
  String _billing = 'monthly';

  // Step 3 – Zugangsdaten
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  bool _loading = false;

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _nameCtrl, _adresseCtrl, _plzCtrl, _ortCtrl, _telefonCtrl,
      _websiteCtrl, _oeffnungCtrl, _beraterCtrl, _leistungenCtrl,
      _emailCtrl, _passwordCtrl, _confirmCtrl,
    ]) c.dispose();
    for (final c in _zusatzTelefonCtrl.values) c.dispose();
    super.dispose();
  }

  List<Paket> get _pakete => paketeForKategorie(_kategorie);

  bool get _needsBerater =>
      _kategorie == 'Versicherungsmakler' || _kategorie == 'KFZ Sachverständiger';

  void _goTo(int step) {
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentStep = step);
  }

  bool _validateStep1() {
    if (_nameCtrl.text.trim().isEmpty) { _err('Firmenname ist erforderlich.'); return false; }
    if (_ortCtrl.text.trim().isEmpty) { _err('Stadt ist erforderlich.'); return false; }
    if (_telefonCtrl.text.trim().isEmpty) { _err('Telefonnummer ist erforderlich.'); return false; }
    return true;
  }

  bool _validateStep2() {
    if (_selectedPaketId == null) { _err('Bitte wählen Sie ein Paket.'); return false; }
    return true;
  }

  bool _validateStep3() {
    if (!_emailCtrl.text.contains('@')) { _err('Bitte eine gültige E-Mail-Adresse eingeben.'); return false; }
    if (_passwordCtrl.text.length < 8) { _err('Passwort muss mindestens 8 Zeichen haben.'); return false; }
    if (_passwordCtrl.text != _confirmCtrl.text) { _err('Passwörter stimmen nicht überein.'); return false; }
    return true;
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _submit() async {
    if (!_validateStep3()) return;
    setState(() => _loading = true);

    try {
      final auth = context.read<AuthService>();
      final cred = await auth.register(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (cred == null) throw Exception('Registrierung fehlgeschlagen.');

      final uid = cred.user!.uid;
      final paket = _pakete.firstWhere((p) => p.id == _selectedPaketId!);

      final zusatzTelefon = <String, String>{};
      for (final k in _zusatzTelefonCtrl.keys) {
        final v = _zusatzTelefonCtrl[k]!.text.trim();
        if (v.isNotEmpty) zusatzTelefon[k] = v;
      }

      await PartnerService().createProfile(uid, {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'kategorie': _kategorie,
        'kategorien': [_kategorie, ..._zusatzKategorien],
        'adresse': _adresseCtrl.text.trim(),
        'plz': _plzCtrl.text.trim(),
        'ort': _ortCtrl.text.trim(),
        'land': _land,
        'telefon': _telefonCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'oeffnungszeiten': _oeffnungCtrl.text.trim(),
        'berater': _beraterCtrl.text.trim(),
        'leistungen': _leistungenCtrl.text.trim(),
        'logo': '',
        'aktiv': false,
        'paket': _selectedPaketId,
        'prioritaet': paket.prioritaet,
        'standorte': 1,
        'erstellt': FieldValue.serverTimestamp(),
        'zusatzTelefon': zusatzTelefon,
        'zusatzInfo': <String, String>{},
      });

      if (!mounted) return;
      setState(() => _loading = false);
      _goTo(3); // Stripe step

      // Open Stripe checkout
      await _openStripe(uid, paket);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _err('Fehler: $e');
      }
    }
  }

  Future<void> _openStripe(String uid, Paket paket) async {
    // Calls the existing CrashLog backend /api/checkout endpoint
    final uri = Uri.parse('$_apiBase/api/checkout').replace(queryParameters: {
      'paket': paket.id,
      'billing': _billing,
      'uid': uid,
      'email': _emailCtrl.text.trim(),
      'firmaName': Uri.encodeComponent(_nameCtrl.text.trim()),
      'quantity': '1',
      'lang': 'de',
    });
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _currentStep > 0 && _currentStep < 3
            ? BackButton(onPressed: () => _goTo(_currentStep - 1))
            : BackButton(onPressed: () => context.pop()),
        title: Text(_stepTitle()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 4,
            backgroundColor: AppColors.navy.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation(AppColors.orange),
            minHeight: 4,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1Firma(),
          _buildStep2Paket(),
          _buildStep3Zugangsdaten(),
          _buildStep4Done(),
        ],
      ),
    );
  }

  String _stepTitle() {
    switch (_currentStep) {
      case 0: return 'Firmendaten';
      case 1: return 'Paket wählen';
      case 2: return 'Zugangsdaten';
      default: return 'Abschluss';
    }
  }

  Widget _buildStep1Firma() {
    final zusatzOptions = kZusatzKategorien[_kategorie] ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Firmenname *', _nameCtrl),
          const SizedBox(height: 16),
          _kategoriePicker(),
          const SizedBox(height: 16),
          _landPicker(),
          const SizedBox(height: 16),
          _field('Straße und Hausnummer', _adresseCtrl),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(width: 100, child: _field('PLZ', _plzCtrl, keyboard: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _field('Stadt *', _ortCtrl)),
          ]),
          const SizedBox(height: 16),
          _field('Telefon *', _telefonCtrl, keyboard: TextInputType.phone),
          const SizedBox(height: 16),
          _field('Website (optional)', _websiteCtrl, keyboard: TextInputType.url),
          const SizedBox(height: 16),
          _field('Öffnungszeiten', _oeffnungCtrl, hint: 'z.B. Mo–Fr 08:00–18:00'),
          if (_needsBerater) ...[
            const SizedBox(height: 16),
            _field('Berater / Sachverständiger Name', _beraterCtrl),
          ],
          const SizedBox(height: 16),
          _field('Leistungen', _leistungenCtrl, maxLines: 4,
              hint: 'Was bieten Sie an? (max. 700 Zeichen)'),
          if (zusatzOptions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Zusatzleistungen',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            ...zusatzOptions.map((kat) {
              final selected = _zusatzKategorien.contains(kat);
              return CheckboxListTile(
                title: Text(kat),
                value: selected,
                activeColor: AppColors.orange,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _zusatzKategorien.add(kat);
                      _zusatzTelefonCtrl[kat] = TextEditingController();
                    } else {
                      _zusatzKategorien.remove(kat);
                      _zusatzTelefonCtrl.remove(kat);
                    }
                  });
                },
              );
            }),
            ..._zusatzKategorien.map((kat) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _field('Telefon $kat (optional)', _zusatzTelefonCtrl[kat]!,
                  keyboard: TextInputType.phone),
            )),
          ],
          const SizedBox(height: 32),
          _primaryBtn('Weiter', () { if (_validateStep1()) _goTo(1); }),
        ],
      ),
    );
  }

  Widget _buildStep2Paket() {
    final pakete = _pakete;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Abrechnungszeitraum',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'monthly', label: Text('Monatlich')),
              ButtonSegment(value: 'yearly', label: Text('Jährlich (–17%)'),),
            ],
            selected: {_billing},
            onSelectionChanged: (s) => setState(() => _billing = s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? AppColors.orange : null),
            ),
          ),
          const SizedBox(height: 24),
          ...pakete.map((paket) => _PaketCard(
            paket: paket,
            billing: _billing,
            selected: _selectedPaketId == paket.id,
            onTap: () => setState(() => _selectedPaketId = paket.id),
          )),
          const SizedBox(height: 32),
          _primaryBtn('Weiter', () { if (_validateStep2()) _goTo(2); }),
        ],
      ),
    );
  }

  Widget _buildStep3Zugangsdaten() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Zugangsdaten erstellen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Diese verwenden Sie künftig zur Anmeldung in Ihrem Dashboard.',
              style: TextStyle(color: AppColors.grey)),
          const SizedBox(height: 32),
          _field('E-Mail-Adresse', _emailCtrl, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _field('Passwort (min. 8 Zeichen)', _passwordCtrl,
              obscure: _obscurePass,
              toggleObscure: () => setState(() => _obscurePass = !_obscurePass)),
          const SizedBox(height: 16),
          _field('Passwort bestätigen', _confirmCtrl,
              obscure: _obscureConfirm,
              toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm)),
          const SizedBox(height: 32),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _primaryBtn('Registrieren & zur Zahlung', _submit),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Bereits registriert? Hier anmelden',
                  style: TextStyle(color: AppColors.navy)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Done() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text('Registrierung abgeschlossen!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Nach erfolgreicher Zahlung wird Ihr Betrieb freigeschaltet. Bitte prüfen Sie auch Ihre E-Mail-Adresse.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 32),
            _primaryBtn('Zum Dashboard', () => context.go('/dashboard')),
          ],
        ),
      ),
    );
  }

  Widget _kategoriePicker() {
    return DropdownButtonFormField<String>(
      value: _kategorie,
      decoration: InputDecoration(
        labelText: 'Kategorie',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => setState(() {
        _kategorie = v!;
        _zusatzKategorien.clear();
        _zusatzTelefonCtrl.clear();
        _selectedPaketId = null;
      }),
    );
  }

  Widget _landPicker() {
    return DropdownButtonFormField<String>(
      value: _land,
      decoration: InputDecoration(
        labelText: 'Land',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: const [
        DropdownMenuItem(value: 'AT', child: Text('Österreich')),
        DropdownMenuItem(value: 'DE', child: Text('Deutschland')),
        DropdownMenuItem(value: 'CH', child: Text('Schweiz')),
      ],
      onChanged: (v) => setState(() => _land = v!),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard, bool obscure = false, VoidCallback? toggleObscure,
      int maxLines = 1, String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: toggleObscure)
            : null,
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _PaketCard extends StatelessWidget {
  final Paket paket;
  final String billing;
  final bool selected;
  final VoidCallback onTap;

  const _PaketCard({
    required this.paket,
    required this.billing,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = billing == 'yearly' ? paket.jaehrlich : paket.monatlich;
    final unit = billing == 'yearly' ? '/Jahr' : '/Monat';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.orange : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paket.label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: selected ? Colors.white : AppColors.navy)),
                  if (paket.id.contains('premium'))
                    Text('Höhere Sichtbarkeit & Priorität',
                        style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white70 : AppColors.grey)),
                ],
              ),
            ),
            Text(
              '€ ${price.toStringAsFixed(2)}$unit',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: selected ? AppColors.orange : AppColors.navy),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: AppColors.orange),
              ),
          ],
        ),
      ),
    );
  }
}
