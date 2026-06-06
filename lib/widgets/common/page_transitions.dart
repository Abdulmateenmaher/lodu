import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shared axis-style page transition — slides in from the right with a soft
/// fade and slight scale. Used as a global page route.
class FadeThroughPageRoute<T> extends PageRouteBuilder<T> {
  FadeThroughPageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: AppTheme.durMed,
          reverseTransitionDuration: AppTheme.durFast,
          pageBuilder: (context, anim, secondary) => builder(context),
          transitionsBuilder: (context, anim, secondary, child) {
            final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: t,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(t),
                child: child,
              ),
            );
          },
        );
}
