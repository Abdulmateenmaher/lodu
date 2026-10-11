import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';

/// A circular avatar with the player's color, optional icon, and an optional
/// "AI" or "you" badge. Used in the setup screen, lobby, and HUD.
class PlayerAvatar extends StatelessWidget {
  final Color color;
  final String? label;
  final double size;
  final bool isAI;
  final bool isYou;
  final bool isActive;
  final IconData? icon;

  const PlayerAvatar({
    super.key,
    required this.color,
    this.label,
    this.size = 36,
    this.isAI = false,
    this.isYou = false,
    this.isActive = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dim = isActive ? 1.0 : 0.4;
    return Opacity(
      opacity: dim,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.95),
                    color,
                    color.withValues(alpha: 0.8),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: isAI
                    ? FaIcon(
                        FontAwesomeIcons.robot,
                        color: Colors.white,
                        size: size * 0.55,
                      )
                    : Icon(
                        Icons.person,
                        color: Colors.white,
                        size: size * 0.55,
                      ),
              ),
            ),
            if (isYou)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size * 0.12,
                    vertical: size * 0.04,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.bgPanel, width: 1),
                  ),
                  child: Text(
                    'YOU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
