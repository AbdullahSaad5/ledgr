import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/widgets/ledgr_select.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  const options = [
    LedgrSelectOption(value: 1, label: 'One', icon: LucideIcons.sun),
    LedgrSelectOption(value: 2, label: 'Two', icon: LucideIcons.moon),
    LedgrSelectOption(value: 3, label: 'Three'),
  ];

  testWidgets('field shows label + selected option, sheet picks a new one', (
    tester,
  ) async {
    int? picked;
    await tester.pumpWidget(
      wrap(
        LedgrSelect<int>(
          label: 'Number',
          value: 1,
          options: options,
          onChanged: (v) => picked = v,
        ),
      ),
    );

    expect(find.text('Number'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);

    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    // Sheet lists all options with the current one checked.
    expect(find.text('Two'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(picked, 2);
  });

  testWidgets('compact pill renders and opens the same sheet', (tester) async {
    int? picked;
    await tester.pumpWidget(
      wrap(
        LedgrSelect<int>(
          label: 'Number',
          compact: true,
          value: 3,
          options: options,
          onChanged: (v) => picked = v,
        ),
      ),
    );

    expect(find.text('Three'), findsOneWidget);
    await tester.tap(find.text('Three'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(picked, 1);
  });

  testWidgets('dismissing the sheet keeps the current value', (tester) async {
    var changed = false;
    await tester.pumpWidget(
      wrap(
        LedgrSelect<int>(
          label: 'Number',
          value: 1,
          options: options,
          onChanged: (_) => changed = true,
        ),
      ),
    );
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    // Tap the barrier above the sheet.
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();
    expect(changed, isFalse);
  });
}
