import 'dart:io';
import 'dart:typed_data';

import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/apm/forms/shared/editor/form_draft_persistence_service.dart';
import 'package:audit_pro_mobile/apm/services/platform/image_persistence.dart';
import 'package:image_picker/image_picker.dart';

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
    Future<String?> Function(int formId)? submitter,
  })  : _db = db ?? DatabaseHelper.instance,
        _drafts = drafts ?? FormDraftPersistenceService(),
        _submitter = submitter;

  final DatabaseHelper _db;
  final FormDraftPersistenceService _drafts;
  final Future<String?> Function(int formId)? _submitter;

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
    FormSavePolicy savePolicy = const FormSavePolicy.immediate(),
  }) {
    return _drafts.save(
      formType: _formType,
      formId: _formId,
      status: status,
      formData: _data,
      savePolicy: savePolicy,
    );
  }

  @override
  Future<void> flushDraft() =>
      _drafts.flush(formType: _formType, formId: _formId);

  // --- generic collections (bridge known ones to typed tables) ---------------

  @override
  Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    final bridged = await _readBridged(collection);
    if (bridged != null) return bridged;
    // Not-yet-bridged collection: serve from the blob.
    final raw = _data[collection];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>?> _readBridged(String collection) async {
    switch (collection) {
      case 'observations':
        return _db.getFormObservations(_formId);
      case 'unsafeObservations':
        return _db.getUnsafeObservations(_formId);
      default:
        return null; // not yet bridged — fall back to the blob
    }
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
    switch (collection) {
      case 'observations':
        final id = await _db.saveObservation(
          formId: _formId,
          questionReference:
              (item['question_reference'] ?? item['questionReference'] ?? '')
                  .toString(),
          notes: (item['notes'] as String?)?.trim().isEmpty ?? true
              ? null
              : item['notes'] as String?,
          imagePaths:
              (item['images'] ?? item['imagePaths']) is List
                  ? List<String>.from(
                      (item['images'] ?? item['imagePaths']) as List)
                  : null,
        );
        return id;
      default:
        // Not-yet-bridged collection: keep it in the blob.
        final list = _data[collection] is List
            ? List<dynamic>.from(_data[collection] as List)
            : <dynamic>[];
        final next = Map<String, dynamic>.from(item);
        final id = next['id'] ?? (list.length + 1);
        next['id'] = id;
        final idx = list.indexWhere((e) => e is Map && e['id'] == id);
        if (idx >= 0) {
          list[idx] = next;
        } else {
          list.add(next);
        }
        _data[collection] = list;
        await saveDraft();
        return id;
    }
  }

  @override
  Future<void> deleteCollectionItem(String collection, Object id) async {
    switch (collection) {
      case 'observations':
        if (id is int) await _db.deleteObservation(id);
        return;
      default:
        final raw = _data[collection];
        if (raw is List) raw.removeWhere((e) => e is Map && e['id'] == id);
        await saveDraft();
    }
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
    return submitter(_formId);
  }

  // --- reference data --------------------------------------------------------

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
