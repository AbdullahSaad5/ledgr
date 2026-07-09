import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/tags/data/tag_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
import 'package:ledgr/features/transactions/domain/transaction_filter.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository tx;
  late int cash;
  late int bank;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tx = TransactionRepository(db);
    final accounts = AccountRepository(db);
    cash = await accounts.create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );
    bank = await accounts.create(
      name: 'Bank',
      type: AccountType.bank,
      icon: 'account_balance',
      color: 0xFF000000,
      currency: 'PKR',
    );
  });
  tearDown(() => db.close());

  Future<int> make({
    required int account,
    required int amount,
    TxType type = TxType.expense,
    int category = 1,
    String? payee,
    String? note,
    DateTime? date,
  }) => tx.create(
        TransactionDraft(
          type: type,
          amountMinor: amount,
          currency: 'PKR',
          accountId: account,
          categoryId: type == TxType.transfer ? null : category,
          toAccountId: type == TxType.transfer ? bank : null,
          payee: payee,
          note: note,
          date: date ?? DateTime(2026, 7, 10),
        ),
      );

  Future<List<Transaction>> filter(TransactionFilter f) =>
      tx.watchFiltered(f).first;

  test('text matches payee or note, case-insensitively', () async {
    await make(account: cash, amount: 100, payee: 'Careem');
    await make(account: cash, amount: 200, note: 'careem ride refund');
    await make(account: cash, amount: 300, payee: 'Daraz');

    final res = await filter(const TransactionFilter(text: 'careem'));
    expect(res.map((t) => t.amountMinor), containsAll([100, 200]));
    expect(res.map((t) => t.amountMinor), isNot(contains(300)));
  });

  test('account filter matches source or transfer target', () async {
    await make(account: cash, amount: 100);
    await make(account: cash, amount: 200, type: TxType.transfer); // cash->bank
    final byBank = await filter(TransactionFilter(accountIds: {bank}));
    expect(byBank.map((t) => t.amountMinor), [200]); // transfer target
  });

  test('type and amount-range filters combine', () async {
    await make(account: cash, amount: 100, type: TxType.income, category: 19);
    await make(account: cash, amount: 5000);
    await make(account: cash, amount: 50000);

    final res = await filter(
      const TransactionFilter(
        types: {TxType.expense},
        minMinor: 1000,
        maxMinor: 10000,
      ),
    );
    expect(res.map((t) => t.amountMinor), [5000]);
  });

  test('date range is inclusive on both ends', () async {
    await make(account: cash, amount: 1, date: DateTime(2026, 7, 1));
    await make(account: cash, amount: 2, date: DateTime(2026, 7, 15));
    await make(account: cash, amount: 3, date: DateTime(2026, 7, 31));
    final res = await filter(
      TransactionFilter(from: DateTime(2026, 7, 10), to: DateTime(2026, 7, 20)),
    );
    expect(res.map((t) => t.amountMinor), [2]);
  });

  test('tag filter returns transactions carrying any of the tags', () async {
    final tags = TagRepository(db);
    final a = await make(account: cash, amount: 100);
    final b = await make(account: cash, amount: 200);
    await make(account: cash, amount: 300);
    final work = await tags.getOrCreate('work');
    await tags.setTagsForTransaction(a, {work.id});
    await tags.setTagsForTransaction(b, {work.id});

    final res = await filter(TransactionFilter(tagIds: {work.id}));
    expect(res.map((t) => t.amountMinor), containsAll([100, 200]));
    expect(res.length, 2);
  });

  test('empty filter returns everything', () async {
    await make(account: cash, amount: 100);
    await make(account: cash, amount: 200);
    expect(await filter(const TransactionFilter()), hasLength(2));
    expect(const TransactionFilter().isEmpty, isTrue);
  });
}
