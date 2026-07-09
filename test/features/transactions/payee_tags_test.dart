import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/tags/data/tag_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository tx;
  late int account;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tx = TransactionRepository(db);
    account = await AccountRepository(db).create(
      name: 'A',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );
  });
  tearDown(() => db.close());

  Future<void> expense(String payee, {int category = 1}) => tx.create(
    TransactionDraft(
      type: TxType.expense,
      amountMinor: 100,
      currency: 'PKR',
      accountId: account,
      categoryId: category,
      date: DateTime(2026, 7, 1),
      payee: payee,
    ),
  );

  group('payee autocomplete', () {
    test('ranks by frequency then filters by prefix', () async {
      await expense('Careem');
      await expense('Careem');
      await expense('Cafe');
      await expense('Daraz');

      final all = await tx.payeeSuggestions('');
      expect(all.first, 'Careem'); // most frequent

      final ca = await tx.payeeSuggestions('ca');
      expect(ca, containsAll(['Careem', 'Cafe']));
      expect(ca, isNot(contains('Daraz')));
    });

    test('suggests the most common category for a payee', () async {
      await expense('Careem', category: 3);
      await expense('Careem', category: 3);
      await expense('Careem', category: 5);
      expect(await tx.commonCategoryForPayee('Careem'), 3);
      expect(await tx.commonCategoryForPayee('Unknown'), isNull);
    });
  });

  group('tags', () {
    test('getOrCreate dedupes by name', () async {
      final tags = TagRepository(db);
      final a = await tags.getOrCreate('urgent');
      final b = await tags.getOrCreate('urgent');
      expect(a.id, b.id);
    });

    test('setTagsForTransaction replaces the set', () async {
      final tags = TagRepository(db);
      final txId = await tx.create(
        TransactionDraft(
          type: TxType.expense,
          amountMinor: 100,
          currency: 'PKR',
          accountId: account,
          categoryId: 1,
          date: DateTime(2026, 7, 1),
        ),
      );
      final work = await tags.getOrCreate('work');
      final food = await tags.getOrCreate('food');
      await tags.setTagsForTransaction(txId, {work.id, food.id});
      expect((await tags.tagsForTransaction(txId)).length, 2);

      await tags.setTagsForTransaction(txId, {work.id});
      final remaining = await tags.tagsForTransaction(txId);
      expect(remaining.map((t) => t.name), ['work']);
    });
  });
}
