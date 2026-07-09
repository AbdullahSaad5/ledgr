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

/// Create or edit a category, as a full screen.
class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({required this.kind, this.category, super.key});

  final CategoryKind kind;
  final Category? category;

  static Future<void> show(
    BuildContext context, {
    required CategoryKind kind,
    Category? category,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CategoryFormSheet(kind: kind, category: category),
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
      );
    } else {
      await repo.create(
        name: name,
        kind: widget.kind,
        icon: _icon,
        color: _color,
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
                    for (final name in AppIcons.categoryPickerNames)
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
