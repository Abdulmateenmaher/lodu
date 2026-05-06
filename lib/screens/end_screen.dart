import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/board_constants.dart';
import '../logic/game_notifier.dart';
import 'history_screen.dart';

class EndScreen extends StatelessWidget {
  const EndScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    final history = game.history;
    final last = history.isNotEmpty ? history.last : null;
    final winnerLabel = last?.winnerLabel ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0a0f1e),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _BouncingTrophy(),
              const SizedBox(height: 20),
              
              if (last != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Icon(
                    Icons.star_rounded, 
                    color: i < last.stars ? Colors.amber : Colors.grey.shade800,
                    size: 40,
                  )),
                ),

              const SizedBox(height: 10),
              const Text('Victory!',
                  style: TextStyle(color: Colors.white, fontSize: 44,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 10),
              
              if (last?.statusText.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(last!.statusText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF4ade80),
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 16),

              if (last != null) _WinnerPieces(record: last),
              const SizedBox(height: 36),
              
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.read<GameNotifier>().resetToSetup(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('New Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: const StadiumBorder(),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e293b), foregroundColor: const Color(0xFF94a3b8),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: const StadiumBorder(),
                      side: const BorderSide(color: Color(0xFF334155)),
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
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)],
          ),
        );
      }),
    );
  }
}

class _BouncingTrophy extends StatefulWidget {
  const _BouncingTrophy();
  @override State<_BouncingTrophy> createState() => _BouncingTrophyState();
}

class _BouncingTrophyState extends State<_BouncingTrophy> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _anim;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true); _anim = Tween<double>(begin: 0, end: -16).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _anim, builder: (_, __) => Transform.translate(offset: Offset(0, _anim.value), child: const Icon(Icons.emoji_events, color: Color(0xFFfacc15), size: 80))); }
}