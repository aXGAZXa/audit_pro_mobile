import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../editor/form_draft_persistence_service.dart'
    show FormDraftSession, FormSavePolicy;

/// Environment-agnostic form I/O. One contract, two implementations:
///  - `SqliteFormRepository` — mobile app, backed by the on-device SQLite draft.
///  - `WebFormRepository`     — web editor, backed by the server payload + the
///    editor API.
///
/// Form screens depend ONLY on this; there is NO `kIsWeb` / runtime-mode
/// branching in a screen. The platform decision happens once, at the entry
/// point, by choosing which implementation to inject.
///
/// A repository instance is scoped to a single form-edit session. It loads the
/// form's data once, then serves **generic** collection reads/writes against an
/// in-memory model, and persists via the platform-appropriate sink. "Generic"
/// means nothing here is form-specific: a form is a [formData] map plus named
/// collections (lists of maps) such as `observations`, `assets`, `plantRooms`,
/// `heatMeters`. That genericity is what makes a future form builder drop-in.
abstract class FormRepository {
  /// Load the draft (or create a new one) and make it the active session.
  Future<FormDraftSession> loadOrCreateDraft({
    required String formType,
    int? explicitFormId,
    bool forceNew = false,
    bool allowLatestDraftFallback = false,
    Map<String, dynamic> initialFormData = const <String, dynamic>{},
  });

  /// The active form's top-level field map (everything that is not a
  /// collection). Mutating this then calling [saveDraft] persists the change.
  Map<String, dynamic> get formData;

  /// The active form id (local autoincrement on mobile; the submission's local
  /// id echoed from the payload on web).
  int get formId;

  /// Persist the active form's current state via the platform sink (SQLite on
  /// mobile; in-memory until completion on web).
  Future<void> saveDraft({
    String status = 'draft',
    FormSavePolicy savePolicy = const FormSavePolicy.immediate(),
  });

  /// Flush any pending debounced save.
  Future<void> flushDraft();

  // --- generic collections ----------------------------------------------------

  /// All items in [collection] (e.g. `'observations'`). Reads from the loaded
  /// in-memory model, so it is synchronous.
  List<Map<String, dynamic>> getCollection(String collection);

  /// A single item in [collection] by its `'id'`, or null.
  Map<String, dynamic>? getCollectionItem(String collection, Object id);

  /// Items in [collection] matching all of [where] (key == value), e.g.
  /// `queryCollection('observations', where: {'questionReference': 'CR.SITE.01'})`.
  List<Map<String, dynamic>> queryCollection(
    String collection, {
    Map<String, Object?> where = const <String, Object?>{},
  });

  /// Upsert [item] into [collection] (matched by its `'id'` when present; a new
  /// id is assigned otherwise) and return the item's id. Persists per the form's
  /// save policy.
  Future<Object> saveCollectionItem(
    String collection,
    Map<String, dynamic> item,
  );

  /// Remove the item with [id] from [collection].
  Future<void> deleteCollectionItem(String collection, Object id);

  // --- images / attachments ---------------------------------------------------

  /// Persist freshly-picked images and return references to store in form data.
  /// Mobile: copies into the app documents dir, returns file paths. Web: uploads
  /// via the editor API, returns attachment ids.
  Future<List<String>> persistImages(
    List<XFile> images, {
    required String prefix,
  });

  /// Resolve [ref] to bytes for display (mobile: read the file; web: fetch via
  /// the editor API).
  Future<Uint8List?> loadImageBytes(String ref);

  // --- submission -------------------------------------------------------------

  /// Finalise the form. Mobile: build the envelope and POST `/api/forms/submit`.
  /// Web: PUT `/api/editor/submission`. Returns a server reference on success.
  Future<String?> submit();

  // --- reference data ---------------------------------------------------------

  Future<List<String>> getClients();

  Future<List<String>> getSuggestions({
    required String fieldName,
    required String query,
    Map<String, String>? filterContext,
    int limit = 10,
  });

  Future<void> saveSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  });

  void dispose();
}
