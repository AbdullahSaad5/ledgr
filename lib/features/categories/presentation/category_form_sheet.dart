import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/color_swatches.dart';

/// Create or edit a category.
class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({required this.kind, this.category, super.key});

  final CategoryKind kind;
  final Category? category;

  static Future<void> show(
    BuildContext context, {
    required CategoryKind kind,
    Category? category,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryFormSheet(kind: kind, category: category),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit category' : 'New category',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: !_isEditing,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: GridView.count(
              crossAxisCount: 6,
              children: [
                for (final name in AppIcons.categoryPickerNames)
                  IconButton(
                    onPressed: () => setState(() => _icon = name),
                    icon: Icon(AppIcons.resolve(name)),
                    isSelected: _icon == name,
                    style: IconButton.styleFrom(
                      backgroundColor: _icon == name
                          ? Color(_color).withValues(alpha: 0.2)
                          : null,
                      foregroundColor: _icon == name ? Color(_color) : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ColorSwatchPicker(
            selected: _color,
            onSelected: (c) => setState(() => _color = c),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(_isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}
