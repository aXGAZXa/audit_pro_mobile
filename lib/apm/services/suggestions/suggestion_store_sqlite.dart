import '../../database/database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'suggestion_store.dart';

SuggestionStore createSuggestionStore() => _SqliteSuggestionStore();

class _SqliteSuggestionStore implements SuggestionStore {
  final DatabaseHelper _db = DatabaseHelper.instance;

  @override
  Future<List<String>> getSuggestions({
    required String fieldName,
    required String query,
    Map<String, String>? filterContext,
  }) {
    if (kIsWeb) return Future.value(const <String>[]);
    return _db.getSuggestions(
      fieldName: fieldName,
      query: query,
      filterContext: filterContext,
    );
  }

  @override
  Future<void> saveSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  }) {
    if (kIsWeb) return Future.value();
    return _db.saveSuggestion(
      fieldName: fieldName,
      value: value,
      filterContext: filterContext,
    );
  }

  @override
  Future<void> deleteSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  }) {
    if (kIsWeb) return Future.value();
    return _db.deleteSuggestion(
      fieldName: fieldName,
      value: value,
      filterContext: filterContext,
    );
  }
}
