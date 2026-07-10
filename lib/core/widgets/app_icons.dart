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
    // Extended browse set — food & drink.
    'coffee': LucideIcons.coffee,
    'pizza': LucideIcons.pizza,
    'cake': LucideIcons.cakeSlice,
    'apple': LucideIcons.apple,
    'salad': LucideIcons.salad,
    'soup': LucideIcons.soup,
    'ice_cream': LucideIcons.iceCreamCone,
    'cup_soda': LucideIcons.cupSoda,
    'wine': LucideIcons.wine,
    'utensils_crossed': LucideIcons.utensilsCrossed,
    // Transport & travel.
    'car': LucideIcons.car,
    'bike': LucideIcons.bike,
    'train': LucideIcons.trainFront,
    'ship': LucideIcons.ship,
    'map': LucideIcons.map,
    'map_pin': LucideIcons.mapPin,
    'luggage': LucideIcons.luggage,
    'tent': LucideIcons.tent,
    'mountain': LucideIcons.mountain,
    'palmtree': LucideIcons.palmtree,
    // Tech & media.
    'laptop': LucideIcons.laptop,
    'monitor': LucideIcons.monitor,
    'headphones': LucideIcons.headphones,
    'camera': LucideIcons.camera,
    'music': LucideIcons.music,
    'film': LucideIcons.film,
    'gamepad': LucideIcons.gamepad2,
    'printer': LucideIcons.printer,
    // Learning & work.
    'book': LucideIcons.book,
    'book_open': LucideIcons.bookOpen,
    'newspaper': LucideIcons.newspaper,
    'pencil': LucideIcons.pencil,
    'palette': LucideIcons.palette,
    'presentation': LucideIcons.presentation,
    // Style & self.
    'scissors': LucideIcons.scissors,
    'shirt': LucideIcons.shirt,
    'watch': LucideIcons.watch,
    'gem': LucideIcons.gem,
    'glasses': LucideIcons.glasses,
    // Health & fitness.
    'dumbbell': LucideIcons.dumbbell,
    'heart_pulse': LucideIcons.heartPulse,
    'pill': LucideIcons.pill,
    'stethoscope': LucideIcons.stethoscope,
    'syringe': LucideIcons.syringe,
    // Pets & people.
    'dog': LucideIcons.dog,
    'cat': LucideIcons.cat,
    'paw_print': LucideIcons.pawPrint,
    'users': LucideIcons.users,
    'user': LucideIcons.user,
    // Places.
    'building': LucideIcons.building,
    'building2': LucideIcons.building2,
    'factory': LucideIcons.factory,
    'hotel': LucideIcons.hotel,
    'church': LucideIcons.church,
    // Money & numbers.
    'coins': LucideIcons.coins,
    'trending_down': LucideIcons.trendingDown,
    'percent': LucideIcons.percent,
    'calculator': LucideIcons.calculator,
    'receipt': LucideIcons.receiptText,
    'hand_coins': LucideIcons.handCoins,
    // Tools & home.
    'hammer': LucideIcons.hammer,
    'wrench': LucideIcons.wrench,
    'paint_roller': LucideIcons.paintRoller,
    'sofa': LucideIcons.sofa,
    'bed': LucideIcons.bed,
    'lamp': LucideIcons.lamp,
    'washing_machine': LucideIcons.washingMachine,
    // Nature & misc.
    'leaf': LucideIcons.leaf,
    'sprout': LucideIcons.sprout,
    'sun': LucideIcons.sun,
    'moon': LucideIcons.moon,
    'cloud': LucideIcons.cloud,
    'umbrella': LucideIcons.umbrella,
    'recycle': LucideIcons.recycle,
    'shield': LucideIcons.shield,
    'lock': LucideIcons.lock,
    'key': LucideIcons.key,
    'phone': LucideIcons.phone,
    'mail': LucideIcons.mail,
    'globe': LucideIcons.globe,
    'star': LucideIcons.star,
    'sparkles': LucideIcons.sparkles,
    'party_popper': LucideIcons.partyPopper,
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

  /// Every icon offered in the "browse all" picker, grouped roughly by theme.
  /// Everything in the registry except account-shape icons.
  static List<String> get allPickerNames => _byName.keys
      .where((n) => !{'more_horiz', 'candlestick_chart'}.contains(n))
      .toList();

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
