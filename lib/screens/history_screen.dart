import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/board_constants.dart';
import '../logic/game_notifier.dart';
import '../models/match_record.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final history = context.watch<GameNotifier>().history;
    final filtered = _applyFilter(history);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPanel,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: AppTheme.trophyGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Match History',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const Spacer(),
            Text(
              '${history.length} matches',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: Column(
        children: [
          if (history.isNotEmpty) _buildFilterBar(),
          Expanded(
            child: history.isEmpty
                ? const _EmptyState()
                : (filtered.isEmpty
                    ? const _NoMatchesState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final record =
                              filtered[filtered.length - 1 - index];
                          return _MatchCard(
                            record: record,
                            matchNumber: history.length -
                                history.indexOf(record),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Solo Wins',
            selected: _filter == 'solo',
            onTap: () => setState(() => _filter = 'solo'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Team Wins',
            selected: _filter == 'team',
            onTap: () => setState(() => _filter = 'team'),
          ),
        ],
      ),
    );
  }

  List<MatchRecord> _applyFilter(List<MatchRecord> all) {
    switch (_filter) {
      case 'solo':
        return all.where((r) => !r.winnerLabel.contains('+')).toList();
      case 'team':
        return all.where((r) => r.winnerLabel.contains('+')).toList();
      default:
        return all;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppTheme.durFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryButton : null,
          color: selected ? null : AppTheme.bgPanel,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: selected
                ? AppTheme.accentBlueDeep
                : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.bgPanel,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border, width: 1.5),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppTheme.textFaint,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No matches yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Play a game and your wins will appear here.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            color: AppTheme.textFaint,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No matches match this filter',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
            ),
          ),
        ],
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
    final timeStr =
        '${now.day}/${now.month}/${now.year}  ${_two(now.hour)}:${_two(now.minute)}';
    final losers = _getLosers();
    final history = context.read<GameNotifier>().history;
    final rec = history.isNotEmpty ? history.last : record;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.bgPanel, AppTheme.bgPanelAlt],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlueDeep.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Match #$matchNumber',
                    style: const TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: i < record.stars
                            ? AppTheme.accentYellow
                            : AppTheme.borderStrong,
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: AppTheme.textFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SideRow(
              iconData: Icons.emoji_events_rounded,
              iconGradient: AppTheme.trophyGradient,
              label: 'Won',
              labelColor: AppTheme.accentGreen,
              names: _splitWinners(),
              record: rec,
            ),
            const SizedBox(height: 8),
            if (losers.isNotEmpty)
              _SideRow(
                iconData: Icons.close_rounded,
                iconGradient: const LinearGradient(
                  colors: [AppTheme.accentRed, Color(0xFFf43f5e)],
                ),
                label: 'Defeated',
                labelColor: AppTheme.accentRed,
                names: losers,
                record: rec,
              )
            else
              _SideRow(
                iconData: Icons.shield_rounded,
                iconGradient: const LinearGradient(
                  colors: [AppTheme.accentGreen, Color(0xFF22c55e)],
                ),
                label: 'Solo Victory',
                labelColor: AppTheme.accentGreen,
                names: const [],
                emptyMessage: 'No opponents finished',
                record: rec,
              ),
          ],
        ),
      ),
    );
  }

  List<String> _splitWinners() =>
      record.winnerLabel.split('+').map((e) => e.trim()).toList();

  List<String> _getLosers() {
    if (record.statusText.startsWith('Defeated: ')) {
      return record.statusText.substring(10).split(', ');
    }
    return [];
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}

class _SideRow extends StatelessWidget {
  final IconData iconData;
  final Gradient iconGradient;
  final String label;
  final Color labelColor;
  final List<String> names;
  final String? emptyMessage;
  final MatchRecord record;
  const _SideRow({
    required this.iconData,
    required this.iconGradient,
    required this.label,
    required this.labelColor,
    required this.names,
    this.emptyMessage,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: iconGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: names.isEmpty
                ? Text(
                    emptyMessage ?? '—',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: names
                        .map((n) => _buildNameChip(n, record))
                        .toList(),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameChip(String name, MatchRecord rec) {
    final idx = rec.playerNames.indexOf(name);
    final color = (idx >= 0 && idx < kColors.length)
        ? kColors[idx]!.main
        : AppTheme.textMuted;
    final isAI = (idx >= 0 && idx < rec.playerIsAI.length)
        ? rec.playerIsAI[idx]
        : false;
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
            isAI ? Icons.memory : Icons.person,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
