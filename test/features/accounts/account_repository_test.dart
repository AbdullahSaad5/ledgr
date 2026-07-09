import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AccountRepository(db);
  });
  tearDown(() => db.close());

  Future<int> makeAccount(String name, {int opening = 0}) => repo.create(
    name: name,
    type: AccountType.bank,
    icon: 'account_balance',
    color: 0xFF000000,
    currency: 'PKR',
    openingBalanceMinor: opening,
  );

  group('create + positions', () {
    test('assigns incrementing positions', () async {
      final a = await makeAccount('A');
      final b = await makeAccount('B');
      final list = await repo.watchActive().first;
      expect(list.map((e) => e.id), [a, b]);
      expect(list.map((e) => e.position), [0, 1]);
    });

    test('populates uuid and updatedAt', () async {
      final id = await makeAccount('A');
      final account = await repo.watchById(id).first;
      expect(account.uuid, isNotEmpty);
      expect(account.archived, isFalse);
    });
  });

  group('balances', () {
    test('watchActiveWithBalances reflects opening balance', () async {
      await makeAccount('A', opening: 250000);
      final list = await repo.watchActiveWithBalances().first;
      expect(list.single.balanceMinor, 250000);
    });
  });

  group('archive (never hard-delete)', () {
    test('archived accounts drop out of the active list but survive', () async {
      final id = await makeAccount('A');
      await repo.setArchived(id, archived: true);
      expect(await repo.watchActive().first, isEmpty);
      // Row still exists.
      final account = await repo.watchById(id).first;
      expect(account.archived, isTrue);
    });
  });

  group('reorder', () {
    test('writes compacted positions', () async {
      final a = await makeAccount('A');
      final b = await makeAccount('B');
      final c = await makeAccount('C');
      await repo.reorder([c, a, b]);
      final list = await repo.watchActive().first;
      expect(list.map((e) => e.id), [c, a, b]);
    });
  });

  group('reconcile', () {
    test('posts a signed adjustment so balance matches target', () async {
      final id = await makeAccount('A', opening: 100000);
      final txId = await repo.reconcile(id, targetMinor: 90000);
      expect(txId, isNotNull);
      expect(await repo.balance(id), 90000);
    });

    test('reconciling upward also works', () async {
      final id = await makeAccount('A', opening: 100000);
      await repo.reconcile(id, targetMinor: 130000);
      expect(await repo.balance(id), 130000);
    });

    test('no-op when already reconciled', () async {
      final id = await makeAccount('A', opening: 100000);
      final txId = await repo.reconcile(id, targetMinor: 100000);
      expect(txId, isNull);
      expect(await repo.balance(id), 100000);
    });
  });
}
