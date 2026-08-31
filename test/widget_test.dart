import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connectme/app.dart';

void main() {
  testWidgets('App boots and shows the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));
    await tester.pumpAndSettle();

    expect(find.text('Добре дошъл отново'), findsOneWidget);
    expect(find.text('Вход'), findsOneWidget);
  });
}
