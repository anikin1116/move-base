import 'package:cloud_firestore/cloud_firestore.dart';
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
}
