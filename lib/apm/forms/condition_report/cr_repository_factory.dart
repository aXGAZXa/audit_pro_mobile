import 'package:audit_pro_mobile/apm/forms/condition_report/services/cr_submission_service.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/sqlite_form_repository.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';

/// Mobile Condition Report repository: SQLite-backed, submitting via
/// [CrSubmissionService] (build from the tables + POST + attachment sync +
/// status recording — the proven mobile path, unchanged). The web editor builds
/// its own `WebFormRepository` at the editor entry point.
FormRepository createCrMobileRepository() {
  final submission = CrSubmissionService(
    tokenStore: AuthTokenStore(),
    appInfoService: AppInfoService(),
  );
  return SqliteFormRepository(
    submitter: (id) => submission.submitForm(formId: id),
  );
}
