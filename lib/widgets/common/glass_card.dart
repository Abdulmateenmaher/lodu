import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A frosted-glass panel used for HUDs, lobby cards, and dialog bodies.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final double blur;
  final Color? tint;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.gap16),
    this.radius = AppTheme.radiusLg,
    this.borderColor,
    this.borderWidth = 1,
    this.blur = 18,
    this.tint,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppTheme.bgPanel;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppTheme.border,
          width: borderWidth,
        ),
        boxShadow: shadows ??
            const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
      ),
      child: child,
    );
  }
}
