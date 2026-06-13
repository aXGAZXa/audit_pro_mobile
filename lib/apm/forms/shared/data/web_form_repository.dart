import 'dart:typed_data';

import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_web_editor_attachment_context.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_web_editor_service.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/apm/forms/shared/editor/form_draft_persistence_service.dart';
import 'package:image_picker/image_picker.dart';

/// Web-editor [FormRepository]: the form's working data is the in-memory section
/// of the server payload (extracted form-specifically at the entry point);
/// collections are list-valued keys within it. Persistence happens on [submit]
/// only — the working data is serialised by the injected, form-specific
/// [buildPayloadJson] and PUT to the editor endpoint via [FormWebEditorService].
///
/// The collection logic is identical to the SQLite impl (both operate on a held
/// JSON map) — only the I/O hooks differ, which is the whole point. Image I/O
/// currently delegates to the existing attachment service; folding that behind a
/// proper injected boundary (killing the singleton) is a later cleanup.
class WebFormRepository implements FormRepository {
  WebFormRepository({
    required FormWebEditorService service,
    required String ticket,
    required String formType,
    required int formId,
    required Map<String, dynamic> initialData,
    required String Function(Map<String, dynamic> workingData) buildPayloadJson,
    FormWebEditorAttachmentContext? attachments,
    bool generatePdfOnSubmit = true,
  })  : _service = service,
        _ticket = ticket,
        _formId = formId,
        _data = Map<String, dynamic>.from(initialData),
        _buildPayloadJson = buildPayloadJson,
        _attachments = attachments ?? FormWebEditorAttachmentContext.instance,
        _generatePdf = generatePdfOnSubmit;

  final FormWebEditorService _service;
  final String _ticket;
  final int _formId;
  final Map<String, dynamic> _data;
  final String Function(Map<String, dynamic> workingData) _buildPayloadJson;
  final FormWebEditorAttachmentContext _attachments;
  final bool _generatePdf;

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
    // The web editor entry point has already fetched the submission; the working
    // data was supplied at construction. Just surface it as the active session.
    return FormDraftSession(formId: _formId, status: 'draft', formData: _data);
  }

  @override
  Future<void> saveDraft({
    String status = 'draft',
    bool keepCurrentPointer = true,
    FormSavePolicy savePolicy = const FormSavePolicy.immediate(),
  }) async {
    // Web edits are held in memory until completion; there is no draft sink.
  }

  @override
  Future<void> flushDraft() async {}

  // --- generic collections (identical logic to SqliteFormRepository) ---------

  List<Map<String, dynamic>> _readCollection(String collection) {
    final raw = _data[collection];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCollection(String collection) async =>
      _readCollection(collection);

  @override
  Future<Map<String, dynamic>?> getCollectionItem(
    String collection,
    Object id,
  ) async {
    for (final item in _readCollection(collection)) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    Map<String, Object?> where = const <String, Object?>{},
  }) async {
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
    return resolvedId;
  }

  @override
  Future<void> deleteCollectionItem(String collection, Object id) async {
    final raw = _data[collection];
    if (raw is! List) return;
    raw.removeWhere((e) => e is Map && e['id'] == id);
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
  }) async {
    final refs = <String>[];
    for (final image in images) {
      refs.add(await _attachments.uploadNewImage(image: image, prefix: prefix));
    }
    return refs;
  }

  @override
  Future<Uint8List?> loadImageBytes(String ref) {
    return _attachments.loadBytesForLocalPath(ref);
  }

  // --- submission ------------------------------------------------------------

  @override
  Future<String?> submit() async {
    final payloadJson = _buildPayloadJson(_data);
    await _service.updateSubmission(
      ticket: _ticket,
      payloadJson: payloadJson,
      generatePdf: _generatePdf,
    );
    return _ticket;
  }

  // --- reference data --------------------------------------------------------

  @override
  Future<List<String>> getClients() => _service.getClients(ticket: _ticket);

  @override
  Future<List<String>> getSuggestions({
    required String fieldName,
    required String query,
    Map<String, String>? filterContext,
    int limit = 10,
  }) async {
    // No local suggestion learning in the web editor.
    return const <String>[];
  }

  @override
  Future<void> saveSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  }) async {}

  @override
  void dispose() {}
}
