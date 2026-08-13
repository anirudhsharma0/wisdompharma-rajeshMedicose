import 'package:flutter_test/flutter_test.dart';
import 'package:medical_store/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MedicalStoreApp());

    // Verify that the widget app renders without throwing exceptions
    expect(find.byType(MedicalStoreApp), findsOneWidget);
  });
}
