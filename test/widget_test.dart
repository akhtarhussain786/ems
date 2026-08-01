import 'package:flutter_test/flutter_test.dart';
import 'package:yatharthems_apps/main.dart';

void main() {
  testWidgets('Counter smoke test (optional)', (WidgetTester tester) async {
    await tester.pumpWidget(const EAMSApp());
    expect(find.text('EAMS'), findsOneWidget);
  });
}
