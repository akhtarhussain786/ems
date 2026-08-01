import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EAMSApp());
    expect(find.text('EAMS'), findsOneWidget);
  });
}
