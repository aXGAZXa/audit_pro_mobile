import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_submission_service.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/sqlite_form_repository.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';

/// Mobile Heat Network Assessment repository: SQLite-backed, submitting via
/// [HnaSubmissionService] (POST `/api/forms/submit` or an edit-session revision,
/// + attachment sync + status recording). The screen flushes the in-memory
/// document to the draft blob before submit, so the service reads the same data
/// the snapshot path would (proven equivalent by
/// `hna_mobile_snapshot_equivalence_test`). The web editor builds its own
/// `WebFormRepository` at the editor entry point; both render the SAME screen.
FormRepository createHnaMobileRepository() {
  final submission = HnaSubmissionService(
    tokenStore: AuthTokenStore(),
    appInfoService: AppInfoService(),
  );
  return SqliteFormRepository(
    submitter: (id, formData) => submission.submitForm(formId: id),
  );
}
