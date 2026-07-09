import 'package:drift/drift.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// Public because Drift copies these references verbatim into the generated
// database part, which resolves them through this file's import, not
// lexically.
String dbNewUuid() => _uuid.v4();
DateTime dbNow() => DateTime.now();

/// Columns every **syncable** table carries (ADR-0005). `uuid` is the stable
/// cross-device identity; `updatedAt` must be touched on every write (the
/// repository's job); `deletedAt` is a tombstone — syncable rows are
/// soft-deleted, never removed, and every query filters `deletedAt IS NULL`.
mixin SyncColumns on Table {
  TextColumn get uuid => text().unique().clientDefault(dbNewUuid)();
  DateTimeColumn get createdAt => dateTime().clientDefault(dbNow)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(dbNow)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@TableIndex(name: 'idx_accounts_position', columns: {#position})
class Accounts extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get type => intEnum<AccountType>()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();
  TextColumn get currency => text()();
  IntColumn get creditLimitMinor => integer().nullable()();
  BoolColumn get includeInNetWorth =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();
}

class Categories extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get kind => intEnum<CategoryKind>()();
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get position => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'idx_tx_date', columns: {#date})
@TableIndex(name: 'idx_tx_account_date', columns: {#accountId, #date})
@TableIndex(name: 'idx_tx_category_date', columns: {#categoryId, #date})
@TableIndex(name: 'idx_tx_payee', columns: {#payee})
class Transactions extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => intEnum<TxType>()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  IntColumn get feeMinor => integer().nullable()();
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get payee => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();
  IntColumn get recurringRuleId => integer().nullable().references(
    RecurringRules,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get debtId => integer().nullable().references(
    Debts,
    #id,
    onDelete: KeyAction.setNull,
  )();
}

class Tags extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get color => integer()();
}

class TransactionTags extends Table {
  IntColumn get transactionId =>
      integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

class Attachments extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId =>
      integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
}

class Budgets extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get limitMinor => integer()();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

@TableIndex(name: 'idx_rules_next_due', columns: {#nextDue, #active})
class RecurringRules extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 60)();
  IntColumn get type => intEnum<TxType>()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get payee => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get frequency => intEnum<Frequency>()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  IntColumn get anchorDay => integer().nullable()();
  DateTimeColumn get nextDue => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get remainingCount => integer().nullable()();
  BoolColumn get autoPost => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

class Debts extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text().withLength(min: 1, max: 60)();
  IntColumn get direction => intEnum<DebtDirection>()();
  IntColumn get principalMinor => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
}

class DebtPayments extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId =>
      integer().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get date => dateTime()();
  IntColumn get transactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();
}
