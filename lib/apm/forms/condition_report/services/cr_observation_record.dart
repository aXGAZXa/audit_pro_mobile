/// Single shape authority for a Condition Report observation record.
///
/// This mirrors EXACTLY the map `DatabaseHelper.saveObservation` writes into the
/// `observations` collection, so that routing observation writes through the
/// generic [FormRepository] (single-writer Capture & Projection plumbing)
/// preserves the byte-for-byte payload the CR feature already receives.
///
/// The bespoke `attached_to_*` / `question_*` / `asset_*` / `unsafe_*` fields are
/// the *old* encoding of an observation's "context" (which the gt_form_builder
/// `CollectionItem.contextId`/`answers` model generalises) — preserved here for
/// the live v2 envelope; they converge later when CR becomes a builder definition.
library;

Map<String, dynamic> buildCrObservationRecord({
  Object? id,
  required int formId,
  required String questionReference,
  String? notes,
  List<String> imagePaths = const <String>[],
  String? questionText,
  String? sectionName,
  Object? assetId,
  Object? assetUuid,
  String? assetType,
  String? assetMakeModel,
  bool isUnsafe = false,
  String? unsafeClassification,
  String? unsafeActionTaken,
  String? unsafeWarningNoticeImage,
  String? unsafeAfterImage,
  String? unsafeResidentReaction,
  String? unsafeReportedToClient,
  String? unsafeReportedInternally,
  String? unsafeCheckedBy,
  String? unsafeCheckedDate,
  String? unsafeSentVia,
  String? unsafeSentTo,
  Map<String, dynamic>? existing,
  String? nowIso,
}) {
  final now = nowIso ?? DateTime.now().toIso8601String();
  final prior = existing ?? const <String, dynamic>{};
  return <String, dynamic>{
    ...prior,
    'id': ?id,
    'form_id': formId,
    'attached_to_type': 'question',
    'attached_to_id': questionReference,
    'attached_to_path': null,
    'question_reference': questionReference,
    'notes': notes,
    'question_text': questionText,
    'section_name': sectionName,
    'asset_id': assetId,
    // FK-by-uuid (additive): the asset's stable UUID alongside the local int id,
    // so the server can reconcile the observation->asset link by a key that
    // survives edits / re-projection / devices. int asset_id stays for the live
    // v2 envelope until both client display + server key on uuid (coordinated).
    'asset_uuid': ?assetUuid,
    'asset_type': assetType,
    'asset_make_model': assetMakeModel,
    'is_unsafe': isUnsafe ? 1 : 0,
    'unsafe_classification': unsafeClassification,
    'unsafe_action_taken': unsafeActionTaken,
    'unsafe_warning_notice_image': unsafeWarningNoticeImage,
    'unsafe_after_image': unsafeAfterImage,
    'unsafe_resident_reaction': unsafeResidentReaction,
    'unsafe_reported_to_client': unsafeReportedToClient,
    'unsafe_reported_internally': unsafeReportedInternally,
    'unsafe_checked_by': unsafeCheckedBy,
    'unsafe_checked_date': unsafeCheckedDate,
    'unsafe_sent_via': unsafeSentVia,
    'unsafe_sent_to': unsafeSentTo,
    'images': imagePaths,
    'created_at': (prior['created_at'] ?? now),
    'updated_at': now,
  };
}
