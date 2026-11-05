import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A tappable surface that answers the finger: it shrinks slightly while
/// pressed (none under reduced motion), on top of the ripple. Without
/// [onTap] it's just its child.
class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Widget child;

  const Pressable({super.key, required this.onTap, this.borderRadius, required this.child});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return InkWell(
      onTap: widget.onTap,
      borderRadius: widget.borderRadius,
      onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? Motion.pressScale : 1,
        duration: reduceMotion ? Duration.zero : Motion.press,
        curve: Motion.easeOut,
        child: widget.child,
      ),
    );
  }
}
