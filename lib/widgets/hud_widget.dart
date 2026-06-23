import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/board_constants.dart';
import '../logic/game_notifier.dart';
import '../theme/app_theme.dart';
import 'dice_widget.dart';
import 'dice_cell_widget.dart';

class HudWidget extends StatelessWidget {
  final bool flipped;
  const HudWidget({super.key, this.flipped = false});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    final actId = game.activePlayerId;
    final targetColor = kColors[actId]!.main;

    return GestureDetector(
      onTap: game.rollDice,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: targetColor),
        duration: AppTheme.durSlow,
        curve: AppTheme.curveEmphasized,
        builder: (context, color, child) {
          return Transform.rotate(
            angle: flipped ? pi : 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: (color ?? targetColor).withValues(alpha: 0.85),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (color ?? targetColor).withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // FIX 5: Only show player name label
            if (game.players.isNotEmpty) _PlayerLabel(game: game),
            _DiceRow(game: game),
          ],
        ),
      ),
    );
  }
}

// ── Player Label (FIX 5: Simplified - only name, no extras) ──

class _PlayerLabel extends StatelessWidget {
  final GameNotifier game;
  const _PlayerLabel({required this.game});

  @override
  Widget build(BuildContext context) {
    final actId = game.activePlayerId;
    final player = game.players[actId];
    final color = kColors[actId]!.main;
    final name = player.name.isEmpty
        ? (player.isAI ? 'Bot ${kColors[actId]!.name}' : kColors[actId]!.name)
        : player.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 6,
            ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Dice Row ───────────────────────────────────────────────────────

class _DiceRow extends StatelessWidget {
  final GameNotifier game;
  const _DiceRow({required this.game});

  @override
  Widget build(BuildContext context) {
    final isRolling = game.isRolling;
    final pool = game.dicePool;
    final selected = game.selectedDieIndex;

    if (isRolling) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RollingDie(),
          const SizedBox(width: 8),
          _RollingDie(),
        ],
      );
    }

    return DiceCellRow(
      diceValues: pool,
      selectedIndex: selected,
      onDieTap: (index) => game.handleDieClick(index),
      cellSize: 48,
    );
  }
}

// ── Rolling Die (cycles faces) ─────────────────────────────────────

class _RollingDie extends StatefulWidget {
  const _RollingDie();
  @override
  State<_RollingDie> createState() => _RollingDieState();
}

class _RollingDieState extends State<_RollingDie>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _val = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )
      ..addListener(() {
        if (_ctrl.value > 0.5) {
          final next = (_val % 6) + 1;
          if (next != _val) setState(() => _val = next);
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      DiceWidget(value: _val, isRolling: true, size: 48);
}