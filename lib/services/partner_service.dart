import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/partner.dart';

class PartnerService {
  final _col = FirebaseFirestore.instance.collection('companies');

  Stream<List<Partner>> getPartners({String? category}) {
    Query q = _col.where('aktiv', isEqualTo: true);
    return q.snapshots().map((s) {
      var partners = s.docs.map(Partner.fromFirestore).toList();
      if (category != null) {
        partners = partners
            .where((p) =>
                p.kategorie == category || p.kategorien.contains(category))
            .toList();
      }
      partners.sort((a, b) => b.prioritaet.compareTo(a.prioritaet));
      return partners;
    });
  }

  Future<List<Partner>> getAllPartners() async {
    final snap = await _col.where('aktiv', isEqualTo: true).get();
    return snap.docs.map(Partner.fromFirestore).toList();
  }

  Future<Partner?> getPartner(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Partner.fromFirestore(doc);
  }

  Stream<Partner?> watchMyProfile(String uid) {
    return _col.doc(uid).snapshots().map(
          (doc) => doc.exists ? Partner.fromFirestore(doc) : null,
        );
  }

  Future<void> updateProfile(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update(data);
  }

  Future<void> createProfile(String uid, Map<String, dynamic> data) async {
    await _col.doc(uid).set(data);
  }

  Future<void> trackKlick(String partnerId, String field) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      await _col.doc(partnerId).update({'klicks.$field': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('trackKlick($field) error: $e');
    }
  }
}
