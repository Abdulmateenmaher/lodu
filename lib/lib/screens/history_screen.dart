import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/board_constants.dart';
import '../../logic/game_notifier.dart';
import '../../models/match_record.dart';
import '../theme/space_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<GameNotifier>().history;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SpaceTheme.bgDark,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 24),
            SizedBox(width: 8),
            Text('MATCH HISTORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
          ],
        ),
        elevation: 0,
      ),
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
            history.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, color: Color(0xFF4DBBFF), size: 64),
                      SizedBox(height: 16),
                      Text('No matches played yet.', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final record = history[history.length - 1 - index];
                    return _MatchCard(record: record, matchNumber: history.length - index);
                  },
                ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchRecord record;
  final int matchNumber;
  const _MatchCard({required this.record, required this.matchNumber});

  @override
  Widget build(BuildContext context) {
    final now = record.playedAt;
    final timeStr = '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF4DBBFF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF4DBBFF).withValues(alpha: 0.5))),
                child: Text('MATCH #$matchNumber', style: const TextStyle(color: Color(0xFF4DBBFF), fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => Icon(
                  Icons.star,
                  size: 16,
                  color: i < record.stars ? const Color(0xFFFFD700) : Colors.white24,
                )),
              ),
              const SizedBox(width: 12),
              Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(record.statusText, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(record.playerNames.length, (i) {
              final color = kColors[i]!.main;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 4)])),
                    const SizedBox(width: 6),
                    Text(record.playerNames[i], style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    if (record.playerIsAI[i]) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.memory, color: color.withValues(alpha: 0.9), size: 12),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
