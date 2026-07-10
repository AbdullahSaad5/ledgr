import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/categories/data/category_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });
  tearDown(() => db.close());

  test('create appends after the seeded categories', () async {
    final before = await repo.byKind(CategoryKind.expense);
    final id = await repo.create(
      name: 'Hobbies',
      kind: CategoryKind.expense,
      icon: 'category',
      color: 0xFF000000,
    );
    final after = await repo.byKind(CategoryKind.expense);
    expect(after.length, before.length + 1);
    expect(after.map((c) => c.id), contains(id));
  });

  test('update changes name/icon/color', () async {
    final id = await repo.create(
      name: 'Old',
      kind: CategoryKind.expense,
      icon: 'category',
      color: 0xFF111111,
    );
    await repo.update(id, name: 'New', icon: 'home', color: 0xFF222222);
    final c = await repo.byId(id);
    expect(c!.name, 'New');
    expect(c.icon, 'home');
    expect(c.color, 0xFF222222);
  });

  test('update can move a category under a parent and back out', () async {
    final parent = await repo.create(
      name: 'Bills',
      kind: CategoryKind.expense,
      icon: 'receipt_long',
      color: 0xFF000000,
    );
    final id = await repo.create(
      name: 'Electricity',
      kind: CategoryKind.expense,
      icon: 'bolt',
      color: 0xFF000000,
    );
    await repo.update(
      id,
      name: 'Electricity',
      icon: 'bolt',
      color: 0xFF000000,
      parentId: parent,
    );
    expect((await repo.byId(id))!.parentId, parent);

    await repo.update(
      id,
      name: 'Electricity',
      icon: 'bolt',
      color: 0xFF000000,
      parentId: null,
    );
    expect((await repo.byId(id))!.parentId, isNull);
  });

  group('mergeAndDelete', () {
    test(
      'reassigns transactions to the target and tombstones the source',
      () async {
        final accounts = AccountRepository(db);
        final tx = TransactionRepository(db);
        final acc = await accounts.create(
          name: 'A',
          type: AccountType.cash,
          icon: 'payments',
          color: 0xFF000000,
          currency: 'PKR',
        );
        final from = await repo.create(
          name: 'From',
          kind: CategoryKind.expense,
          icon: 'category',
          color: 0xFF000000,
        );
        final to = await repo.create(
          name: 'To',
          kind: CategoryKind.expense,
          icon: 'category',
          color: 0xFF000000,
        );
        await tx.create(
          TransactionDraft(
            type: TxType.expense,
            amountMinor: 500,
            currency: 'PKR',
            accountId: acc,
            categoryId: from,
            date: DateTime(2026, 7, 1),
          ),
        );

        expect(await repo.transactionCount(from), 1);
        await repo.mergeAndDelete(from, toId: to);

        expect(await repo.transactionCount(from), 0);
        expect(await repo.transactionCount(to), 1);
        final kinds = await repo.byKind(CategoryKind.expense);
        expect(kinds.map((c) => c.id), isNot(contains(from)));
        expect(kinds.map((c) => c.id), contains(to));
      },
    );

    test(
      'promotes children to top-level even when merging into a target',
      () async {
        final parent = await repo.create(
          name: 'Bills',
          kind: CategoryKind.expense,
          icon: 'receipt_long',
          color: 0xFF000000,
        );
        final child = await repo.create(
          name: 'Electricity',
          kind: CategoryKind.expense,
          icon: 'bolt',
          color: 0xFF000000,
          parentId: parent,
        );
        final other = await repo.create(
          name: 'Other bills',
          kind: CategoryKind.expense,
          icon: 'category',
          color: 0xFF000000,
        );
        await repo.mergeAndDelete(parent, toId: other);
        // One-level nesting: a child never follows the merge target (which
        // could itself be a child) — it becomes top-level instead.
        final reloaded = await repo.byId(child);
        expect(reloaded!.parentId, isNull);
      },
    );

    test('detaches children when no target is given', () async {
      final parent = await repo.create(
        name: 'Bills',
        kind: CategoryKind.expense,
        icon: 'receipt_long',
        color: 0xFF000000,
      );
      final child = await repo.create(
        name: 'Electricity',
        kind: CategoryKind.expense,
        icon: 'bolt',
        color: 0xFF000000,
        parentId: parent,
      );
      await repo.mergeAndDelete(parent);
      final reloaded = await repo.byId(child);
      expect(reloaded!.parentId, isNull);
    });
  });

  test('reorder writes compacted positions within a kind', () async {
    final a = await repo.create(
      name: 'A',
      kind: CategoryKind.income,
      icon: 'category',
      color: 0xFF000000,
    );
    final b = await repo.create(
      name: 'B',
      kind: CategoryKind.income,
      icon: 'category',
      color: 0xFF000000,
    );
    await repo.reorder([b, a]);
    final pa = await repo.byId(a);
    final pb = await repo.byId(b);
    expect(pb!.position, lessThan(pa!.position));
  });
}
