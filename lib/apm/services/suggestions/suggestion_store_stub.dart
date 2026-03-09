import 'suggestion_store.dart';

SuggestionStore createSuggestionStore() => const _NoopSuggestionStore();

class _NoopSuggestionStore implements SuggestionStore {
  const _NoopSuggestionStore();

  @override
  Future<List<String>> getSuggestions({
    required String fieldName,
    required String query,
    Map<String, String>? filterContext,
  }) async {
    return const <String>[];
  }

  @override
  Future<void> saveSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  }) async {}

  @override
  Future<void> deleteSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  }) async {}
}
