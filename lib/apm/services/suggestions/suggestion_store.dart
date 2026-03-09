// Note: On Flutter Web, `dart.library.html` is available.
// We key off that rather than `dart.library.io` to avoid accidentally selecting
// IO-backed implementations in web builds.
import 'suggestion_store_sqlite.dart'
    if (dart.library.html) 'suggestion_store_stub.dart';

abstract interface class SuggestionStore {
  Future<List<String>> getSuggestions({
    required String fieldName,
    required String query,
    Map<String, String>? filterContext,
  });

  Future<void> saveSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  });

  Future<void> deleteSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  });
}

/// Platform-resolved suggestion store.
///
/// - Mobile/desktop: SQLite-backed.
/// - Web: no-op (suggestions are a device-local UX enhancement only).
SuggestionStore get suggestionStore => createSuggestionStore();
