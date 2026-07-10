import 'package:flutter/material.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Resolves the icon-name strings stored on categories/accounts to concrete
/// [IconData]. A registry (not dynamic lookup) so icons stay tree-shakeable.
///
/// Names are stable identifiers persisted in the DB; the glyphs they map to
/// are a presentation choice (currently Lucide) and may be restyled freely.
abstract final class AppIcons {
  static const _byName = <String, IconData>{
    // Category icons (seed set).
    'restaurant': LucideIcons.utensils,
    'shopping_basket': LucideIcons.shoppingCart,
    'directions_bus': LucideIcons.bus,
    'local_gas_station': LucideIcons.fuel,
    'receipt_long': LucideIcons.receipt,
    'home': LucideIcons.home,
    'shopping_bag': LucideIcons.shoppingBag,
    'favorite': LucideIcons.heart,
    'school': LucideIcons.graduationCap,
    'movie': LucideIcons.clapperboard,
    'subscriptions': LucideIcons.tv,
    'flight': LucideIcons.plane,
    'family_restroom': LucideIcons.baby,
    'volunteer_activism': LucideIcons.heartHandshake,
    'account_balance': LucideIcons.landmark,
    'spa': LucideIcons.flower,
    'card_giftcard': LucideIcons.gift,
    'category': LucideIcons.shapes,
    'payments': LucideIcons.banknote,
    'storefront': LucideIcons.store,
    'work': LucideIcons.briefcase,
    'trending_up': LucideIcons.trendingUp,
    'undo': LucideIcons.undo2,
    // Utility subcategory icons (#16).
    'bolt': LucideIcons.zap,
    'flame': LucideIcons.flame,
    'water_drop': LucideIcons.droplet,
    'wifi': LucideIcons.wifi,
    // Account icons.
    'wallet': LucideIcons.wallet,
    'credit_card': LucideIcons.creditCard,
    'savings': LucideIcons.piggyBank,
    'candlestick_chart': LucideIcons.candlestickChart,
    'phone_android': LucideIcons.smartphone,
    'more_horiz': LucideIcons.moreHorizontal,
  };

  static IconData resolve(String name) => _byName[name] ?? LucideIcons.shapes;

  /// Default icon name for a fresh account of [type].
  static String defaultForAccount(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'payments';
      case AccountType.bank:
        return 'account_balance';
      case AccountType.creditCard:
        return 'credit_card';
      case AccountType.wallet:
        return 'phone_android';
      case AccountType.savings:
        return 'savings';
      case AccountType.investment:
        return 'candlestick_chart';
      case AccountType.other:
        return 'more_horiz';
    }
  }

  /// The curated set offered in the account icon picker.
  static const accountPickerNames = <String>[
    'payments',
    'account_balance',
    'credit_card',
    'phone_android',
    'savings',
    'candlestick_chart',
    'wallet',
    'shopping_bag',
    'home',
    'more_horiz',
  ];

  /// The curated set offered in the category icon picker.
  static const categoryPickerNames = <String>[
    'restaurant',
    'shopping_basket',
    'directions_bus',
    'local_gas_station',
    'receipt_long',
    'home',
    'shopping_bag',
    'favorite',
    'school',
    'movie',
    'subscriptions',
    'flight',
    'family_restroom',
    'volunteer_activism',
    'account_balance',
    'spa',
    'card_giftcard',
    'payments',
    'storefront',
    'work',
    'trending_up',
    'bolt',
    'flame',
    'water_drop',
    'wifi',
    'phone_android',
    'category',
  ];
}
