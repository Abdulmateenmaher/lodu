import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/board_constants.dart';
import '../logic/game_notifier.dart';
import '../models/match_record.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<GameNotifier>().history;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0f1e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Color(0xFFfacc15), size: 20),
            SizedBox(width: 8),
            Text('Match History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF1f2937)),
        ),
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: Color(0xFF334155), size: 64),
                  SizedBox(height: 16),
                  Text('No matches saved to database', style: TextStyle(color: Color(0xFF475569), fontSize: 16)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1f2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF1d4ed8).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Text('Match #$matchNumber', style: const TextStyle(color: Color(0xFF60a5fa), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => Icon(
                  Icons.star,
                  size: 14,
                  color: i < record.stars ? Colors.amber : Colors.grey.shade800,
                )),
              ),
              const SizedBox(width: 8),
              Text(timeStr, style: const TextStyle(color: Color(0xFF475569), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          
          Text(record.statusText,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List.generate(record.playerNames.length, (i) {
              final color = kColors[i]!.main;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(record.playerNames[i], style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                    if (record.playerIsAI[i]) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.memory, color: color.withValues(alpha: 0.7), size: 10),
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