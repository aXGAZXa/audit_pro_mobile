import 'dart:io';
import 'dart:typed_data';

import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/apm/forms/shared/editor/form_draft_persistence_service.dart';
import 'package:audit_pro_mobile/apm/services/platform/image_persistence.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Mobile [FormRepository]. The form's top-level fields live in the on-device
/// draft's `form_data` blob; **collections bridge to the existing typed SQLite
/// tables** so the repo shares one source of truth with any not-yet-migrated
/// sub-screen (no split-brain) and the proven mobile submit path
/// (`CrSubmissionService` building from those tables) is unchanged.
///
/// Collections are bridged incrementally — known ones route to `DatabaseHelper`;
/// any not-yet-bridged collection falls back to the blob, which is harmless
/// because un-migrated screens still talk to the DB directly. Submission is an
/// injected, form-specific submitter (the only legit form-specific seam).
class SqliteFormRepository implements FormRepository {
  SqliteFormRepository({
    DatabaseHelper? db,
    FormDraftPersistenceService? drafts,
    Future<String?> Function(int formId, Map<String, dynamic> formData)?
        submitter,
  })  : _db = db ?? DatabaseHelper.instance,
        _drafts = drafts ?? FormDraftPersistenceService(),
        _submitter = submitter;

  final DatabaseHelper _db;
  final FormDraftPersistenceService _drafts;
  final Future<String?> Function(int formId, Map<String, dynamic> formData)?
      _submitter;

  String _formType = '';
  int _formId = 0;
  Map<String, dynamic> _data = <String, dynamic>{};

  @override
  Map<String, dynamic> get formData => _data;

  @override
  int get formId => _formId;

  @override
  Future<FormDraftSession> loadOrCreateDraft({
    required String formType,
    int? explicitFormId,
    bool forceNew = false,
    bool allowLatestDraftFallback = false,
    Map<String, dynamic> initialFormData = const <String, dynamic>{},
  }) async {
    _formType = formType;
    final session = await _drafts.loadOrCreate(
      formType: formType,
      explicitFormId: explicitFormId,
      forceNew: forceNew,
      allowLatestDraftFallback: allowLatestDraftFallback,
      initialFormData: initialFormData,
    );
    _formId = session.formId;
    _data = Map<String, dynamic>.from(session.formData);
    return session;
  }

  @override
  Future<void> saveDraft({
    String status = 'draft',
    bool keepCurrentPointer = true,
    FormSavePolicy savePolicy = const FormSavePolicy.immediate(),
  }) {
    return _drafts.save(
      formType: _formType,
      formId: _formId,
      status: status,
      // The screen may hold DateTime values; the draft blob is JSON.
      formData: _jsonSafe(_data) as Map<String, dynamic>,
      keepCurrentPointer: keepCurrentPointer,
      savePolicy: savePolicy,
    );
  }

