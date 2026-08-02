import 'package:cloud_firestore/cloud_firestore.dart';

class Partner {
  final String id;
  final String name;
  final String kategorie;
  final List<String> kategorien;
  final String adresse;
  final String ort;
  final String plz;
  final String land;
  final String telefon;
  final String email;
  final String website;
  final String oeffnungszeiten;
  final String berater;
  final String logo;
  final String leistungen;
  final String ersatzwagenHinweis;
  final bool aktiv;
  final String paket;
  final int standorte;
  final int prioritaet;
  final double? lat;
  final double? lng;
  final Map<String, String> zusatzTelefon;
  final Map<String, String> zusatzInfo;
  final List<String> photos;
  final Map<String, int> klicks;

  Partner({
    required this.id,
    required this.name,
    required this.kategorie,
    required this.kategorien,
    required this.adresse,
    required this.ort,
    required this.plz,
    required this.land,
    required this.telefon,
    required this.email,
    required this.website,
    required this.oeffnungszeiten,
    required this.berater,
    required this.logo,
    required this.leistungen,
    required this.ersatzwagenHinweis,
    required this.aktiv,
    required this.paket,
    required this.standorte,
    required this.prioritaet,
    this.lat,
    this.lng,
    required this.zusatzTelefon,
    required this.zusatzInfo,
    required this.photos,
    this.klicks = const {},
  });

  factory Partner.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Partner(
      id: doc.id,
      name: d['name'] ?? '',
      kategorie: d['kategorie'] ?? '',
      kategorien: d['kategorien'] is List
          ? List<String>.from(d['kategorien'])
          : d['kategorien'] is String && (d['kategorien'] as String).isNotEmpty
              ? [d['kategorien'] as String]
              : [],
      adresse: d['adresse'] ?? '',
      ort: d['ort'] ?? '',
      plz: d['plz'] ?? '',
      land: d['land'] ?? 'AT',
      telefon: d['telefon'] ?? '',
      email: d['email'] ?? '',
      website: d['website'] ?? '',
      oeffnungszeiten: d['oeffnungszeiten'] ?? '',
      berater: d['berater'] ?? '',
      logo: d['logo'] ?? '',
      leistungen: d['leistungen'] ?? '',
      ersatzwagenHinweis: d['ersatzwagenHinweis'] ?? '',
      aktiv: d['aktiv'] ?? false,
      paket: d['paket'] ?? '',
      standorte: (d['standorte'] as num?)?.toInt() ?? 1,
      prioritaet: (d['prioritaet'] as num?)?.toInt() ?? 0,
      lat: (d['firmaLatitude'] as num?)?.toDouble(),
      lng: (d['firmaLongitude'] as num?)?.toDouble(),
      zusatzTelefon: Map<String, String>.from(d['zusatzTelefon'] ?? {}),
      zusatzInfo: Map<String, String>.from(d['zusatzInfo'] ?? {}),
      photos: d['photos'] is List ? List<String>.from(d['photos']) : [],
      klicks: (d['klicks'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  String get fullAddress => '$adresse, $plz $ort';
}

const List<String> kCategories = [
  'Werkstatt',
  'Abschleppdienst',
  'Hotel',
  'Taxi',
  'Versicherungsmakler',
  'KFZ Sachverständiger',
];

const Map<String, List<String>> kZusatzKategorien = {
  'Werkstatt': ['Abschleppdienst', 'Ersatzwagen', 'Glasservice', 'Reifenservice'],
  'Abschleppdienst': ['Werkstatt', 'Ersatzwagen'],
  'Ersatzwagen': ['Werkstatt', 'Abschleppdienst'],
  'Hotel': [],
  'Taxi': [],
  'Versicherungsmakler': [],
  'KFZ Sachverständiger': [],
};

// Pakete mit Preisen
class Paket {
  final String id;
  final String label;
  final double monatlich;
  final double jaehrlich;
  final int prioritaet;

  const Paket({
    required this.id,
    required this.label,
    required this.monatlich,
    required this.jaehrlich,
    required this.prioritaet,
  });
}

const List<Paket> kPakete = [
  Paket(id: 'basic', label: 'Basic', monatlich: 4.99, jaehrlich: 49.90, prioritaet: 1),
  Paket(id: 'premium', label: 'Premium', monatlich: 9.99, jaehrlich: 99.90, prioritaet: 2),
];

const List<Paket> kPaketeVersicherung = [
  Paket(id: 'versicherung_basic', label: 'Basic', monatlich: 14.99, jaehrlich: 149.90, prioritaet: 3),
  Paket(id: 'versicherung_premium', label: 'Premium', monatlich: 19.99, jaehrlich: 199.90, prioritaet: 4),
];

const List<Paket> kPaketeSachverstaendiger = [
  Paket(id: 'sachverstaendiger_basic', label: 'Basic', monatlich: 14.99, jaehrlich: 149.90, prioritaet: 3),
  Paket(id: 'sachverstaendiger_premium', label: 'Premium', monatlich: 19.99, jaehrlich: 199.90, prioritaet: 4),
];

List<Paket> paketeForKategorie(String kategorie) {
  if (kategorie == 'Versicherungsmakler') return kPaketeVersicherung;
  if (kategorie == 'KFZ Sachverständiger') return kPaketeSachverstaendiger;
  return kPakete;
}
