import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One entry in a [MenuSheet].
class MenuSheetItem {
  const MenuSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

/// The app's standard action menu: a bottom sheet of icon-badged rows.
/// Replaces stock popup menus so menus share the sheet shape language.
class MenuSheet extends StatelessWidget {
  const MenuSheet({required this.items, this.title, super.key});

  final List<MenuSheetItem> items;
  final String? title;

  static Future<void> show(
    BuildContext context, {
    required List<MenuSheetItem> items,
    String? title,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => MenuSheet(items: items, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, 4),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          for (final item in items)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Gaps.page,
                vertical: 2,
              ),
              leading: IconBadge(
                icon: item.icon,
                color: scheme.primary,
                size: 40,
                iconSize: 19,
                background: scheme.surfaceContainerHigh,
              ),
              title: Text(item.label),
              subtitle: item.subtitle == null ? null : Text(item.subtitle!),
              trailing: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              onTap: () {
                Navigator.of(context).pop();
                item.onTap();
              },
            ),
          const SizedBox(height: Gaps.sm),
        ],
      ),
    );
  }
}
