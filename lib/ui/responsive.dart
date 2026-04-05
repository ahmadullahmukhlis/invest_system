import 'package:flutter/material.dart';

class Responsive {
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 720;
  }

  static double maxContentWidth(BuildContext context) {
    return isTablet(context) ? 720 : double.infinity;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return isTablet(context)
        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
        : const EdgeInsets.all(16);
  }

  static Widget centered(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth(context)),
        child: child,
      ),
    );
  }
}
