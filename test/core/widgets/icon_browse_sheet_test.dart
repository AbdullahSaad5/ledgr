import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/widgets/icon_browse_sheet.dart';

void main() {
  testWidgets('search filters the catalog and returns the tapped name', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await IconBrowseSheet.show(
                    context,
                    selected: 'category',
                    accent: Colors.teal,
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
    expect(find.text('All icons'), findsOneWidget);

    // Narrow the grid down to the water_drop icon and pick it.
    await tester.enterText(find.byType(TextField), 'water');
    await tester.pumpAndSettle();
    final badges = find.byType(InkWell);
    expect(badges, findsWidgets);
    await tester.tap(badges.last);
    await tester.pumpAndSettle();
    expect(picked, 'water_drop');
  });

  testWidgets('no-match query shows the empty message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => IconBrowseSheet.show(
                  context,
                  selected: 'category',
                  accent: Colors.teal,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No icons match "zzzz"'), findsOneWidget);
  });
}
