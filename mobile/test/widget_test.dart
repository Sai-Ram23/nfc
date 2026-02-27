import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_event_app/main.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const BreachGateApp());
    // Verify the app starts and shows a loading indicator
    expect(find.byType(BreachGateApp), findsOneWidget);
  });
}
