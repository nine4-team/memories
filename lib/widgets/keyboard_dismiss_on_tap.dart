import 'package:flutter/material.dart';

/// Dismisses the soft keyboard whenever the user taps anywhere outside
/// of a focused input element.
class KeyboardDismissOnTap extends StatelessWidget {
  const KeyboardDismissOnTap({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
