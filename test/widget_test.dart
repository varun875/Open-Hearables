import 'package:flutter_test/flutter_test.dart';
import 'package:open_hearables/main.dart';

void main() {
  testWidgets('OpenHearablesApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenHearablesApp());
    expect(find.text('Open Hearables'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
