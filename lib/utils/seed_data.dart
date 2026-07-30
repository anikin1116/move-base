import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedPartners() async {
  final col = FirebaseFirestore.instance.collection('partners');

  final partners = [
    {
      'uid': 'seed_001',
      'companyName': 'Auto-Werkstatt Müller',
      'category': 'Werkstatt',
      'specializations': ['KFZ-Reparatur', 'Karosserie', 'HU/AU'],
      'address': {
        'street': 'Mariahilfer Straße 45',
        'zip': '1060',
        'city': 'Wien',
        'geoPoint': const GeoPoint(48.1963, 16.3396),
      },
      'contact': {
        'phone': '+43 1 234 5678',
        'website': 'https://werkstatt-mueller.at',
      },
      'openingHours': {
        'Mo-Fr': '08:00–18:00',
        'Sa': '09:00–13:00',
      },
      'photos': <String>[],
      'description': 'Ihr zuverlässiger KFZ-Betrieb im Herzen Wiens. 30 Jahre Erfahrung, faire Preise, schnelle Abwicklung.',
      'verified': true,
      'subscriptionStatus': 'active',
      'analytics': {'impressionsMonth': 142, 'profileClicksMonth': 38, 'contactClicksMonth': 12},
    },
    {
      'uid': 'seed_002',
      'companyName': 'Lackier-Profi Wien',
      'category': 'Lackiererei',
      'specializations': ['Unfallschäden', 'Smart Repair', 'Folierung'],
      'address': {
        'street': 'Gürtelstraße 12',
        'zip': '1100',
        'city': 'Wien',
        'geoPoint': const GeoPoint(48.1741, 16.3688),
      },
      'contact': {
        'phone': '+43 1 876 5432',
        'website': '',
      },
      'openingHours': {
        'Mo-Fr': '07:30–17:00',
      },
      'photos': <String>[],
      'description': 'Spezialbetrieb für Unfallreparaturen und Lackschäden. Direktabrechnung mit allen Versicherungen.',
      'verified': true,
      'subscriptionStatus': 'active',
      'analytics': {'impressionsMonth': 89, 'profileClicksMonth': 21, 'contactClicksMonth': 7},
    },
    {
      'uid': 'seed_003',
      'companyName': 'Schnell-Abschlepp 24h',
      'category': 'Abschleppdienst',
      'specializations': ['24h Pannenhilfe', 'Abschleppen', 'Starthilfe'],
      'address': {
        'street': 'Industriestraße 88',
        'zip': '1230',
        'city': 'Wien',
        'geoPoint': const GeoPoint(48.1465, 16.3052),
      },
      'contact': {
        'phone': '+43 699 123 456 78',
        'website': '',
      },
      'openingHours': {
        'täglich': '00:00–24:00',
      },
      'photos': <String>[],
      'description': '24/7 Pannenhilfe und Abschleppdienst in ganz Wien und Umgebung. Innerhalb von 30 Minuten vor Ort.',
      'verified': true,
      'subscriptionStatus': 'active',
      'analytics': {'impressionsMonth': 210, 'profileClicksMonth': 67, 'contactClicksMonth': 34},
    },
    {
      'uid': 'seed_004',
      'companyName': 'Gutachterbüro Steiner',
      'category': 'KFZ Gutachter',
      'specializations': ['Unfallgutachten', 'Wertgutachten', 'Schadensschätzung'],
      'address': {
        'street': 'Ringstraße 3',
        'zip': '1010',
        'city': 'Wien',
        'geoPoint': const GeoPoint(48.2041, 16.3643),
      },
      'contact': {
        'phone': '+43 1 555 9900',
        'website': 'https://gutachter-steiner.at',
      },
      'openingHours': {
        'Mo-Fr': '09:00–17:00',
      },
      'photos': <String>[],
      'description': 'Zertifizierter KFZ-Sachverständiger. Schnelle Gutachtenerstellung für Versicherungen und Gerichte.',
      'verified': true,
      'subscriptionStatus': 'active',
      'analytics': {'impressionsMonth': 65, 'profileClicksMonth': 18, 'contactClicksMonth': 9},
    },
    {
      'uid': 'seed_005',
      'companyName': 'Reifen Bauer GmbH',
      'category': 'Reifenservice',
      'specializations': ['Reifenwechsel', 'Einlagerung', 'Felgenreparatur'],
      'address': {
        'street': 'Laxenburger Straße 201',
        'zip': '1100',
        'city': 'Wien',
        'geoPoint': const GeoPoint(48.1612, 16.3744),
      },
      'contact': {
        'phone': '+43 1 666 7788',
        'website': 'https://reifen-bauer.at',
      },
      'openingHours': {
        'Mo-Fr': '08:00–18:00',
        'Sa': '08:00–14:00',
      },
      'photos': <String>[],
      'description': 'Alle Reifenmarken, schneller Wechsel ohne Termin. Saisonale Einlagerung zu günstigen Preisen.',
      'verified': true,
      'subscriptionStatus': 'active',
      'analytics': {'impressionsMonth': 178, 'profileClicksMonth': 44, 'contactClicksMonth': 19},
    },
    {
      'uid': 'seed_006',
      'companyName': 'Versicherung Kovač',
      'category': 'Versicherungsvermittler',
      'specializations': ['KFZ-Versicherung', 'Kaskoversicherung', 'Schadensabwicklung'],
      'address': {
        'street': 'Praterstraße 14',
        'zip': '1020',
        'city': 'Wien',
        'geoPoint': const GeoPoint(48.2155, 16.3872),
      },
      'contact': {
        'phone': '+43 1 333 4455',
        'website': '',
      },
      'openingHours': {
        'Mo-Fr': '09:00–18:00',
      },
      'photos': <String>[],
      'description': 'Unabhängiger Versicherungsmakler für KFZ. Vergleich aller Anbieter, Hilfe bei Schadensabwicklung.',
      'verified': false,
      'subscriptionStatus': 'active',
      'analytics': {'impressionsMonth': 43, 'profileClicksMonth': 11, 'contactClicksMonth': 5},
    },
  ];

  final batch = FirebaseFirestore.instance.batch();
  for (final p in partners) {
    final uid = p['uid'] as String;
    batch.set(col.doc(uid), p);
  }
  await batch.commit();
}
