import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A pill-shaped gradient button with a soft glow.
class GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double fontSize;
  final FontWeight fontWeight;
  final bool expand;
  final bool compact;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppTheme.primaryButton,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.radius = AppTheme.radiusLg,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w700,
    this.expand = false,
    this.compact = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppTheme.durFast,
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setHover(bool v) {
    if (!mounted) return;
    if (v) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final body = AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12 + 6 * t,
                offset: Offset(0, 4 + 4 * t),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : widget.padding,
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: widget.fontSize + 4),
              SizedBox(width: widget.compact ? 6 : 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          onTapDown: enabled ? (_) => _setHover(true) : null,
          onTapUp: enabled ? (_) => _setHover(false) : null,
          onTapCancel: enabled ? () => _setHover(false) : null,
          onTap: widget.onPressed,
          child: body,
        ),
      ),
    );
  }
}

/// Outlined version of [GradientButton] — used for secondary actions.
class OutlinedPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double fontSize;

  const OutlinedPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textMuted;
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1.0,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, size: fontSize + 2, color: c)
            : const SizedBox.shrink(),
        label: Text(
          label,
          style: TextStyle(
            color: c,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}
