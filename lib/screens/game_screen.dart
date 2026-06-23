import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/game_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/board_widget.dart';
import '../widgets/common/animated_toast.dart';
import '../widgets/common/glowing_grid_background.dart';
import '../widgets/hud_widget.dart';

const _yardAlignments = [
  Alignment.bottomLeft,
  Alignment.topLeft,
  Alignment.topRight,
  Alignment.bottomRight,
];

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Glowing grid background
          const Positioned.fill(child: GlowingGridBackground()),
          SafeArea(
            child: Stack(
              children: [
                // Board
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight;
                      return SizedBox(
                        width: size,
                        height: size,
                        child: const BoardWidget(),
                      );
                    },
                  ),
                ),

                // Animated HUD overlay
                const _HudOverlay(),

                // Leave button
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LeaveButton(
                    onTap: () => _confirmLeave(context, game),
                  ),
                ),

                // Toast
                if (game.toast != null)
                  Positioned(
                    top: 52,
                    left: 0,
                    right: 0,
                    child: Center(child: AnimatedToast(message: game.toast!)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, GameNotifier game) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.exit_to_app_rounded,
                  color: AppTheme.accentRed,
                  size: 24,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Leave Match?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Current match progress will be lost.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        side: const BorderSide(color: AppTheme.border),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        game.leaveMatch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentRed,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        elevation: 6,
                        shadowColor:
                            AppTheme.accentRed.withValues(alpha: 0.5),
                      ),
                      child: const Text(
                        'Leave',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LeaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Leave Match',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.bgPanel.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.exit_to_app_rounded,
            color: AppTheme.accentRed,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    final actId = game.activePlayerId;
    final alignment = _yardAlignments[actId];
    return AnimatedAlign(
      duration: AppTheme.durSlow,
      curve: AppTheme.curveEmphasized,
      alignment: alignment,
      // FIX 5: Flip HUD for Green (1) and Yellow (2) — they're at the top of the board
      // so their HUD needs to be rotated 180° to face the center
      child: Padding(
        padding: _pad(alignment),
        child: HudWidget(flipped: actId == 1 || actId == 2),
      ),
    );
  }

  EdgeInsets _pad(Alignment a) {
    const p = 12.0;
    if (a == Alignment.topLeft) {
      return const EdgeInsets.only(top: p, left: p);
    }
    if (a == Alignment.topRight) {
      return const EdgeInsets.only(top: p, right: p);
    }
    if (a == Alignment.bottomLeft) {
      return const EdgeInsets.only(bottom: p, left: p);
    }
    return const EdgeInsets.only(bottom: p, right: p);
  }
}
