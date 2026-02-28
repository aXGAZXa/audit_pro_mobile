// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:audit_pro_mobile/app/audit_pro_app.dart';

void main() {
  testWidgets('App boots and shows home', (WidgetTester tester) async {
    await tester.pumpWidget(const AuditProApp());
    expect(find.text('AuditPro'), findsWidgets);
    expect(find.text('Open Sample Form'), findsOneWidget);
  });
}
