import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/attachments/data/attachment_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

void main() {
  late AppDatabase db;
  late Directory docs;
  late AttachmentRepository repo;
  late int txId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = await Directory.systemTemp.createTemp('ledgr_attach_test');
    repo = AttachmentRepository(db, docsDir: () async => docs);
    final cash = await AccountRepository(db).create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );
    txId = await TransactionRepository(db).create(
      TransactionDraft(
        type: TxType.expense,
        amountMinor: 500,
        currency: 'PKR',
        accountId: cash,
        categoryId: 1,
        date: DateTime(2026, 7, 10),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
  });

  Future<File> fakeImage() async {
    final f = File('${docs.path}/source.jpg');
    await f.writeAsBytes([1, 2, 3, 4]);
    return f;
  }

  test('add copies the image into app storage and links it', () async {
    final source = await fakeImage();
    final id = await repo.add(txId, sourcePath: source.path);

    final rows = await repo.watchForTransaction(txId).first;
    expect(rows, hasLength(1));
    expect(rows.single.id, id);

    final copied = await repo.fileFor(rows.single);
    expect(copied.existsSync(), isTrue);
    // The copy lives under our receipts dir, not the source location.
    expect(copied.path, contains('receipts'));
    expect(copied.path, isNot(source.path));

    // Deleting the "gallery" original leaves the receipt intact.
    await source.delete();
    expect(copied.existsSync(), isTrue);
  });

  test('remove tombstones the row and deletes the copied file', () async {
    final source = await fakeImage();
    final id = await repo.add(txId, sourcePath: source.path);
    final row = (await repo.watchForTransaction(txId).first).single;
    final copied = await repo.fileFor(row);

    await repo.remove(id);

    expect(await repo.watchForTransaction(txId).first, isEmpty);
    expect(copied.existsSync(), isFalse);
  });

  test('pruneOrphanFiles deletes files without a live row', () async {
    final source = await fakeImage();
    await repo.add(txId, sourcePath: source.path);
    final kept = await repo.fileFor(
      (await repo.watchForTransaction(txId).first).single,
    );
    // Simulate what a replace-all restore leaves behind: a file whose row
    // is gone.
    final orphan = File('${docs.path}/receipts/orphan.jpg');
    await orphan.writeAsBytes([9, 9]);

    await repo.pruneOrphanFiles();

    expect(kept.existsSync(), isTrue);
    expect(orphan.existsSync(), isFalse);
  });
}
