import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/menu_sheet.dart';
import 'package:ledgr/features/categories/presentation/category_form_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CategoryList(kind: CategoryKind.expense),
            _CategoryList(kind: CategoryKind.income),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesByKindProvider(kind));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-category-$kind',
        onPressed: () => CategoryFormSheet.show(context, kind: kind),
        child: const Icon(LucideIcons.plus),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (categories) {
          // Children render nested under their parent (one level, #16).
          final parents = categories.where((c) => c.parentId == null).toList();
          final childrenOf = <int, List<Category>>{};
          for (final c in categories) {
            final p = c.parentId;
            if (p != null) childrenOf.putIfAbsent(p, () => []).add(c);
          }
          return ListView(
            // Clears the FAB (and system bar) so the last row stays readable.
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 88,
            ),
            children: [
              for (final parent in parents) ...[
                _categoryTile(context, ref, parent, categories),
                // Children hang off a parent-colored rail so the nesting
                // reads as structure, not stray indentation.
                if ((childrenOf[parent.id] ?? const <Category>[]).isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 35,
                      bottom: 6,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          start: BorderSide(
                            color: Color(
                              parent.color,
                            ).withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          for (final child in childrenOf[parent.id]!)
                            _childTile(context, ref, child, categories),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _categoryTile(
    BuildContext context,
    WidgetRef ref,
    Category c,
    List<Category> categories,
  ) {
    return ListTile(
      leading: IconBadge(
        icon: AppIcons.resolve(c.icon),
        color: Color(c.color),
        iconSize: 19,
      ),
      title: Text(c.name),
      trailing: IconButton(
        icon: const Icon(LucideIcons.moreVertical, size: 18),
        visualDensity: VisualDensity.compact,
        onPressed: () => MenuSheet.show(
          context,
          title: c.name,
          items: [
            MenuSheetItem(
              icon: LucideIcons.pencil,
              label: 'Edit',
              onTap: () =>
                  CategoryFormSheet.show(context, kind: kind, category: c),
            ),
            // One-level nesting: only top-level categories take children.
            MenuSheetItem(
              icon: LucideIcons.plus,
              label: 'Add subcategory',
              onTap: () => CategoryFormSheet.show(
                context,
                kind: kind,
                initialParentId: c.id,
              ),
            ),
            MenuSheetItem(
              icon: LucideIcons.trash2,
              label: 'Delete',
              onTap: () => _confirmDelete(context, ref, c, categories),
            ),
          ],
        ),
      ),
    );
  }

  /// A subcategory row: elbow glyph + smaller badge, hanging off the
  /// parent-colored rail drawn by the list above.
  Widget _childTile(
    BuildContext context,
    WidgetRef ref,
    Category c,
    List<Category> categories,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 16),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.cornerDownRight,
            size: 15,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          IconBadge(
            icon: AppIcons.resolve(c.icon),
            color: Color(c.color),
            size: 32,
            iconSize: 15,
          ),
        ],
      ),
      title: Text(c.name),
      trailing: IconButton(
        icon: const Icon(LucideIcons.moreVertical, size: 18),
        visualDensity: VisualDensity.compact,
        onPressed: () => MenuSheet.show(
          context,
          title: c.name,
          items: [
            MenuSheetItem(
              icon: LucideIcons.pencil,
              label: 'Edit',
              onTap: () =>
                  CategoryFormSheet.show(context, kind: kind, category: c),
            ),
            MenuSheetItem(
              icon: LucideIcons.trash2,
              label: 'Delete',
              onTap: () => _confirmDelete(context, ref, c, categories),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
    List<Category> siblings,
  ) async {
    final repo = ref.read(categoryRepositoryProvider);
    final count = await repo.transactionCount(category.id);
    if (!context.mounted) return;

    final childCount = siblings.where((c) => c.parentId == category.id).length;

    if (count == 0) {
      // Nothing to merge, but deleting is still destructive enough for a
      // confirmation — especially for a parent whose children get promoted.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete ${category.name}?'),
          content: Text(
            childCount == 0
                ? 'No transactions use this category.'
                : 'Its $childCount subcategor${childCount == 1 ? 'y' : 'ies'} '
                      'will become top-level categories.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed ?? false) await repo.mergeAndDelete(category.id);
      return;
    }

    final others = siblings.where((c) => c.id != category.id).toList();
    final target = await showDialog<int>(
      context: context,
      builder: (_) => _MergeDialog(
        count: count,
        category: category,
        options: others,
        childCount: childCount,
      ),
    );
    if (target != null) {
      await repo.mergeAndDelete(category.id, toId: target);
    }
  }
}

class _MergeDialog extends StatelessWidget {
  const _MergeDialog({
    required this.count,
    required this.category,
    required this.options,
    required this.childCount,
  });

  final int count;
  final Category category;
  final List<Category> options;
  final int childCount;

  @override
  Widget build(BuildContext context) {
    // Include the category being deleted: its own children appear as merge
    // targets and still label with its name.
    final byId = {for (final c in options) c.id: c, category.id: category};
    // Children read as "Parent > Child" so two same-named children under
    // different parents stay distinguishable.
    String label(Category c) => c.parentId == null
        ? c.name
        : '${byId[c.parentId]?.name ?? '?'} > ${c.name}';

    return AlertDialog(
      title: Text('Delete ${category.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count transaction(s) use this category'
            '${childCount > 0 ? ' or its subcategories' : ''}. '
            '${childCount > 0 ? 'Subcategories become top-level. ' : ''}'
            'Move the transactions to:',
          ),
          const SizedBox(height: 8),
          // Scrolls: the full category list is taller than small screens.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in options)
                    ListTile(
                      dense: true,
                      leading: IconBadge(
                        icon: AppIcons.resolve(c.icon),
                        color: Color(c.color),
                        size: 34,
                        iconSize: 16,
                      ),
                      title: Text(label(c)),
                      onTap: () => Navigator.of(context).pop(c.id),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
