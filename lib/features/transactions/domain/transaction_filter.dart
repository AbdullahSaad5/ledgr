import 'package:ledgr/core/db/enums.dart';

/// A set of criteria for searching transactions. All fields are ANDed; a set
/// field matches any of its members.
class TransactionFilter {
  const TransactionFilter({
    this.text,
    this.accountIds = const {},
    this.categoryIds = const {},
    this.types = const {},
    this.tagIds = const {},
    this.from,
    this.to,
    this.minMinor,
    this.maxMinor,
  });

  final String? text;
  final Set<int> accountIds;
  final Set<int> categoryIds;
  final Set<TxType> types;
  final Set<int> tagIds;
  final DateTime? from;
  final DateTime? to;
  final int? minMinor;
  final int? maxMinor;

  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) &&
      accountIds.isEmpty &&
      categoryIds.isEmpty &&
      types.isEmpty &&
      tagIds.isEmpty &&
      from == null &&
      to == null &&
      minMinor == null &&
      maxMinor == null;

  int get activeCount => [
    text != null && text!.trim().isNotEmpty,
    accountIds.isNotEmpty,
    categoryIds.isNotEmpty,
    types.isNotEmpty,
    tagIds.isNotEmpty,
    from != null || to != null,
    minMinor != null || maxMinor != null,
  ].where((e) => e).length;

  TransactionFilter copyWith({
    String? text,
    Set<int>? accountIds,
    Set<int>? categoryIds,
    Set<TxType>? types,
    Set<int>? tagIds,
    DateTime? from,
    DateTime? to,
    int? minMinor,
    int? maxMinor,
    bool clearDates = false,
    bool clearAmounts = false,
  }) {
    return TransactionFilter(
      text: text ?? this.text,
      accountIds: accountIds ?? this.accountIds,
      categoryIds: categoryIds ?? this.categoryIds,
      types: types ?? this.types,
      tagIds: tagIds ?? this.tagIds,
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
      minMinor: clearAmounts ? null : (minMinor ?? this.minMinor),
      maxMinor: clearAmounts ? null : (maxMinor ?? this.maxMinor),
    );
  }
}
