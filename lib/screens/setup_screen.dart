import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/board_constants.dart';
import '../logic/game_notifier.dart';
import '../models/game_settings.dart';
import 'history_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with SingleTickerProviderStateMixin {
  final List<bool> _isAI = [false, false, false, false];
  final List<TextEditingController> _nameCtrl = List.generate(4, (i) => TextEditingController());
  late GameSettings _settings;
  late AnimationController _logoCtrl;
  late Animation<double> _logoAnim;
  int _playerCount = 4;

  @override
  void initState() {
    super.initState();
    _settings = context.read<GameNotifier>().settings;
    _playerCount = 4; // Fixed to 4 players
    for (int i = 0; i < 4; i++) {
      _nameCtrl[i].text = kColors[i]!.name + '...';
    }
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _logoAnim = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    for (final c in _nameCtrl) c.dispose();
    super.dispose();
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => _SettingsDialog(
        settings: _settings,
        onSave: (s) => setState(() => _settings = s),
      ),
    );
  }

  List<int> _getVisiblePlayers() {
    return [0, 1, 2, 3]; // All players
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0f1e),
      body: Stack(
        children: [
          CustomPaint(painter: _GridPainter(), size: Size.infinite),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildLogo(),
                           Positioned(
                             left: 0,
                             top: 0,
                             child: GestureDetector(
                               onTap: _openSettings,
                               child: Container(
                                 width: 40, height: 40,
                                 decoration: BoxDecoration(
                                   color: const Color(0xFF111827),
                                   borderRadius: BorderRadius.circular(10),
                                   border: Border.all(color: const Color(0xFF1f2937)),
                                 ),
                                 child: const Icon(Icons.tune_rounded, color: Color(0xFF60a5fa), size: 20),
                               ),
                             ),
                           ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _buildPlayersCard(),
                       const SizedBox(height: 24),
                       _buildStartButton(),
                       const SizedBox(height: 16),
                       _buildHistoryButton(),
                       const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoAnim,
      builder: (_, child) => Transform.translate(offset: Offset(0, _logoAnim.value), child: child),
      child: Column(
        children: [
          Image.asset('assets/images/starting.png', width: 120, height: 120, errorBuilder: (c,e,s) => Icon(Icons.casino, size: 80, color: Colors.blue)),
          const SizedBox(height: 10),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFef4444), Color(0xFFfacc15), Color(0xFF22c55e), Color(0xFF3b82f6)],
            ).createShader(b),
            child: const Text('وطني چکه', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 6)),
          ),
          const SizedBox(height: 2),
          const Text('Classic Board Game', style: TextStyle(color: Color(0xFF64748b), fontSize: 12, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildPlayersCard() {
    final visibleIndexes = _getVisiblePlayers();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1f2937)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
             children: [
               const Icon(Icons.people, color: Color(0xFF60a5fa), size: 16),
               const SizedBox(width: 8),
               const Text('PLAYERS', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
             ],
           ),
          const SizedBox(height: 16),
           ...visibleIndexes.map((i) => Padding(
             padding: const EdgeInsets.only(bottom: 12),
             child: _PlayerRow(
               index: i,
               isAI: _isAI[i],
               nameCtrl: _nameCtrl[i],
               onTypeChanged: (v) => setState(() {
                 _isAI[i] = v;
                 _nameCtrl[i].text = v ? 'Bot ${kColors[i]!.name}...' : kColors[i]!.name + '...';
               }),
             ),
           )),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          final game = context.read<GameNotifier>();
          game.updateSettings(_settings.copyWith(playerCount: _playerCount));
          game.startGame(List.generate(4, (i) => {
            'isAI': _isAI[i],
            'name': _nameCtrl[i].text.trim().isEmpty ? (_isAI[i] ? 'Bot ${kColors[i]!.name}' : kColors[i]!.name) : _nameCtrl[i].text.trim(),
          }));
        },
        icon: const Icon(Icons.play_arrow_rounded, size: 26),
        label: const Text('Start Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563eb),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 8,
          shadowColor: const Color(0xFF2563eb).withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
        icon: const Icon(Icons.history, size: 20),
        label: const Text('View History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF94a3b8),
          side: const BorderSide(color: Color(0xFF1f2937)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// _PlayerRow, _SegmentedToggle, _SettingsDialog, and _GridPainter remain exactly similar as previous, but included for completeness:

class _PlayerRow extends StatelessWidget {
  final int index;
  final bool isAI;
  final TextEditingController nameCtrl;
  final ValueChanged<bool> onTypeChanged;
  const _PlayerRow({required this.index, required this.isAI, required this.nameCtrl, required this.onTypeChanged});

  @override
  Widget build(BuildContext context) {
    final color = kColors[index]!.main;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: color.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
           Icon(Icons.lens, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
             child: TextField(
               controller: nameCtrl,
               style: const TextStyle(color: Colors.white, fontSize: 14),
               decoration: InputDecoration(
                 suffixIcon: Icon(Icons.edit, color: color.withValues(alpha: 0.5), size: 16),
                 isDense: true,
                 border: InputBorder.none,
                 contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               ),
             ),
          ),
          _SegmentedToggle(options: const ['Human', 'AI'], selected: isAI ? 1 : 0, color: color, onChanged: (i) => onTypeChanged(i == 1)),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatefulWidget {
  final List<String> options; final int selected; final Color color; final ValueChanged<int> onChanged;
  const _SegmentedToggle({required this.options, required this.selected, required this.color, required this.onChanged});
  @override State<_SegmentedToggle> createState() => _SegmentedToggleState();
}
class _SegmentedToggleState extends State<_SegmentedToggle> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _anim;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: widget.selected == 1 ? 1.0 : 0.0); _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl); }
  @override void didUpdateWidget(_SegmentedToggle old) { super.didUpdateWidget(old); if (widget.selected != old.selected) { if (widget.selected == 1) _ctrl.forward(); else _ctrl.reverse(); } }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final newSelected = local.dx > box.size.width / 2 ? 1 : 0;
        if (newSelected != widget.selected) widget.onChanged(newSelected);
      },
      child: GestureDetector(
        onTap: () => widget.onChanged(widget.selected == 0 ? 1 : 0),
        onHorizontalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox;
          final local = box.globalToLocal(details.globalPosition);
          final newSelected = local.dx > box.size.width / 2 ? 1 : 0;
          if (newSelected != widget.selected) widget.onChanged(newSelected);
        },
        child: Container(
          width: 80, height: 32,
          decoration: BoxDecoration(color: const Color(0xFF0f172a), borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.color.withValues(alpha: 0.5))),
          child: Stack(
            children: [
              AnimatedBuilder(animation: _anim, builder: (c, child) => Positioned(left: 2 + _anim.value * (76 - 34), top: 2, child: Container(width: 34, height: 28, decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(14))))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(widget.options.length, (i) => AnimatedBuilder(animation: _anim, builder: (c, child) { final isSelected = (i == 0 && _anim.value < 0.5) || (i == 1 && _anim.value >= 0.5); return SizedBox(width: 38, child: Center(child: Icon(i == 0 ? Icons.person : Icons.computer, color: isSelected ? Colors.white : const Color(0xFF64748b), size: 24))); }))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  final GameSettings settings; final ValueChanged<GameSettings> onSave;
  const _SettingsDialog({required this.settings, required this.onSave});
  @override State<_SettingsDialog> createState() => _SettingsDialogState();
}
class _SettingsDialogState extends State<_SettingsDialog> {
  late GameSettings _s;
  @override void initState() { super.initState(); _s = widget.settings; }
  @override Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1f2937)), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 12, 0), child: Row(children: [const Icon(Icons.tune_rounded, color: Color(0xFF60a5fa), size: 20), const SizedBox(width: 8), const Text('Game Rules', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Color(0xFF475569), size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints())])),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 20),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
              _Toggle(label: 'Double Six / One Bonus', sub: 'Rolling 6+6 or 1+1 grants an extra roll', icon: Icons.casino, value: _s.doubleSixBonus, onChanged: (v) => setState(() => _s = _s.copyWith(doubleSixBonus: v))),
              _Toggle(label: 'Kill to Enter Home', sub: 'Must capture before entering home stretch', icon: Icons.home, value: _s.killToEnter, onChanged: (v) => setState(() => _s = _s.copyWith(killToEnter: v))),
              _Toggle(label: 'Safe Zones', sub: 'Star cells protect pieces from capture', icon: Icons.star, value: _s.safeZonesEnabled, onChanged: (v) => setState(() => _s = _s.copyWith(safeZonesEnabled: v))),
              _Toggle(label: 'Prison Rule', sub: 'Captured pieces need 6 to escape prison', icon: Icons.lock, value: _s.prisonRule, onChanged: (v) => setState(() => _s = _s.copyWith(prisonRule: v))),
              _Toggle(label: 'Auto-Move Unambiguous', sub: 'Auto-play when only one valid move exists', icon: Icons.auto_fix_high, value: _s.autoMoveUnambiguous, onChanged: (v) => setState(() => _s = _s.copyWith(autoMoveUnambiguous: v))),
              _Toggle(label: 'Team Play (4 Players Only)', sub: 'Red+Yellow vs Green+Blue win together', icon: Icons.groups, value: _s.teamPlay && _s.playerCount == 4, onChanged: (v) => setState(() { if(_s.playerCount == 4) _s = _s.copyWith(teamPlay: v); }), isLast: true),
            ]))),
            Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { widget.onSave(_s); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563eb), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))))),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label, sub; final IconData icon; final bool value, isLast; final ValueChanged<bool> onChanged;
  const _Toggle({required this.label, required this.sub, required this.icon, required this.value, required this.onChanged, this.isLast = false});
  @override Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: value ? const Color(0xFF1d4ed8).withValues(alpha: 0.2) : const Color(0xFF1e293b), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 17, color: value ? const Color(0xFF60a5fa) : const Color(0xFF475569))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), Text(sub, style: const TextStyle(color: Color(0xFF64748b), fontSize: 11))])),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF3b82f6), activeTrackColor: const Color(0xFF1d4ed8).withValues(alpha: 0.4), inactiveThumbColor: const Color(0xFF475569), inactiveTrackColor: const Color(0xFF1e293b)),
      ])),
      if (!isLast) Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) { final p = Paint()..color = const Color(0xFF1f2937).withValues(alpha: 0.35)..strokeWidth = 0.5; for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p); for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), p); }
  @override bool shouldRepaint(_) => false;
}