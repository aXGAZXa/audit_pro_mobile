// Regression: the web editor feeds formData straight from JSON, where dates are
// STRINGS (e.g. auditDate: "2025-12-10"). Site Details must render without
// throwing when given that shape — previously it assigned the string into a
// DateTime? field and AppDateField blew up, surfacing as a grey ErrorWidget.
import 'package:audit_pro_mobile/apm/forms/condition_report/screens/site_details_screen.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal repo stub mirroring the web editor: reference catalogs resolve fast
/// (here empty, as for an older submission whose payload predates bundling).
class _StubRepo implements FormRepository {
  @override
  Future<List<Map<String, dynamic>>> getReferenceCollection(String name) async =>
      const <Map<String, dynamic>>[];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Site Details renders with JSON string auditDate (web shape)', (
    tester,
  ) async {
    final formData = <String, dynamic>{
      'auditDate': '2025-12-10', // web payload: date is a JSON String
      'client': 'Acme Housing',
      'propertyType': 'Communal Block',
      'siteName': 'Riverside Court',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiteDetailsScreen(
            repo: _StubRepo(),
            formData: formData,
            onDataChanged: (_, _) {},
            onNext: () {},
          ),
        ),
      ),
    );
    // Let _loadReferenceData resolve; avoid pumpAndSettle (spinner animates).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Site Details'), findsOneWidget);
    expect(find.text('Acme Housing'), findsOneWidget); // seeded into dropdown
  });
}
