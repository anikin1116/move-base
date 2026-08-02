import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../models/partner.dart';

const _apiBase = 'https://crashlog.eu';

String _localizedCategory(AppLocalizations l10n, String cat) {
  switch (cat) {
    case 'Werkstatt': return l10n.catWerkstatt;
    case 'Abschleppdienst': return l10n.catAbschleppdienst;
    case 'Ersatzwagen': return l10n.catErsatzwagen;
    case 'Hotel': return l10n.catHotel;
    case 'Taxi': return l10n.catTaxi;
    case 'Versicherungsmakler': return l10n.catVersicherungsmakler;
    case 'KFZ Sachverständiger': return l10n.catSachverstaendiger;
    default: return cat;
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1
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

  // Step 2
  String? _selectedPaketId;
  String _billing = 'monthly';
  int _standorte = 1;

  // Step 3
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  bool _loading = false;

  // Address autocomplete
  List<_AddressSuggestion> _suggestions = [];
  bool _adresseSearching = false;
  double? _adresseLat;
  double? _adresseLng;
  Timer? _adresseTimer;
  Timer? _plzTimer;

  @override
  void initState() {
    super.initState();
    _plzCtrl.addListener(_onPlzChanged);
  }

  @override
  void dispose() {
    _adresseTimer?.cancel();
    _plzTimer?.cancel();
    _plzCtrl.removeListener(_onPlzChanged);
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
    final l10n = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty) { _err(l10n.validationCompanyRequired); return false; }
    if (_adresseCtrl.text.trim().isEmpty) { _err(l10n.validationStreetRequired); return false; }
    if (_plzCtrl.text.trim().isEmpty) { _err(l10n.validationPostalRequired); return false; }
    if (_ortCtrl.text.trim().isEmpty) { _err(l10n.validationCityRequired); return false; }
    if (_telefonCtrl.text.trim().isEmpty) { _err(l10n.validationPhoneRequired); return false; }
    return true;
  }

  // ── Address autocomplete ──────────────────────────────────────────────────

  void _onAdresseChanged(String val) {
    _adresseTimer?.cancel();
    if (val.trim().length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _adresseTimer = Timer(
      const Duration(milliseconds: 700),
      () => _searchAddress(val.trim()),
    );
  }

  Future<void> _searchAddress(String query) async {
    if (!mounted) return;
    setState(() => _adresseSearching = true);
    try {
      final cc = _land.toLowerCase();
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'countrycodes': cc,
        'accept-language': 'de',
      });
      final response = await http.get(uri,
          headers: {'User-Agent': 'MoveBase/1.0 (contact@movebase.at)'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        final suggestions = results
            .map((e) => _AddressSuggestion.fromJson(e as Map<String, dynamic>))
            .where((s) => s.road.isNotEmpty && s.postcode.isNotEmpty)
            .toList();
        setState(() => _suggestions = suggestions);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _adresseSearching = false);
    }
  }

  void _onPlzChanged() {
    _plzTimer?.cancel();
    final plz = _plzCtrl.text.trim();
    final minLen = _land == 'DE' ? 5 : 4;
    if (plz.length < minLen) return;
    _plzTimer = Timer(
      const Duration(milliseconds: 800),
      () => _lookupCity(plz),
    );
  }

  Future<void> _lookupCity(String plz) async {
    if (!mounted) return;
    try {
      final cc = _land.toLowerCase();
      final response = await http.get(
          Uri.parse('https://api.zippopotam.us/$cc/$plz'));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List?;
        if (places != null && places.isNotEmpty) {
          final city = places.first['place name'] as String;
          if (_ortCtrl.text.isEmpty) setState(() => _ortCtrl.text = city);
        }
      }
    } catch (_) {}
  }

  bool _validateStep2() {
    final l10n = AppLocalizations.of(context);
    if (_selectedPaketId == null) { _err(l10n.validationSelectPackage); return false; }
    return true;
  }

  bool _validateStep3() {
    final l10n = AppLocalizations.of(context);
    if (!_emailCtrl.text.contains('@')) { _err(l10n.validationValidEmail); return false; }
    if (_passwordCtrl.text.length < 8) { _err(l10n.validationPasswordMin8); return false; }
    if (_passwordCtrl.text != _confirmCtrl.text) { _err(l10n.passwordsDoNotMatch); return false; }
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
      if (cred == null) throw Exception(AppLocalizations.of(context).registrationFailed);

      final uid = cred.user!.uid;

      // Bestätigungs-E-Mail via Resend — fire and forget
      http.post(
        Uri.parse('$_apiBase/api/send-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailCtrl.text.trim()}),
      ).ignore();
      final paket = _pakete.firstWhere((p) => p.id == _selectedPaketId!);

      final zusatzTelefon = <String, String>{};
      for (final k in _zusatzTelefonCtrl.keys) {
        final v = _zusatzTelefonCtrl[k]!.text.trim();
        if (v.isNotEmpty) zusatzTelefon[k] = v;
      }

      await PartnerService().createProfile(uid, {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'kategorie': _kategorie,           // DE-Wert für Firestore
        'kategorien': [_kategorie, ..._zusatzKategorien],
        'adresse': _adresseCtrl.text.trim(),
        'plz': _plzCtrl.text.trim(),
        'ort': _ortCtrl.text.trim(),
        'land': _land,
        if (_adresseLat != null) 'firmaLatitude': _adresseLat,
        if (_adresseLng != null) 'firmaLongitude': _adresseLng,
        'telefon': _telefonCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'oeffnungszeiten': _oeffnungCtrl.text.trim(),
        'berater': _beraterCtrl.text.trim(),
        'leistungen': _leistungenCtrl.text.trim(),
        'logo': '',
        'aktiv': false,
        'paket': _selectedPaketId,
        'prioritaet': paket.prioritaet,
        'standorte': _standorte,
        'erstellt': FieldValue.serverTimestamp(),
        'zusatzTelefon': zusatzTelefon,
        'zusatzInfo': <String, String>{},
      });

      if (!mounted) return;
      setState(() => _loading = false);
      _goTo(3);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _err('${AppLocalizations.of(context).errorPrefix} $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: _currentStep > 0 && _currentStep < 3
            ? BackButton(onPressed: () => _goTo(_currentStep - 1))
            : BackButton(onPressed: () => context.pop()),
        title: Text(_stepTitle(l10n)),
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
          _buildStep1Firma(l10n),
          _buildStep2Paket(l10n),
          _buildStep3Zugangsdaten(l10n),
          _buildStep4Done(l10n),
        ],
      ),
    );
  }

  String _stepTitle(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0: return l10n.step1Title;
      case 1: return l10n.step2Title;
      case 2: return l10n.step3Title;
      default: return l10n.finish;
    }
  }

  Widget _buildStep1Firma(AppLocalizations l10n) {
    final zusatzOptions = kZusatzKategorien[_kategorie] ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('${l10n.companyName} *', _nameCtrl),
          const SizedBox(height: 16),
          _kategoriePicker(l10n),
          const SizedBox(height: 16),
          _landPicker(l10n),
          const SizedBox(height: 16),
          _buildAdresseField(l10n),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(
                width: 100,
                child: _field('${l10n.postalCode} *', _plzCtrl,
                    keyboard: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _field('${l10n.city} *', _ortCtrl)),
          ]),
          const SizedBox(height: 16),
          _field('${l10n.phone} *', _telefonCtrl,
              keyboard: TextInputType.phone),
          const SizedBox(height: 16),
          _field('${l10n.website} (optional)', _websiteCtrl,
              keyboard: TextInputType.url),
          const SizedBox(height: 16),
          _field(l10n.openingHours, _oeffnungCtrl,
              hint: l10n.openingHoursHint),
          if (_needsBerater) ...[
            const SizedBox(height: 16),
            _field(l10n.advisorName, _beraterCtrl),
          ],
          const SizedBox(height: 16),
          _field(l10n.servicesDescription, _leistungenCtrl,
              maxLines: 4, hint: l10n.servicesHint),
          if (zusatzOptions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.additionalServicesSection,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            ...zusatzOptions.map((kat) {
              final selected = _zusatzKategorien.contains(kat);
              return CheckboxListTile(
                title: Text(_localizedCategory(l10n, kat)),
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
                  child: _field(
                      '${l10n.phone} ${_localizedCategory(l10n, kat)} (optional)',
                      _zusatzTelefonCtrl[kat]!,
                      keyboard: TextInputType.phone),
                )),
          ],
          const SizedBox(height: 32),
          _primaryBtn(l10n.next,
              () { if (_validateStep1()) _goTo(1); }),
        ],
      ),
    );
  }

  Widget _buildStep2Paket(AppLocalizations l10n) {
    final pakete = _pakete;
    final hasDiscount = _standorte >= 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.billingCycle,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'monthly', label: Text(l10n.monthly)),
              ButtonSegment(value: 'yearly', label: Text(l10n.yearlyDiscount)),
            ],
            selected: {_billing},
            onSelectionChanged: (s) => setState(() => _billing = s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? AppColors.orange
                      : null),
            ),
          ),
          const SizedBox(height: 24),
          // Standorte-Stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.navy, size: 20),
                  const SizedBox(width: 8),
                  const Text('Anzahl Standorte',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  IconButton(
                    onPressed: _standorte > 1
                        ? () => setState(() => _standorte--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.orange,
                    iconSize: 30,
                  ),
                  Expanded(
                    child: Text(
                      '$_standorte',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy),
                    ),
                  ),
                  IconButton(
                    onPressed: _standorte < 20
                        ? () => setState(() => _standorte++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.orange,
                    iconSize: 30,
                  ),
                ]),
                if (hasDiscount)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(children: [
                      Icon(Icons.local_offer_outlined,
                          size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text('20% Mengenrabatt ab 2 Standorten',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...pakete.map((paket) {
            final basePrice = _billing == 'yearly' ? paket.jaehrlich : paket.monatlich;
            final total = hasDiscount
                ? basePrice * _standorte * 0.8
                : basePrice * _standorte;
            return _PaketCard(
              paket: paket,
              billing: _billing,
              standorte: _standorte,
              totalPrice: total,
              hasDiscount: hasDiscount,
              selected: _selectedPaketId == paket.id,
              onTap: () => setState(() => _selectedPaketId = paket.id),
              higherVisibilityLabel: l10n.higherVisibility,
              perMonth: l10n.perMonth,
              perYear: l10n.perYear,
            );
          }),
          const SizedBox(height: 32),
          _primaryBtn(l10n.next,
              () { if (_validateStep2()) _goTo(2); }),
        ],
      ),
    );
  }

  Widget _buildStep3Zugangsdaten(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.createCredentials,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.credentialsSubtitle,
              style: const TextStyle(color: AppColors.grey)),
          const SizedBox(height: 32),
          _field(l10n.emailLabel, _emailCtrl,
              keyboard: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _field(l10n.passwordMin8, _passwordCtrl,
              obscure: _obscurePass,
              toggleObscure: () =>
                  setState(() => _obscurePass = !_obscurePass)),
          const SizedBox(height: 16),
          _field(l10n.confirmPassword, _confirmCtrl,
              obscure: _obscureConfirm,
              toggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm)),
          const SizedBox(height: 32),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _primaryBtn(l10n.registerAndPay, _submit),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: Text(l10n.alreadyRegistered,
                  style: const TextStyle(color: AppColors.navy)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Done(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read_outlined,
                color: AppColors.orange, size: 80),
            const SizedBox(height: 24),
            Text(l10n.registrationComplete,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(l10n.registrationCompleteInfo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey)),
            const SizedBox(height: 32),
            _primaryBtn(l10n.goToLogin, () async {
              await context.read<AuthService>().signOut();
              if (mounted) context.go('/login');
            }),
          ],
        ),
      ),
    );
  }

  Widget _kategoriePicker(AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      value: _kategorie,
      decoration: InputDecoration(
        labelText: l10n.filterCategory,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: kCategories
          .map((c) => DropdownMenuItem(
                value: c, // DE-Wert gespeichert
                child: Text(_localizedCategory(l10n, c)),
              ))
          .toList(),
      onChanged: (v) => setState(() {
        _kategorie = v!;
        _zusatzKategorien.clear();
        _zusatzTelefonCtrl.clear();
        _selectedPaketId = null;
      }),
    );
  }

  Widget _landPicker(AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      value: _land,
      decoration: InputDecoration(
        labelText: l10n.country,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        DropdownMenuItem(value: 'AT', child: Text(l10n.austria)),
        DropdownMenuItem(value: 'DE', child: Text(l10n.germany)),
        DropdownMenuItem(value: 'CH', child: Text(l10n.switzerland)),
      ],
      onChanged: (v) => setState(() => _land = v!),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard,
      bool obscure = false,
      VoidCallback? toggleObscure,
      int maxLines = 1,
      String? hint}) {
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
                icon: Icon(obscure
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: toggleObscure)
            : null,
      ),
    );
  }

  Widget _buildAdresseField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _adresseCtrl,
          decoration: InputDecoration(
            labelText: '${l10n.streetAndNumber} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: _adresseSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _onAdresseChanged,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08), blurRadius: 6),
              ],
            ),
            child: Column(
              children: _suggestions.take(4).map((s) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _adresseCtrl.text = s.streetLine;
                      if (s.postcode.isNotEmpty) _plzCtrl.text = s.postcode;
                      if (s.city.isNotEmpty) _ortCtrl.text = s.city;
                      _adresseLat = s.lat;
                      _adresseLng = s.lng;
                      _suggestions = [];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.streetLine.isNotEmpty
                                    ? s.streetLine
                                    : s.displayName.split(',').first,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (s.postcode.isNotEmpty || s.city.isNotEmpty)
                                Text(
                                  '${s.postcode} ${s.city}'.trim(),
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.grey),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _AddressSuggestion {
  final String road;
  final String houseNumber;
  final String postcode;
  final String city;
  final String displayName;
  final double? lat;
  final double? lng;

  const _AddressSuggestion({
    required this.road,
    required this.houseNumber,
    required this.postcode,
    required this.city,
    required this.displayName,
    this.lat,
    this.lng,
  });

  factory _AddressSuggestion.fromJson(Map<String, dynamic> json) {
    final address = (json['address'] as Map<String, dynamic>?) ?? {};
    return _AddressSuggestion(
      road: (address['road'] as String?) ??
          (address['pedestrian'] as String?) ??
          (address['path'] as String?) ??
          '',
      houseNumber: (address['house_number'] as String?) ?? '',
      postcode: (address['postcode'] as String?) ?? '',
      city: (address['city'] as String?) ??
          (address['town'] as String?) ??
          (address['village'] as String?) ??
          (address['municipality'] as String?) ??
          '',
      displayName: (json['display_name'] as String?) ?? '',
      lat: double.tryParse(json['lat']?.toString() ?? ''),
      lng: double.tryParse(json['lon']?.toString() ?? ''),
    );
  }

  String get streetLine =>
      houseNumber.isNotEmpty ? '$road $houseNumber' : road;
}

class _PaketCard extends StatelessWidget {
  final Paket paket;
  final String billing;
  final int standorte;
  final double totalPrice;
  final bool hasDiscount;
  final bool selected;
  final VoidCallback onTap;
  final String higherVisibilityLabel;
  final String perMonth;
  final String perYear;

  const _PaketCard({
    required this.paket,
    required this.billing,
    required this.standorte,
    required this.totalPrice,
    required this.hasDiscount,
    required this.selected,
    required this.onTap,
    required this.higherVisibilityLabel,
    required this.perMonth,
    required this.perYear,
  });

  @override
  Widget build(BuildContext context) {
    final basePrice = billing == 'yearly' ? paket.jaehrlich : paket.monatlich;
    final unit = billing == 'yearly' ? perYear : perMonth;

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
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 6),
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
                    Text(higherVisibilityLabel,
                        style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white70 : AppColors.grey)),
                  if (standorte > 1)
                    Text(
                      hasDiscount
                          ? '€ ${basePrice.toStringAsFixed(2)} × $standorte – 20%'
                          : '€ ${basePrice.toStringAsFixed(2)} × $standorte',
                      style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white54 : AppColors.grey),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€ ${totalPrice.toStringAsFixed(2)}$unit',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: selected ? AppColors.orange : AppColors.navy),
                ),
                if (hasDiscount)
                  Text('inkl. 20% Rabatt',
                      style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? Colors.green.shade300
                              : Colors.green.shade700)),
              ],
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
