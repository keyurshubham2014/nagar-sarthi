import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// App-wide scrolling without Android's stretch overscroll (adapted from
/// Saarthee): lists, pages and sheets stop cleanly at their edges. Every
/// scrollable under MaterialApp inherits it. Pull-to-refresh still works (it
/// listens to overscroll notifications). Mouse and trackpad can drag on web.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();

  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse, PointerDeviceKind.trackpad};
}
