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
        data: (categories) => ListView(
          children: [
            for (final c in categories)
              ListTile(
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
                        onTap: () => CategoryFormSheet.show(
                          context,
                          kind: kind,
                          category: c,
                        ),
                      ),
                      MenuSheetItem(
                        icon: LucideIcons.trash2,
                        label: 'Delete',
                        onTap: () =>
                            _confirmDelete(context, ref, c, categories),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
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

    if (count == 0) {
      await repo.mergeAndDelete(category.id);
      return;
    }

    final others = siblings.where((c) => c.id != category.id).toList();
    final target = await showDialog<int>(
      context: context,
      builder: (_) =>
          _MergeDialog(count: count, category: category, options: others),
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
  });

  final int count;
  final Category category;
  final List<Category> options;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete ${category.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count transaction(s) use this category. Move them to:'),
          const SizedBox(height: 8),
          for (final c in options)
            ListTile(
              dense: true,
              leading: IconBadge(
                icon: AppIcons.resolve(c.icon),
                color: Color(c.color),
                size: 34,
                iconSize: 16,
              ),
              title: Text(c.name),
              onTap: () => Navigator.of(context).pop(c.id),
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
