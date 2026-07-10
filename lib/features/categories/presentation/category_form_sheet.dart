import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/color_swatches.dart';
import 'package:ledgr/core/widgets/group_card.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/icon_browse_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Create or edit a category, as a full screen.
class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({
    required this.kind,
    this.category,
    this.initialParentId,
    super.key,
  });

  final CategoryKind kind;
  final Category? category;

  /// Pre-selected parent for the "Add subcategory" entry point (#16).
  final int? initialParentId;

  static Future<void> show(
    BuildContext context, {
    required CategoryKind kind,
    Category? category,
    int? initialParentId,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CategoryFormSheet(
          kind: kind,
          category: category,
          initialParentId: initialParentId,
        ),
      ),
    );
  }

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late String _icon =
      widget.category?.icon ?? AppIcons.categoryPickerNames.first;
  late int _color = widget.category?.color ?? AppColors.swatches.first;
  late int? _parentId = widget.category?.parentId ?? widget.initialParentId;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(categoryRepositoryProvider);
    if (_isEditing) {
      await repo.update(
        widget.category!.id,
        name: name,
        icon: _icon,
        color: _color,
        parentId: _parentId,
      );
    } else {
      await repo.create(
        name: name,
        kind: widget.kind,
        icon: _icon,
        color: _color,
        parentId: _parentId,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(_color);

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(_isEditing ? 'Edit category' : 'New category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xs, Gaps.page, 24),
        children: [
          GroupCard(
            title: 'Name',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gaps.lg),
                child: Row(
                  children: [
                    IconBadge(
                      icon: AppIcons.resolve(_icon),
                      color: accent,
                      iconSize: 19,
                    ),
                    const SizedBox(width: Gaps.md),
                    Expanded(
                      child: TextField(
                        controller: _name,
                        autofocus: !_isEditing,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _ParentCard(
            kind: widget.kind,
            editingId: widget.category?.id,
            parentId: _parentId,
            onChanged: (id) => setState(() => _parentId = id),
          ),
          GroupCard(
            title: 'Icon',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gaps.md),
                child: GridView.count(
                  crossAxisCount: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Gaps.sm,
                  crossAxisSpacing: Gaps.sm,
                  children: [
                    // A picked browse-all icon joins the curated grid so the
                    // selection is never invisible.
                    for (final name in {
                      _icon,
                      ...AppIcons.categoryPickerNames,
                    })
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _icon = name),
                        child: IconBadge(
                          icon: AppIcons.resolve(name),
                          size: 44,
                          iconSize: 19,
                          background: _icon == name
                              ? accent.withValues(alpha: 0.22)
                              : scheme.surfaceContainer,
                          color: _icon == name
                              ? accent
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(LucideIcons.layoutGrid, size: 18, color: accent),
                title: Text(
                  'Browse all icons',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
                  final picked = await IconBrowseSheet.show(
                    context,
                    selected: _icon,
                    accent: accent,
                  );
                  if (picked != null) setState(() => _icon = picked);
                },
              ),
            ],
          ),
          GroupCard(
            title: 'Color',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gaps.lg),
                child: ColorSwatchPicker(
                  selected: _color,
                  onSelected: (c) => setState(() => _color = c),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          Gaps.page,
          Gaps.sm,
          Gaps.page,
          Gaps.md,
        ),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _save,
            child: Text(_isEditing ? 'Save' : 'Create'),
          ),
        ),
      ),
    );
  }
}

/// Optional parent selection (#16). Hidden while the category being edited
/// has children of its own — nesting is one level, so a parent can't become
/// a child until its children are moved out.
class _ParentCard extends ConsumerWidget {
  const _ParentCard({
    required this.kind,
    required this.editingId,
    required this.parentId,
    required this.onChanged,
  });

  final CategoryKind kind;
  final int? editingId;
  final int? parentId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesByKindProvider(kind)).valueOrNull ?? const [];
    final hasChildren =
        editingId != null && categories.any((c) => c.parentId == editingId);
    if (hasChildren) return const SizedBox.shrink();

    final options = categories
        .where((c) => c.parentId == null && c.id != editingId)
        .toList();
    if (options.isEmpty) return const SizedBox.shrink();

    final matches = options.where((c) => c.id == parentId);
    final selected = matches.isEmpty ? null : matches.first;

    return GroupCard(
      title: 'Parent category',
      children: [
        ListTile(
          leading: selected == null
              ? const Icon(LucideIcons.folderTree, size: 20)
              : IconBadge(
                  icon: AppIcons.resolve(selected.icon),
                  color: Color(selected.color),
                  size: 34,
                  iconSize: 16,
                ),
          title: Text(selected?.name ?? 'None (top-level)'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () async {
            final picked = await showModalBottomSheet<(int?,)>(
              context: context,
              useRootNavigator: true,
              builder: (sheetContext) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.folderTree, size: 20),
                      title: const Text('None (top-level)'),
                      onTap: () => Navigator.of(sheetContext).pop((null,)),
                    ),
                    for (final c in options)
                      ListTile(
                        leading: IconBadge(
                          icon: AppIcons.resolve(c.icon),
                          color: Color(c.color),
                          size: 34,
                          iconSize: 16,
                        ),
                        title: Text(c.name),
                        onTap: () => Navigator.of(sheetContext).pop((c.id,)),
                      ),
                  ],
                ),
              ),
            );
            if (picked != null) onChanged(picked.$1);
          },
        ),
      ],
    );
  }
}
