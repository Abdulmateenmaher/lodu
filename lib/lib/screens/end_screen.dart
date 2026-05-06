import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/board_constants.dart';

import '../../logic/game_notifier.dart';
import '../theme/space_theme.dart';
import 'history_screen.dart';

class EndScreen extends StatelessWidget {
  const EndScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    final history = game.history;
    final last = history.isNotEmpty ? history.last : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF090E24), Color(0xFF1E103C)],
          )
        ),
        child: Stack(
          children: [
            SpaceTheme.backgroundStars(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 60),
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                        decoration: SpaceTheme.panelDecoration,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('LEVEL DONE', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: Color(0xFF4DBBFF), blurRadius: 10)])),
                            const SizedBox(height: 16),
                            if (last?.statusText.isNotEmpty == true)
                              Text(last!.statusText, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4ade80), fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            if (last != null) _WinnerPieces(record: last),
                            const SizedBox(height: 36),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildGlossyBtn(Icons.refresh, 'RESTART', () => context.read<GameNotifier>().resetToSetup(), isPurple: false),
                                _buildGlossyBtn(Icons.list, 'HISTORY', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())), isPurple: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (i) {
                            bool earned = last != null && i < last.stars;
                            return Padding(
                              padding: EdgeInsets.only(top: i == 1 ? 0 : 30, left: 5, right: 5),
                              child: Icon(
                                Icons.star_rounded, 
                                color: earned ? const Color(0xFFFFD700) : const Color(0xFF1E3A8A),
                                size: i == 1 ? 90 : 70,
                                shadows: earned ? const [Shadow(color: Color(0xFFFFA500), blurRadius: 20)] : null,
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlossyBtn(IconData icon, String label, VoidCallback onTap, {required bool isPurple}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: SpaceTheme.buttonDecoration(isPurple: isPurple),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
              ],
            ),
          ),
          SpaceTheme.glossyOverlay(140, 44, 16),
        ],
      ),
    );
  }
}

class _WinnerPieces extends StatelessWidget {
  final dynamic record;
  const _WinnerPieces({required this.record});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final color = kColors[i]!.main;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)],
          ),
        );
      }),
    );
  }
}
