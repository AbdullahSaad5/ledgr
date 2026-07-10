import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';

/// The in-body screen header: title (optionally with the Ledgr logo mark) on
/// the left, `SoftIconButton`-style actions on the right. Screens use this
/// instead of a stock AppBar for a consistent, designed top edge.
class LedgrHeader extends StatelessWidget {
  const LedgrHeader({
    required this.title,
    this.showLogo = false,
    this.actions = const [],
    super.key,
  });

  final String title;
  final bool showLogo;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.lg, Gaps.md),
      child: Row(
        children: [
          if (showLogo) ...[
            const LedgrLogoMark(),
            const SizedBox(width: Gaps.md),
          ],
          Expanded(
            child: Text(
              title,
              // Kept in lockstep with appBarTheme.titleTextStyle so every
              // screen's header reads the same size.
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The brand mark (issue #2): deep-teal L with a tonal coin dot on a solid
/// mint field — identical to the launcher icon. Theme-invariant on purpose,
/// the way an app icon is.
class LedgrLogoMark extends StatelessWidget {
  const LedgrLogoMark({this.size = 34, super.key});

  final double size;

  static const _mint = Color(0xFF5BD9C8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: _mint,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size / 3),
        ),
      ),
      child: CustomPaint(
        size: Size.square(size),
        painter: const _MarkPainter(),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const _ink = Color(0xFF0B3B36);
  static const _coin = Color(0xFF338A7F);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 96;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13.5 * u
      ..strokeCap = StrokeCap.round;
    final l = Path()
      ..moveTo(35 * u, 22 * u)
      ..lineTo(35 * u, 57 * u)
      ..arcToPoint(
        Offset(46 * u, 68 * u),
        radius: Radius.circular(11 * u),
        clockwise: false,
      )
      ..lineTo(70 * u, 68 * u);
    canvas
      ..drawPath(l, stroke)
      ..drawCircle(Offset(53 * u, 48 * u), 7 * u, Paint()..color = _coin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
