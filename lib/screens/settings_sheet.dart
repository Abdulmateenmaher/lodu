import 'package:flutter/material.dart';
import '../models/game_settings.dart';
import '../theme/app_theme.dart';

class SettingsSheet extends StatefulWidget {
  final GameSettings settings;
  final ValueChanged<GameSettings> onSave;
  const SettingsSheet({super.key, required this.settings, required this.onSave});
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late GameSettings _s;
  @override
  void initState() { super.initState(); _s = widget.settings; }
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgPanel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.borderStrong, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 4), child: Row(children: [
            const Icon(Icons.tune_rounded, color: AppTheme.accentBlue, size: 20),
            const SizedBox(width: 8),
            const Text('Game Rules', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ])),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),
          Expanded(
            child: ListView(controller: scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              _RuleToggle(label: 'Double Six / One Bonus', sub: 'Rolling 6+6 or 1+1 grants extra roll', icon: Icons.casino_rounded, value: _s.doubleSixBonus,
                onChanged: (v) => setState(() => _s = _s.copyWith(doubleSixBonus: v))),
              _RuleToggle(label: 'Kill to Enter Home', sub: 'Must capture before entering home stretch', icon: Icons.home_rounded, value: _s.killToEnter,
                onChanged: (v) => setState(() => _s = _s.copyWith(killToEnter: v))),
              _RuleToggle(label: 'Safe Zones', sub: 'Star cells protect pieces from capture', icon: Icons.star_rounded, value: _s.safeZonesEnabled,
                onChanged: (v) => setState(() => _s = _s.copyWith(safeZonesEnabled: v))),
              _RuleToggle(label: 'Prison Rule', sub: 'Captured pieces need 6 to escape prison', icon: Icons.lock_rounded, value: _s.prisonRule,
                onChanged: (v) => setState(() => _s = _s.copyWith(prisonRule: v))),
              _RuleToggle(label: 'Auto-Move Unambiguous', sub: 'Auto-play when only one valid move exists', icon: Icons.auto_fix_high_rounded, value: _s.autoMoveUnambiguous,
                onChanged: (v) => setState(() => _s = _s.copyWith(autoMoveUnambiguous: v))),
              _RuleToggle(label: 'Team Play (4 Players Only)', sub: 'Red+Yellow vs Green+Blue win together', icon: Icons.groups_rounded,
                value: _s.teamPlay && _s.playerCount == 4,
                onChanged: (v) { if (_s.playerCount == 4) setState(() => _s = _s.copyWith(teamPlay: v)); }),
              const Divider(color: AppTheme.borderFaint, height: 20),
              _RuleToggle(label: 'Final 6 Finish', sub: 'Must roll a 6 to end the match (last piece)', icon: Icons.six_k_rounded, value: _s.finalSixFinish,
                onChanged: (v) => setState(() => _s = _s.copyWith(finalSixFinish: v))),
              _DiceCountToggle(value: _s.diceCount, onChanged: (v) => setState(() => _s = _s.copyWith(diceCount: v))),
              _RuleToggle(label: 'Skip on Double 3', sub: "3,3 skips the next player's turn", icon: Icons.skip_next_rounded, value: _s.skipOnDoubleThree,
                onChanged: (v) => setState(() => _s = _s.copyWith(skipOnDoubleThree: v))),
              _RuleToggle(label: 'Blost on Double 4', sub: '4,4 = 2 extra 6s + hits all unprotected pieces', icon: Icons.auto_delete_rounded,
                value: _s.blostOnDoubleFour, onChanged: (v) => setState(() => _s = _s.copyWith(blostOnDoubleFour: v)), isLast: true),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () { widget.onSave(_s); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlueDeep, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 6, shadowColor: AppTheme.accentBlueDeep.withValues(alpha: 0.5)),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ))),
        ]),
      ),
    );
  }
}


class _RuleToggle extends StatelessWidget {
  final String label, sub;
  final IconData icon;
  final bool value, isLast;
  final ValueChanged<bool> onChanged;
  const _RuleToggle({required this.label, required this.sub, required this.icon, required this.value, required this.onChanged, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
        AnimatedContainer(duration: AppTheme.durFast, width: 36, height: 36,
          decoration: BoxDecoration(color: value ? AppTheme.accentBlueDeep.withValues(alpha: 0.25) : AppTheme.bgPanelAlt, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: value ? AppTheme.accentBlue : AppTheme.textFaint)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(sub, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        Switch(value: value, onChanged: onChanged, activeColor: AppTheme.accentBlue,
          activeTrackColor: AppTheme.accentBlueDeep.withValues(alpha: 0.4), inactiveThumbColor: AppTheme.textFaint, inactiveTrackColor: AppTheme.bgPanelAlt),
      ])),
      if (!isLast) Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
    ]);
  }
}

class _DiceCountToggle extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DiceCountToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
        AnimatedContainer(duration: AppTheme.durFast, width: 36, height: 36,
          decoration: BoxDecoration(color: AppTheme.accentBlueDeep.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.casino_outlined, size: 18, color: AppTheme.accentBlue)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dice Count', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text('${value == 1 ? '1 dice' : '2 dices'} for rolling${value == 1 ? ' (hit = extra turn)' : ''}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        _SegmentedToggle(options: ['1', '2'], selected: value == 1 ? 0 : 1, color: AppTheme.accentBlue, onChanged: (i) => onChanged(i == 0 ? 1 : 2)),
      ])),
      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
    ]);
  }
}

class _SegmentedToggle extends StatefulWidget {
  final List<String> options;
  final int selected;
  final Color color;
  final ValueChanged<int> onChanged;
  const _SegmentedToggle({required this.options, required this.selected, required this.color, required this.onChanged});
  @override
  State<_SegmentedToggle> createState() => _SegmentedToggleState();
}

class _SegmentedToggleState extends State<_SegmentedToggle> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: AppTheme.durMed, value: widget.selected == 1 ? 1.0 : 0.0);
  late final Animation<double> _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  @override
  void didUpdateWidget(_SegmentedToggle old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected) {
      if (widget.selected == 1) _ctrl.forward(); else _ctrl.reverse();
    }
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(widget.selected == 0 ? 1 : 0),
      child: Container(width: 92, height: 34,
        decoration: BoxDecoration(color: const Color(0xFF0f172a), borderRadius: BorderRadius.circular(17), border: Border.all(color: widget.color.withValues(alpha: 0.5))),
        child: Stack(children: [
          AnimatedBuilder(animation: _anim, builder: (c, child) => Positioned(left: 2 + _anim.value * 46, top: 2, child: Container(width: 38, height: 30,
            decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 6)])))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(widget.options.length, (i) {
            return AnimatedBuilder(animation: _anim, builder: (c, child) {
              final isSelected = (i == 0 && _anim.value < 0.5) || (i == 1 && _anim.value >= 0.5);
              return SizedBox(width: 42, child: Center(child: Text(widget.options[i],
                style: TextStyle(color: isSelected ? Colors.white : AppTheme.textSubtle, fontSize: 14, fontWeight: FontWeight.bold))));
            });
          })),
        ]),
      ),
    );
  }
}
