import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connectme/app.dart';

void main() {
  testWidgets('App boots and shows the component gallery', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));
    await tester.pumpAndSettle();

    expect(find.text('Мария'), findsOneWidget);
    expect(find.text('Ще стигнеш ли до 7?'), findsOneWidget);
  });
}
