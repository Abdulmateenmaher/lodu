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

  List<String> _getLosers(MatchRecord record) {
    if (record.statusText.startsWith('Defeated: ')) {
      return record.statusText.substring(10).split(', ');
    }
    return [];
  }

  List<Widget> _getWinnerWidgets(MatchRecord record) {
    final winners = record.winnerLabel.split('+');
    return winners.map((name) {
      final index = record.playerNames.indexOf(name);
      if (index == -1) return const SizedBox();
      final color = kColors[index]!.main;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              record.playerIsAI[index] ? Icons.memory : Icons.person,
              color: color,
              size: 12,
            ),
            const SizedBox(width: 6),
            Text(name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _getLoserWidgets(MatchRecord record) {
    final losers = _getLosers(record);
    return losers.map((name) {
      final index = record.playerNames.indexOf(name);
      if (index == -1) return const SizedBox();
      final color = kColors[index]!.main;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              record.playerIsAI[index] ? Icons.memory : Icons.person,
              color: color,
              size: 12,
            ),
            const SizedBox(width: 6),
            Text(name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = record.playedAt;
    final timeStr = '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final losers = _getLosers(record);

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

          // Winners row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0f172a),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1e293b)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFfacc15), Color(0xFFf59e0b)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _getWinnerWidgets(record),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10b981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Won',
                    style: TextStyle(color: const Color(0xFF10b981), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Losers row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0f172a),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1e293b)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFef4444), Color(0xFFf43f5e)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _getLoserWidgets(record),
                  ),
                ),
                if (losers.isEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF10b981), Color(0xFF22c55e)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 16),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}