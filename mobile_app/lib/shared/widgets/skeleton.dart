import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Placeholder block shaped like the content it stands in for. Pulses
/// gently to show work is happening; holds still under reduced motion.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, this.height = 14, this.radius = 6});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.55,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Skeleton for a list of one- or two-line rows (budgets, mappings).
class SkeletonRows extends StatelessWidget {
  final int count;
  final bool twoLine;
  final EdgeInsetsGeometry padding;

  const SkeletonRows({
    super.key,
    this.count = 4,
    this.twoLine = true,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.gutter),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Varying widths read as text, not as a grid.
                          FractionallySizedBox(
                            widthFactor: const [0.62, 0.48, 0.7, 0.55][i % 4],
                            child: const Skeleton(height: 14),
                          ),
                          if (twoLine) ...[
                            const SizedBox(height: Space.sm),
                            FractionallySizedBox(
                              widthFactor: const [0.34, 0.4, 0.28, 0.36][i % 4],
                              child: const Skeleton(height: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
