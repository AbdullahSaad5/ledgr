import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/sheet_insets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Full icon catalog with search, for category/account customization (#16
/// follow-up: the curated grid was too small). Returns the picked icon name.
class IconBrowseSheet extends StatefulWidget {
  const IconBrowseSheet({
    required this.selected,
    required this.accent,
    super.key,
  });

  final String selected;
  final Color accent;

  static Future<String?> show(
    BuildContext context, {
    required String selected,
    required Color accent,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        // Keeps the grid above the keyboard while searching, and above the
        // system bar (3-button nav) when the keyboard is down.
        padding: EdgeInsets.only(bottom: sheetBottomInset(sheetContext)),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: IconBrowseSheet(selected: selected, accent: accent),
        ),
      ),
    );
  }

  @override
  State<IconBrowseSheet> createState() => _IconBrowseSheetState();
}

class _IconBrowseSheetState extends State<IconBrowseSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final q = _query.text.trim().toLowerCase();
    final names = AppIcons.allPickerNames
        .where((n) => q.isEmpty || n.replaceAll('_', ' ').contains(q))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, Gaps.sm),
          child: Text('All icons', style: text.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
          child: TextField(
            controller: _query,
            autofocus: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search icons',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _query.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: Gaps.md),
        Expanded(
          child: names.isEmpty
              ? Center(
                  child: Text(
                    'No icons match "$q"',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : GridView.count(
                  crossAxisCount: 6,
                  padding: const EdgeInsets.fromLTRB(
                    Gaps.xl,
                    0,
                    Gaps.xl,
                    Gaps.xl,
                  ),
                  mainAxisSpacing: Gaps.sm,
                  crossAxisSpacing: Gaps.sm,
                  children: [
                    for (final name in names)
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).pop(name),
                        child: IconBadge(
                          icon: AppIcons.resolve(name),
                          size: 44,
                          iconSize: 19,
                          background: widget.selected == name
                              ? widget.accent.withValues(alpha: 0.22)
                              : scheme.surfaceContainer,
                          color: widget.selected == name
                              ? widget.accent
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
