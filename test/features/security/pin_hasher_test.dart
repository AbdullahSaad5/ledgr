import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/features/security/domain/pin_hasher.dart';

void main() {
  test('verify succeeds for the correct pin', () {
    final stored = PinHasher.hash('1234', salt: 'abc');
    expect(PinHasher.verify('1234', stored), isTrue);
  });

  test('verify fails for the wrong pin', () {
    final stored = PinHasher.hash('1234', salt: 'abc');
    expect(PinHasher.verify('0000', stored), isFalse);
  });

  test('the same pin with a different salt yields a different hash', () {
    final a = PinHasher.hash('1234', salt: 'saltA');
    final b = PinHasher.hash('1234', salt: 'saltB');
    expect(a.hash, isNot(b.hash));
  });

  test('a generated salt is present and non-empty', () {
    final stored = PinHasher.hash('1234');
    expect(stored.salt, isNotEmpty);
    expect(PinHasher.verify('1234', stored), isTrue);
  });

  test('the pin is never stored in plaintext', () {
    final stored = PinHasher.hash('9999', salt: 'x');
    expect(stored.hash, isNot(contains('9999')));
  });
}
