import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';

/// Tags and their attachment to transactions (many-to-many).
class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;

  Stream<List<Tag>> watchAll() {
    return (_db.select(_db.tags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<Tag> getOrCreate(String name, {int color = 0xFF607D8B}) async {
    final normalized = name.trim();
    final existing =
        await (_db.select(_db.tags)
              ..where((t) => t.name.equals(normalized) & t.deletedAt.isNull()))
            .getSingleOrNull();
    if (existing != null) return existing;
    final id = await _db
        .into(_db.tags)
        .insert(TagsCompanion.insert(name: normalized, color: color));
    return (_db.select(_db.tags)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Replace the tag set on a transaction.
  Future<void> setTagsForTransaction(int transactionId, Set<int> tagIds) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.transactionTags,
      )..where((tt) => tt.transactionId.equals(transactionId))).go();
      for (final tagId in tagIds) {
        await _db
            .into(_db.transactionTags)
            .insert(
              TransactionTagsCompanion.insert(
                transactionId: transactionId,
                tagId: tagId,
              ),
            );
      }
    });
  }

  Future<List<Tag>> tagsForTransaction(int transactionId) {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.transactionTags,
        _db.transactionTags.tagId.equalsExp(_db.tags.id),
      ),
    ])..where(_db.transactionTags.transactionId.equals(transactionId));
    return query.map((row) => row.readTable(_db.tags)).get();
  }
}
