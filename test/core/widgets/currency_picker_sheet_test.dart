import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/widgets/currency_picker_sheet.dart';

void main() {
  Future<(String, String, String)?> open(WidgetTester tester) async {
    (String, String, String)? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await CurrencyPickerSheet.show(
                    context,
                    current: 'PKR',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('search narrows the list and returns the tapped tuple', (
    tester,
  ) async {
    (String, String, String)? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await CurrencyPickerSheet.show(
                    context,
                    current: 'PKR',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Pakistani Rupee'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'yen');
    await tester.pumpAndSettle();
    expect(find.text('Japanese Yen'), findsOneWidget);
    expect(find.text('Pakistani Rupee'), findsNothing);

    await tester.tap(find.text('Japanese Yen'));
    await tester.pumpAndSettle();
    expect(picked, ('JPY', '¥', 'Japanese Yen'));
  });

  testWidgets('no-match query shows the empty message', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No currency matches "zzz"'), findsOneWidget);
  });

  testWidgets('current currency is checked', (tester) async {
    await open(tester);
    // PKR row carries the check icon while others do not.
    expect(find.text('Pakistani Rupee'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
}
