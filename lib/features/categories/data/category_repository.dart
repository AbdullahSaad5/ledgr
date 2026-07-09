import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';

/// Read access to categories for pickers and grouping (full CRUD lands in M2).
class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchByKind(CategoryKind kind) {
    return (_db.select(_db.categories)
          ..where((c) => c.kind.equalsValue(kind) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm(expression: c.position)]))
        .watch();
  }

  Future<List<Category>> byKind(CategoryKind kind) {
    return (_db.select(_db.categories)
          ..where((c) => c.kind.equalsValue(kind) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm(expression: c.position)]))
        .get();
  }

  Future<Category?> byId(int id) {
    return (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Stream<List<Category>> watchAll() {
    return (_db.select(
      _db.categories,
    )..where((c) => c.deletedAt.isNull())).watch();
  }
}
