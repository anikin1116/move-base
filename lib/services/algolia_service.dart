import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/partner.dart';

class AlgoliaService {
  static const _appId = '4IWBMP0M4F';
  static const _searchKey = 'fe2560b3dbb3717f4213c1d8e2b77acc';
  static const _index = 'companies';

  Future<List<Partner>> search(String query) async {
    final uri = Uri.https(
      '$_appId-dsn.algolia.net',
      '/1/indexes/$_index/query',
    );
    try {
      final res = await http.post(
        uri,
        headers: {
          'X-Algolia-Application-Id': _appId,
          'X-Algolia-API-Key': _searchKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': query,
          'hitsPerPage': 100,
        }),
      );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final hits = data['hits'] as List<dynamic>? ?? [];
      return hits
          .map((h) {
            try {
              return Partner.fromAlgolia(h as Map<String, dynamic>);
            } catch (e) {
              debugPrint('Algolia hit parse error: $e');
              return null;
            }
          })
          .whereType<Partner>()
          .toList();
    } catch (e) {
      debugPrint('Algolia search error: $e');
      return [];
    }
  }
}
