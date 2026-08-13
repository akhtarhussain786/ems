import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yatharthems_apps/main.dart';

void main() {
  testWidgets('app boots to the splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const EAMSApp());

    // The stock template test asserted 'EAMS', which this app has never shown.
    expect(find.text('Yatharth Connect'), findsOneWidget);

    // Splash waits 3s before routing. Let that fire, then tear the tree down,
    // so no timer or ticker outlives the test.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });
}
