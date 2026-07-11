import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/app/router.dart';

void main() {
  group('normalizeDeepLink (ledgr#18, Tokri handoff)', () {
    test('rewrites host-form ledgr://tx/new to the /tx/new route', () {
      final result = normalizeDeepLink(
        Uri.parse(
          'ledgr://tx/new?amountMinor=45000&payee=Groceries&note=Trip+from+Tokri',
        ),
      );
      expect(result, isNotNull);
      expect(result!.path, '/tx/new');
      expect(result.queryParameters['amountMinor'], '45000');
      expect(result.queryParameters['payee'], 'Groceries');
      expect(result.queryParameters['note'], 'Trip from Tokri');
    });

    test('leaves the path-form widget link alone', () {
      expect(normalizeDeepLink(Uri.parse('ledgr:///tx/new')), isNull);
      expect(normalizeDeepLink(Uri.parse('/tx/new')), isNull);
    });

    test('ignores other hosts and paths', () {
      expect(normalizeDeepLink(Uri.parse('ledgr://tx/edit')), isNull);
      expect(normalizeDeepLink(Uri.parse('ledgr://home/new')), isNull);
    });

    test('host-form link without params still normalizes', () {
      final result = normalizeDeepLink(Uri.parse('ledgr://tx/new'));
      expect(result, isNotNull);
      expect(result!.path, '/tx/new');
      expect(result.queryParameters, isEmpty);
    });
  });

  group('TxPrefill.fromQuery', () {
    test('parses the Tokri contract: hundredths amount, payee, note', () {
      final prefill = TxPrefill.fromQuery(const {
        'amountMinor': '45000',
        'payee': 'Groceries',
        'note': 'Trip from Tokri',
      });
      expect(prefill.amountHundredths, 45000);
      expect(prefill.payee, 'Groceries');
      expect(prefill.note, 'Trip from Tokri');
    });

    test('ignores junk amounts and unknown params', () {
      final prefill = TxPrefill.fromQuery(const {
        'amountMinor': '-5',
        'payee': 'x',
        'surprise': 'y',
      });
      expect(prefill.amountHundredths, isNull);
      expect(prefill.payee, 'x');
      expect(prefill.note, isNull);

      expect(
        TxPrefill.fromQuery(const {'amountMinor': 'abc'}).amountHundredths,
        isNull,
      );
    });
  });
}
