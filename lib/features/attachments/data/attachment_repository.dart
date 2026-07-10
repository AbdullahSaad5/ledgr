import 'dart:io';

import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:path_provider/path_provider.dart';

/// Receipt images for transactions (#17).
///
/// Images are **copied into app-private storage** (`<documents>/receipts/`)
/// the moment they're attached — the DB stores only the relative path, never
/// the bytes (blobs would bloat the DB and every backup), and deleting the
/// original from the gallery can't break the receipt.
class AttachmentRepository {
  AttachmentRepository(this._db, {Future<Directory> Function()? docsDir})
    : _docsDir = docsDir ?? getApplicationDocumentsDirectory;

  final AppDatabase _db;
  final Future<Directory> Function() _docsDir;

  Stream<List<Attachment>> watchForTransaction(int transactionId) {
    return (_db.select(_db.attachments)..where(
          (a) => a.transactionId.equals(transactionId) & a.deletedAt.isNull(),
        ))
        .watch();
  }

  /// Copies the picked image into the receipts folder and links it to the
  /// transaction. Returns the attachment id.
  Future<int> add(int transactionId, {required String sourcePath}) async {
    final docs = await _docsDir();
    final receipts = Directory('${docs.path}/receipts');
    await receipts.create(recursive: true);

    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_$transactionId$ext';
    await File(sourcePath).copy('${receipts.path}/$name');

    return _db
        .into(_db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            transactionId: transactionId,
            path: 'receipts/$name',
          ),
        );
  }

  /// The absolute file behind an attachment row.
  Future<File> fileFor(Attachment attachment) async {
    final docs = await _docsDir();
    return File('${docs.path}/${attachment.path}');
  }

  /// Tombstones the row (sync-ready, ADR-0005) and deletes the copied file.
  Future<void> remove(int id) async {
    final row = await (_db.select(
      _db.attachments,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final now = DateTime.now();
    await (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    final file = await fileFor(row);
    if (file.existsSync()) await file.delete();
  }
}
