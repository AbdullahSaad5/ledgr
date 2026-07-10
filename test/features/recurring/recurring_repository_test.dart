import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/recurring/data/recurring_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late RecurringRepository repo;
  late int account;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RecurringRepository(db, TransactionRepository(db));
    account = await AccountRepository(db).create(
      name: 'Bank',
      type: AccountType.bank,
      icon: 'account_balance',
      color: 0xFF000000,
      currency: 'PKR',
    );
  });
  tearDown(() => db.close());

  Future<int> monthlyRule({
    required DateTime nextDue,
    bool autoPost = true,
    int? remainingCount,
    DateTime? endDate,
    int amount = 50000,
  }) {
    return repo.create(
      RecurringRulesCompanion.insert(
        title: 'Rent',
        type: TxType.expense,
        amountMinor: amount,
        currency: 'PKR',
        accountId: account,
        frequency: Frequency.monthly,
        nextDue: nextDue,
        anchorDay: Value(nextDue.day),
        autoPost: Value(autoPost),
        remainingCount: Value(remainingCount),
        endDate: Value(endDate),
        categoryId: const Value(6), // Rent (seeded)
      ),
    );
  }

  Future<int> txCount() async => (await (db.select(
    db.transactions,
  )..where((t) => t.deletedAt.isNull())).get()).length;

  test('catch-up posts every missed occurrence once', () async {
    await monthlyRule(nextDue: DateTime(2026, 5, 1));
    // Three occurrences due by mid-July: May, Jun, Jul.
    final posted = await repo.catchUp(DateTime(2026, 7, 15));
    expect(posted, 3);
    expect(await txCount(), 3);
  });

  test('catch-up is idempotent across repeated runs', () async {
    await monthlyRule(nextDue: DateTime(2026, 5, 1));
    await repo.catchUp(DateTime(2026, 7, 15));
    final second = await repo.catchUp(DateTime(2026, 7, 15));
    expect(second, 0);
    expect(await txCount(), 3);
  });

  test('remind-only rules are not auto-posted', () async {
    await monthlyRule(nextDue: DateTime(2026, 5, 1), autoPost: false);
    final posted = await repo.catchUp(DateTime(2026, 7, 15));
    expect(posted, 0);
    expect(await txCount(), 0);
  });

  test('remainingCount terminates the rule', () async {
    final id = await monthlyRule(
      nextDue: DateTime(2026, 5, 1),
      remainingCount: 2,
    );
    final posted = await repo.catchUp(DateTime(2026, 12, 31));
    expect(posted, 2);
    final rule = await (db.select(
      db.recurringRules,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(rule.active, isFalse);
  });

  test('endDate stops posting', () async {
    await monthlyRule(
      nextDue: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 6, 15),
    );
    // May and June occurrences only (July > endDate).
    final posted = await repo.catchUp(DateTime(2026, 8, 1));
    expect(posted, 2);
  });

  test('upcoming lists occurrences within the horizon', () async {
    await monthlyRule(nextDue: DateTime(2026, 7, 1), autoPost: false);
    final items = await repo.upcoming(DateTime(2026, 6, 20), days: 30);
    expect(items, isNotEmpty);
    expect(items.first.date, DateTime(2026, 7, 1));
  });

  test('watchUpcoming re-emits when a rule is created (realtime)', () async {
    // Regression: upcoming was a one-shot Future, so the screen needed a
    // manual reload to see new or posted rules.
    final emissions = <int>[];
    final sub = repo.watchUpcoming().listen((items) {
      emissions.add(items.length);
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await monthlyRule(nextDue: DateTime.now(), autoPost: false);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await sub.cancel();
    expect(emissions.first, 0);
    expect(emissions.last, greaterThan(0));
  });

  test('markPaid posts one and advances the schedule', () async {
    final id = await monthlyRule(
      nextDue: DateTime(2026, 7, 1),
      autoPost: false,
    );
    final rule = await (db.select(
      db.recurringRules,
    )..where((r) => r.id.equals(id))).getSingle();
    await repo.markPaid(rule);
    expect(await txCount(), 1);
    final updated = await (db.select(
      db.recurringRules,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(updated.nextDue, DateTime(2026, 8, 1));
  });
}
