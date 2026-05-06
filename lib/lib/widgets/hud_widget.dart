import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/board_constants.dart';
import '../../logic/game_notifier.dart';
import '../../widgets/dice_cell_widget.dart';
import '../../widgets/dice_widget.dart';
import '../theme/space_theme.dart';

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
        duration: const Duration(milliseconds: 400),
        builder: (context, color, child) {
          return Transform.rotate(
            angle: flipped ? pi : 0,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: SpaceTheme.panelDecoration.copyWith(
                    border: Border.all(color: color ?? targetColor, width: 3),
                    boxShadow: [
                      BoxShadow(color: (color ?? targetColor).withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)
                    ]
                  ),
                  child: child,
                ),
                SpaceTheme.glossyOverlay(120, 100, 18),
              ],
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (game.players.isNotEmpty) _PlayerLabel(game: game),
            _DiceRow(game: game),
            const SizedBox(height: 10),
            _ControlRow(game: game),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 6)]),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              shadows: [Shadow(color: color, blurRadius: 4)],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DiceRow extends StatelessWidget {
  final GameNotifier game;
  const _DiceRow({required this.game});

  @override
  Widget build(BuildContext context) {
    final isRolling = game.isRolling;
    final pool = game.dicePool;
    final selected = game.selectedDieIndex;

    if (isRolling) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [_RollingDie(), SizedBox(width: 8), _RollingDie()],
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
    _ctrl =
        AnimationController(
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

class _ControlRow extends StatelessWidget {
  final GameNotifier game;
  const _ControlRow({required this.game});

  @override
  Widget build(BuildContext context) {
    final actId = game.activePlayerId;
    final actPlayer = game.players[actId];

    if (actPlayer.isAI) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingCpuIcon(),
          const SizedBox(width: 6),
          const Text(
            'Thinking...',
            style: TextStyle(color: Color(0xFF4DBBFF), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    final active = game.canRoll && !game.isRolling;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: kColors[actId]!.main),
      duration: const Duration(milliseconds: 400),
      builder: (context, color, _) {
        final bg = color ?? kColors[actId]!.main;
        return GestureDetector(
          onTap: active ? game.rollDice : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: active ? 1.0 : 0.35,
         ),
        );
      },
    );
  }
}

class _PulsingCpuIcon extends StatefulWidget {
  @override
  State<_PulsingCpuIcon> createState() => _PulsingCpuIconState();
}

class _PulsingCpuIconState extends State<_PulsingCpuIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const Icon(Icons.memory, color: Color(0xFF4DBBFF), size: 18),
    );
  }
}
