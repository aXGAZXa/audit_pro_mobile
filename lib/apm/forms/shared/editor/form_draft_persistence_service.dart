import 'dart:async';

import '../../../database/database_helper.dart';

class FormSavePolicy {
  const FormSavePolicy({this.debounce});

  const FormSavePolicy.immediate() : debounce = null;

  final Duration? debounce;

  bool get isDebounced => debounce != null && debounce! > Duration.zero;
}

class FormDraftSession {
  const FormDraftSession({
    required this.formId,
    required this.status,
    required this.formData,
  });

  final int formId;
  final String status;
  final Map<String, dynamic> formData;
}

class FormDraftPersistenceService {
  FormDraftPersistenceService({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;
  final Map<String, Timer> _debounceTimers = <String, Timer>{};
  final Map<String, _PendingSaveRequest> _pendingSaves =
      <String, _PendingSaveRequest>{};

  Future<FormDraftSession> loadOrCreate({
    required String formType,
    int? explicitFormId,
    bool forceNew = false,
    bool allowLatestDraftFallback = false,
    Map<String, dynamic> initialFormData = const <String, dynamic>{},
  }) async {
    if (explicitFormId != null) {
      final form = await _db.getForm(explicitFormId);
      if (form != null) {
        final session = _toSession(form);
        if (session.status == 'draft') {
          await _db.setCurrentFormId(
            formType: formType,
            formId: session.formId,
          );
        }
        return session;
      }
    }

    if (!forceNew) {
      final currentId = await _db.getCurrentFormId(formType);
      if (currentId != null) {
        final form = await _db.getForm(currentId);
        if (form != null) {
          final session = _toSession(form);
          if (session.status == 'draft') {
            return session;
          }
        }

        await _db.clearCurrentFormId(formType);
      }

      if (allowLatestDraftFallback) {
        final forms = await _db.getFormsByType(formType);
        final drafts = forms.where(
          (f) => (f['status']?.toString() ?? '') == 'draft',
        );
        if (drafts.isNotEmpty) {
          final latestDraft = drafts.first;
          final session = _toSession(latestDraft);
          await _db.setCurrentFormId(
            formType: formType,
            formId: session.formId,
          );
          return session;
        }
      }
    }

    final newFormId = await _db.saveForm(
      formType: formType,
      status: 'draft',
      formData: Map<String, dynamic>.from(initialFormData),
    );
    await _db.setCurrentFormId(formType: formType, formId: newFormId);
    return FormDraftSession(
      formId: newFormId,
      status: 'draft',
      formData: Map<String, dynamic>.from(initialFormData),
    );
  }

  Future<void> save({
    required String formType,
    required int formId,
    required String status,
    required Map<String, dynamic> formData,
    bool keepCurrentPointer = true,
    FormSavePolicy savePolicy = const FormSavePolicy.immediate(),
  }) async {
    final key = _saveKey(formType, formId);
    if (!savePolicy.isDebounced) {
      _cancelPending(key);
      await _performSave(
        formType: formType,
        formId: formId,
        status: status,
        formData: formData,
        keepCurrentPointer: keepCurrentPointer,
      );
      return;
    }

    _pendingSaves[key] = _PendingSaveRequest(
      formType: formType,
      formId: formId,
      status: status,
      formData: Map<String, dynamic>.from(formData),
      keepCurrentPointer: keepCurrentPointer,
    );

    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(savePolicy.debounce!, () async {
      final pending = _pendingSaves.remove(key);
      _debounceTimers.remove(key);
      if (pending == null) return;
      try {
        await _performSave(
          formType: pending.formType,
          formId: pending.formId,
          status: pending.status,
          formData: pending.formData,
          keepCurrentPointer: pending.keepCurrentPointer,
        );
      } catch (_) {
        // Caller paths already handle save failures in their own flows.
      }
    });
  }

  Future<void> flush({required String formType, required int formId}) async {
    final key = _saveKey(formType, formId);
    final pending = _pendingSaves.remove(key);
    _debounceTimers.remove(key)?.cancel();
    if (pending == null) return;

    await _performSave(
      formType: pending.formType,
      formId: pending.formId,
      status: pending.status,
      formData: pending.formData,
      keepCurrentPointer: pending.keepCurrentPointer,
    );
  }

  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingSaves.clear();
  }

  Future<void> _performSave({
    required String formType,
    required int formId,
    required String status,
    required Map<String, dynamic> formData,
    required bool keepCurrentPointer,
  }) async {
    await _db.saveForm(
      id: formId,
      formType: formType,
      status: status,
      formData: formData,
    );

    if (keepCurrentPointer && status == 'draft') {
      await _db.setCurrentFormId(formType: formType, formId: formId);
      return;
    }

    if (!keepCurrentPointer || status != 'draft') {
      final current = await _db.getCurrentFormId(formType);
      if (current == formId) {
        await _db.clearCurrentFormId(formType);
      }
    }
  }

  String _saveKey(String formType, int formId) => '$formType::$formId';

  void _cancelPending(String key) {
    _pendingSaves.remove(key);
    _debounceTimers.remove(key)?.cancel();
  }

  Future<void> clearCurrentDraft(String formType) {
    return _db.clearCurrentFormId(formType);
  }

  FormDraftSession _toSession(Map<String, dynamic> form) {
    final raw = form['form_data'];
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    return FormDraftSession(
      formId: form['id'] as int,
      status: (form['status'] ?? '').toString(),
      formData: data,
    );
  }
}

class _PendingSaveRequest {
  const _PendingSaveRequest({
    required this.formType,
    required this.formId,
    required this.status,
    required this.formData,
    required this.keepCurrentPointer,
  });

  final String formType;
  final int formId;
  final String status;
  final Map<String, dynamic> formData;
  final bool keepCurrentPointer;
}
