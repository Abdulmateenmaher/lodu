import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/board_constants.dart';
import '../logic/game_notifier.dart';
import '../models/match_record.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/confetti.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/gradient_button.dart';
import 'history_screen.dart';

class EndScreen extends StatelessWidget {
  const EndScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    final history = game.history;
    final last = history.isNotEmpty ? history.last : null;
    final winnerIndex = _winnerIndexFrom(last);
    final winnerColor = winnerIndex >= 0
        ? kColors[winnerIndex]!.main
        : AppTheme.accentYellow;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          // Confetti background
          const Positioned.fill(child: ConfettiOverlay()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const _BouncingTrophy(),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (b) => LinearGradient(
                      colors: [winnerColor, Colors.white],
                    ).createShader(b),
                    child: Text(
                      last?.winnerLabel ?? 'Victory!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (last != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        return Icon(
                          Icons.star_rounded,
                          color: i < last.stars
                              ? AppTheme.accentYellow
                              : AppTheme.borderStrong,
                          size: 28,
                          shadows: i < last.stars
                              ? [
                                  Shadow(
                                    color: AppTheme.accentYellow
                                        .withValues(alpha: 0.6),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        );
                      }),
                    ),
                  const SizedBox(height: 20),
                  if (last != null)
                    Expanded(
                      child: _MatchSummary(record: last),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      GradientButton(
                        label: 'New Match',
                        icon: Icons.refresh_rounded,
                        onPressed: () {
                          Haptics.medium();
                          context.read<GameNotifier>().resetToSetup();
                        },
                      ),
                      OutlinedPillButton(
                        label: 'History',
                        icon: Icons.history_rounded,
                        color: AppTheme.textMuted,
                        onPressed: () {
                          Haptics.light();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _winnerIndexFrom(MatchRecord? record) {
    if (record == null) return -1;
    if (record.winnerLabel.contains('+')) {
      // team play — pick the first named player's color
      final first = record.winnerLabel.split('+').first.trim();
      final idx = record.playerNames.indexOf(first);
      return idx;
    }
    final idx = record.playerNames.indexOf(record.winnerLabel.trim());
    return idx;
  }
}

class _MatchSummary extends StatelessWidget {
  final MatchRecord record;
  const _MatchSummary({required this.record});

  @override
  Widget build(BuildContext context) {
    final winners = record.winnerLabel.split('+').map((e) => e.trim()).toList();
    final losers = _losers();
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(text: 'WINNERS'),
            const SizedBox(height: 8),
            ...winners.map((name) {
              final idx = record.playerNames.indexOf(name);
              if (idx == -1) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PlayerRow(
                  name: name,
                  color: kColors[idx]!.main,
                  isAI: record.playerIsAI[idx],
                  isWinner: true,
                ),
              );
            }),
            const SizedBox(height: 16),
            if (losers.isNotEmpty) ...[
              const _SectionLabel(text: 'DEFEATED'),
              const SizedBox(height: 8),
              ...losers.map((name) {
                final idx = record.playerNames.indexOf(name);
                if (idx == -1) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PlayerRow(
                    name: name,
                    color: kColors[idx]!.main,
                    isAI: record.playerIsAI[idx],
                  ),
                );
              }),
            ] else ...[
              const _SectionLabel(text: 'SOLO VICTORY'),
              const SizedBox(height: 6),
              Text(
                'All four pieces home — no one else made it.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _losers() {
    if (record.statusText.startsWith('Defeated: ')) {
      return record.statusText.substring(10).split(', ');
    }
    return [];
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final String name;
  final Color color;
  final bool isAI;
  final bool isWinner;
  const _PlayerRow({
    required this.name,
    required this.color,
    required this.isAI,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner
              ? color.withValues(alpha: 0.7)
              : AppTheme.border,
          width: isWinner ? 1.5 : 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isWinner
              ? [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ]
              : [
                  AppTheme.bgPanel,
                  AppTheme.bgPanelAlt,
                ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isWinner
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isAI ? Icons.memory : Icons.person,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isWinner ? Colors.white : AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isWinner
                  ? color.withValues(alpha: 0.25)
                  : AppTheme.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              isWinner ? 'WON' : 'OUT',
              style: TextStyle(
                color: isWinner ? color : AppTheme.accentRed,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingTrophy extends StatefulWidget {
  const _BouncingTrophy();
  @override
  State<_BouncingTrophy> createState() => _BouncingTrophyState();
}

class _BouncingTrophyState extends State<_BouncingTrophy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _anim =
      Tween<double>(begin: 0, end: -18).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: child,
      ),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.trophyGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentYellow.withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.emoji_events_rounded,
          color: Colors.white,
          size: 56,
        ),
      ),
    );
  }
}
