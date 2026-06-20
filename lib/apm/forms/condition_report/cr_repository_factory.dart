import 'package:audit_pro_mobile/apm/forms/condition_report/services/cr_submission_service.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/sqlite_form_repository.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';

/// Mobile Condition Report repository: SQLite-backed, submitting via
/// [CrSubmissionService] from the in-memory document snapshot (`repo.formData`)
/// + POST + attachment sync + status recording. The web editor builds its own
/// `WebFormRepository` at the editor entry point; both now serialize the form
/// the same way (buildFromFormSnapshot) — only transport/endpoint differs.
FormRepository createCrMobileRepository() {
  final submission = CrSubmissionService(
    tokenStore: AuthTokenStore(),
    appInfoService: AppInfoService(),
  );
  return SqliteFormRepository(
    submitter: (id, formData) =>
        submission.submitForm(formId: id, formSnapshot: formData),
  );
}
