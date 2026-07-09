import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';

/// Default category set seeded on first launch (PLAN.md §3.1). The exact list,
/// icons, and colors are refined by the seed-data ticket (#3); this is the
/// working default so a fresh install is never empty.
class _SeedCategory {
  const _SeedCategory(this.name, this.icon, this.color);
  final String name;
  final String icon;
  final int color;
}

const _expense = <_SeedCategory>[
  _SeedCategory('Food & Dining', 'restaurant', 0xFFEF6C00),
  _SeedCategory('Groceries', 'shopping_basket', 0xFF43A047),
  _SeedCategory('Transport', 'directions_bus', 0xFF1E88E5),
  _SeedCategory('Fuel', 'local_gas_station', 0xFF6D4C41),
  _SeedCategory('Bills & Utilities', 'receipt_long', 0xFF00897B),
  _SeedCategory('Rent', 'home', 0xFF5E35B1),
  _SeedCategory('Shopping', 'shopping_bag', 0xFFD81B60),
  _SeedCategory('Health', 'favorite', 0xFFE53935),
  _SeedCategory('Education', 'school', 0xFF3949AB),
  _SeedCategory('Entertainment', 'movie', 0xFF8E24AA),
  _SeedCategory('Subscriptions', 'subscriptions', 0xFF00ACC1),
  _SeedCategory('Travel', 'flight', 0xFF039BE5),
  _SeedCategory('Family', 'family_restroom', 0xFF7CB342),
  _SeedCategory('Charity / Zakat', 'volunteer_activism', 0xFF00A152),
  _SeedCategory('Fees', 'account_balance', 0xFF757575),
  _SeedCategory('Personal Care', 'spa', 0xFFEC407A),
  _SeedCategory('Gifts', 'card_giftcard', 0xFFF4511E),
  _SeedCategory('Other', 'category', 0xFF9E9E9E),
];

const _income = <_SeedCategory>[
  _SeedCategory('Salary', 'payments', 0xFF2E7D32),
  _SeedCategory('Business', 'storefront', 0xFF1565C0),
  _SeedCategory('Freelance', 'work', 0xFF6A1B9A),
  _SeedCategory('Gifts', 'card_giftcard', 0xFFAD1457),
  _SeedCategory('Interest / Profit', 'trending_up', 0xFF00838F),
  _SeedCategory('Refunds', 'undo', 0xFF546E7A),
  _SeedCategory('Other', 'category', 0xFF9E9E9E),
];

/// Inserts the default categories. Idempotent-safe to call only on DB creation.
Future<void> seedDefaults(AppDatabase db) async {
  await db.batch((batch) {
    var position = 0;
    for (final c in _expense) {
      batch.insert(
        db.categories,
        CategoriesCompanion.insert(
          name: c.name,
          kind: CategoryKind.expense,
          icon: c.icon,
          color: c.color,
          position: position++,
          isDefault: const Value(true),
        ),
      );
    }
    position = 0;
    for (final c in _income) {
      batch.insert(
        db.categories,
        CategoriesCompanion.insert(
          name: c.name,
          kind: CategoryKind.income,
          icon: c.icon,
          color: c.color,
          position: position++,
          isDefault: const Value(true),
        ),
      );
    }
  });
}