  static Object? _jsonSafe(Object? value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries) e.key.toString(): _jsonSafe(e.value),
      };
    }
    if (value is List) return value.map(_jsonSafe).toList();
    return value;
  }

  /// Mint a stable UUID reconciliation key (additive to `id`) when an item
  /// lacks one; preserve the existing item's UUID on update. This is the seam
  /// the server feature uses to project/edit models (Capture & Projection).
  static void _ensureUuid(Map<String, dynamic> item, {Object? existing}) {
    if ((item['uuid'] ?? '').toString().isNotEmpty) return;
    final existingUuid =
        existing is Map ? (existing['uuid'] ?? '').toString() : '';
    item['uuid'] = existingUuid.isNotEmpty ? existingUuid : const Uuid().v4();
  }

  @override
  Future<void> flushDraft() =>
      _drafts.flush(formType: _formType, formId: _formId);

  // --- generic collections (bridge known ones to typed tables) ---------------

  @override
  Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    // Derived view: "unsafe observations" are observations flagged is_unsafe —
    // not a stored collection. Everything else is a list-valued key on the doc.
    if (collection == 'unsafeObservations') {
      return _readData('observations').where(_isUnsafeRow).toList();
    }
    return _readData(collection);
  }

  List<Map<String, dynamic>> _readData(String collection) {
    final raw = _data[collection];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static bool _isUnsafeRow(Map<String, dynamic> o) {
    final f = o['is_unsafe'];
    return f == true || f == 1 || f?.toString() == '1';
  }

  @override
  Future<Map<String, dynamic>?> getCollectionItem(
    String collection,
    Object id,
  ) async {
    for (final item in await getCollection(collection)) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    Map<String, Object?> where = const <String, Object?>{},
  }) async {
    final items = await getCollection(collection);
    return items
        .where((item) => where.entries.every((e) => item[e.key] == e.value))
        .toList();
  }

  @override
  Future<Object> saveCollectionItem(
    String collection,
    Map<String, dynamic> item,
  ) async {
    // Generic single-writer upsert into the in-memory document. ALL collections
    // (observations, assets, plantRooms, …) live here now — no DB bridge, so
    // there is exactly one writer and the main-screen autosave can't clobber.
    final list = _data[collection] is List
        ? List<dynamic>.from(_data[collection] as List)
        : <dynamic>[];
    final next = Map<String, dynamic>.from(item);
    final id = next['id'] ?? (list.length + 1);
    next['id'] = id;
    final idx = list.indexWhere((e) => e is Map && e['id'] == id);
    _ensureUuid(next, existing: idx >= 0 ? list[idx] : null);
    if (idx >= 0) {
      list[idx] = next;
    } else {
      list.add(next);
    }
    _data[collection] = list;
    await saveDraft();
    return id;
  }

  @override
  Future<void> deleteCollectionItem(String collection, Object id) async {
    final raw = _data[collection];
    if (raw is List) raw.removeWhere((e) => e is Map && e['id'] == id);
    await saveDraft();
  }

  // --- images ----------------------------------------------------------------

  @override
  Future<List<String>> persistImages(
    List<XFile> images, {
    required String prefix,
  }) {
    return persistPickedImagePaths(images, prefix: prefix);
  }

  @override
  Future<Uint8List?> loadImageBytes(String ref) async {
    try {
      final file = File(ref);
      if (await file.exists()) return file.readAsBytes();
    } catch (_) {
      // fall through
    }
    return null;
  }

  // --- submission ------------------------------------------------------------

  @override
  Future<String?> submit() async {
    final submitter = _submitter;
    if (submitter == null) {
      throw StateError('SqliteFormRepository was constructed without a submitter');
    }
    await flushDraft();
    // Submit from the in-memory document (the single source of truth), not the
    // relational tables. The injected submitter is the only form-specific seam
    // (it serializes this form's envelope + knows its endpoint).
    return submitter(_formId, _data);
  }

  // --- reference data --------------------------------------------------------

  @override
  Future<List<Map<String, dynamic>>> getReferenceCollection(String name) async {
    switch (name) {
      case 'asset_types':
        return _db.getAssetTypes();
      case 'property_types':
        return _db.getPropertyTypes();
      case 'clients':
        return _db.getClients();
      default:
        // Generic reference/lookup tables (e.g. asset_statuses).
        return _db.getCollectionItems(name);
    }
  }

  @override
  Future<List<String>> getClients() async {
    final rows = await _db.getClients();
    return rows
        .map((r) => (r['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  @override
  Future<List<String>> getSuggestions({
    required String fieldName,
    required String query,
    Map<String, String>? filterContext,
    int limit = 10,
  }) {
    return _db.getSuggestions(
      fieldName: fieldName,
      query: query,
      filterContext: filterContext,
      limit: limit,
    );
  }

  @override
  Future<void> saveSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  }) {
    return _db.saveSuggestion(
      fieldName: fieldName,
      value: value,
      filterContext: filterContext,
    );
  }

  @override
  void dispose() => _drafts.dispose();
}
