import 'package:flutter/material.dart';

class RefreshWrapper extends StatelessWidget {
  const RefreshWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: child,
    );
  }
}
