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

  Future<int> create({
    required String name,
    required CategoryKind kind,
    required String icon,
    required int color,
    int? parentId,
  }) async {
    final position = await _nextPosition(kind);
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            kind: kind,
            icon: icon,
            color: color,
            position: position,
            parentId: Value(parentId),
          ),
        );
  }

  /// [parentId] is always written: pass the current value to keep it, null to
  /// make the category top-level.
  Future<void> update(
    int id, {
    required String name,
    required String icon,
    required int color,
    int? parentId,
  }) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        icon: Value(icon),
        color: Value(color),
        parentId: Value(parentId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reorder(List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(
          _db.categories,
        )..where((c) => c.id.equals(orderedIds[i]))).write(
          CategoriesCompanion(
            position: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  /// How many non-deleted transactions reference [categoryId] or one of its
  /// children (for the merge-on-delete prompt). Children count because
  /// deleting a parent reshapes where their spend appears.
  Future<int> transactionCount(int categoryId) async {
    final children = await (_db.select(
      _db.categories,
    )..where((c) => c.parentId.equals(categoryId))).get();
    final ids = [categoryId, ...children.map((c) => c.id)];
    final count = _db.transactions.id.count();
    final row =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([count])
              ..where(
                _db.transactions.categoryId.isIn(ids) &
                    _db.transactions.deletedAt.isNull(),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Delete [fromId] by reassigning its transactions and recurring rules to
  /// [toId], promoting its children to top-level, tombstoning any budget on
  /// it, then tombstoning it. Children never follow the merge target (which
  /// could itself be a child — nesting is one level). One transaction so the
  /// move and the delete are atomic.
  Future<void> mergeAndDelete(int fromId, {int? toId}) {
    return _db.transaction(() async {
      final now = DateTime.now();
      if (toId != null) {
        await (_db.update(
          _db.transactions,
        )..where((t) => t.categoryId.equals(fromId))).write(
          TransactionsCompanion(categoryId: Value(toId), updatedAt: Value(now)),
        );
      }
      // Recurring rules keep posting after the delete, so they must not keep
      // pointing at a tombstoned category. No merge target = uncategorized.
      await (_db.update(
        _db.recurringRules,
      )..where((r) => r.categoryId.equals(fromId))).write(
        RecurringRulesCompanion(categoryId: Value(toId), updatedAt: Value(now)),
      );
      // A budget on the deleted category can never receive spend again;
      // tombstone it rather than leave a nameless frozen row.
      await (_db.update(
        _db.budgets,
      )..where((b) => b.categoryId.equals(fromId))).write(
        BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.update(
        _db.categories,
      )..where((c) => c.parentId.equals(fromId))).write(
        CategoriesCompanion(
          parentId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(
        _db.categories,
      )..where((c) => c.id.equals(fromId))).write(
        CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  Future<int> _nextPosition(CategoryKind kind) async {
    final maxPos = _db.categories.position.max();
    final row =
        await (_db.selectOnly(_db.categories)
              ..addColumns([maxPos])
              ..where(_db.categories.kind.equalsValue(kind)))
            .getSingle();
    return (row.read(maxPos) ?? -1) + 1;
  }
}
