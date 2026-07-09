import 'package:flutter/material.dart';
import 'package:ledgr/core/db/enums.dart';

/// Resolves the icon-name strings stored on categories/accounts to concrete
/// [IconData]. A registry (not dynamic lookup) so icons stay tree-shakeable.
abstract final class AppIcons {
  static const _byName = <String, IconData>{
    // Category icons (seed set).
    'restaurant': Icons.restaurant,
    'shopping_basket': Icons.shopping_basket,
    'directions_bus': Icons.directions_bus,
    'local_gas_station': Icons.local_gas_station,
    'receipt_long': Icons.receipt_long,
    'home': Icons.home,
    'shopping_bag': Icons.shopping_bag,
    'favorite': Icons.favorite,
    'school': Icons.school,
    'movie': Icons.movie,
    'subscriptions': Icons.subscriptions,
    'flight': Icons.flight,
    'family_restroom': Icons.family_restroom,
    'volunteer_activism': Icons.volunteer_activism,
    'account_balance': Icons.account_balance,
    'spa': Icons.spa,
    'card_giftcard': Icons.card_giftcard,
    'category': Icons.category,
    'payments': Icons.payments,
    'storefront': Icons.storefront,
    'work': Icons.work,
    'trending_up': Icons.trending_up,
    'undo': Icons.undo,
    // Account icons.
    'wallet': Icons.account_balance_wallet,
    'credit_card': Icons.credit_card,
    'savings': Icons.savings,
    'candlestick_chart': Icons.candlestick_chart,
    'phone_android': Icons.phone_android,
    'more_horiz': Icons.more_horiz,
  };

  static IconData resolve(String name) => _byName[name] ?? Icons.category;

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
}
