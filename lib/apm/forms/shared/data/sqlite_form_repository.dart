import 'dart:io';
import 'dart:typed_data';

import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/apm/forms/shared/editor/form_draft_persistence_service.dart';
import 'package:audit_pro_mobile/apm/services/platform/image_persistence.dart';
import 'package:image_picker/image_picker.dart';

/// Mobile [FormRepository]: the form's working data is the on-device SQLite
/// draft's `form_data` blob; named collections are list-valued keys within it.
/// Submission is delegated to an injected, form-specific submitter (the only
/// legitimately form-specific seam — the payload builder + endpoint).
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

  // --- generic collections ---------------------------------------------------

  List<Map<String, dynamic>> _readCollection(String collection) {
    final raw = _data[collection];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  List<Map<String, dynamic>> getCollection(String collection) =>
      _readCollection(collection);

  @override
  Map<String, dynamic>? getCollectionItem(String collection, Object id) {
    for (final item in _readCollection(collection)) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  @override
  List<Map<String, dynamic>> queryCollection(
    String collection, {
    Map<String, Object?> where = const <String, Object?>{},
  }) {
    return _readCollection(collection)
        .where((item) => where.entries.every((e) => item[e.key] == e.value))
        .toList();
  }

  @override
  Future<Object> saveCollectionItem(
    String collection,
    Map<String, dynamic> item,
  ) async {
    final list = _data[collection] is List
        ? List<dynamic>.from(_data[collection] as List)
        : <dynamic>[];

    final incomingId = item['id'];
    final existingIndex =
        incomingId == null ? -1 : _indexOfId(list, incomingId);
    final next = Map<String, dynamic>.from(item);

    final Object resolvedId;
    if (existingIndex >= 0) {
      resolvedId = incomingId as Object;
      list[existingIndex] = next;
    } else {
      resolvedId = incomingId ?? _nextId(list);
      next['id'] = resolvedId;
      list.add(next);
    }

    _data[collection] = list;
    await saveDraft();
    return resolvedId;
  }

  @override
  Future<void> deleteCollectionItem(String collection, Object id) async {
    final raw = _data[collection];
    if (raw is! List) return;
    raw.removeWhere((e) => e is Map && e['id'] == id);
    await saveDraft();
  }

  int _indexOfId(List<dynamic> list, Object id) {
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is Map && e['id'] == id) return i;
    }
    return -1;
  }

  int _nextId(List<dynamic> list) {
    var max = 0;
    for (final e in list) {
      if (e is Map && e['id'] is int && (e['id'] as int) > max) {
        max = e['id'] as int;
      }
    }
    return max + 1;
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
