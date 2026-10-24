import 'package:flutter_test/flutter_test.dart';
import 'package:aluminios_app/main.dart';
import 'package:aluminios_app/state/app_state.dart';

void main() {
  testWidgets('Aluminios app smoke test', (WidgetTester tester) async {
    final appState = AppState();
    await tester.pumpWidget(AluminiosApp(appState: appState));
    expect(find.text('ALUMINIOS'), findsWidgets);
  });
}
