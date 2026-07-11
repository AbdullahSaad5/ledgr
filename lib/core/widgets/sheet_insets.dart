import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ledgr/app/theme/app_theme.dart';

/// Bottom padding for a modal bottom sheet's content.
///
/// Modal sheet routes only guard the top inset, so each sheet must clear the
/// system navigation area itself (48dp on 3-button navigation). This is the
/// keyboard inset plus a floor of either [min] or the system bar + breathing
/// room, whichever is larger — so the last row stays tappable with the
/// keyboard both up and down.
double sheetBottomInset(BuildContext context, {double min = Gaps.lg}) =>
    MediaQuery.viewInsetsOf(context).bottom +
    math.max(min, MediaQuery.viewPaddingOf(context).bottom + Gaps.sm);
