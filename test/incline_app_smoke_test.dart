import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('InclineApp initializes and renders root application cleanly', (tester) async {
    await tester.pumpWidget(const InclineApp());
    expect(find.byType(InclineApp), findsOneWidget);
  });
}
