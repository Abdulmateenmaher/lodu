import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/board_constants.dart';
import '../../logic/game_notifier.dart';
import '../../models/game_settings.dart';
import '../theme/space_theme.dart';
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
    _playerCount = _settings.playerCount;
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _logoAnim = Tween<double>(begin: -4, end: 4).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));
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
    if (_playerCount == 2) return [1, 3];
    if (_playerCount == 3) return [0, 1, 3];
    return [0, 1, 2, 3];
  }

  @override
  Widget build(BuildContext context) {
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
                              right: 0,
                              top: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildGlossyIconBtn(
                                    icon: Icons.tune_rounded, 
                                    onTap: _openSettings,
                                    isPurple: false,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildGlossyIconBtn(
                                    icon: Icons.history, 
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                                    isPurple: false,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _buildPlayersCard(),
                        const SizedBox(height: 24),
                        _buildStartButton(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlossyIconBtn({required IconData icon, required VoidCallback onTap, required bool isPurple}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 44, height: 44,
            decoration: SpaceTheme.buttonDecoration(isPurple: isPurple).copyWith(
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SpaceTheme.glossyOverlay(44, 44, 12),
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
          Image.asset('assets/images/starting.png', width: 120, height: 120, errorBuilder: (c,e,s) => const Icon(Icons.rocket_launch, size: 80, color: Color(0xFF4DBBFF))),
          const SizedBox(height: 10),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF4DBBFF), Color(0xFFD8B4E2)],
            ).createShader(b),
            child: const Text('LUDO GALAXY', style: TextStyle(fontSize: 38, fontFamily: 'sans-serif', fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4, shadows: [Shadow(color: Colors.black54, blurRadius: 10)])),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersCard() {
    final visibleIndexes = _getVisiblePlayers();
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: SpaceTheme.panelDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people, color: Color(0xFF4DBBFF), size: 20),
                  const SizedBox(width: 8),
                  const Text('PLAYERS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF4DBBFF).withValues(alpha: 0.5))),
                    child: DropdownButton<int>(
                      value: _playerCount,
                      dropdownColor: const Color(0xFF0F265C),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4DBBFF), size: 18),
                      items: [2, 3, 4].map((e) => DropdownMenuItem(value: e, child: Text('$e Players'))).toList(),
                      onChanged: (v) => setState(() {
                        _playerCount = v!;
                        _settings = _settings.copyWith(playerCount: _playerCount);
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...visibleIndexes.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlayerRow(
                  index: i,
                  isAI: _isAI[i],
                  nameCtrl: _nameCtrl[i],
                  onTypeChanged: (v) => setState(() => _isAI[i] = v),
                ),
              )),
            ],
          ),
        ),
        SpaceTheme.glossyOverlay(double.infinity, 300, 20),
      ],
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () {
        final game = context.read<GameNotifier>();
        game.updateSettings(_settings.copyWith(playerCount: _playerCount));
        game.startGame(List.generate(4, (i) => {
          'isAI': _isAI[i],
          'name': _nameCtrl[i].text.trim().isEmpty ? (_isAI[i] ? 'Bot ${kColors[i]!.name}' : kColors[i]!.name) : _nameCtrl[i].text.trim(),
        }));
      },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: SpaceTheme.buttonDecoration(isPurple: true),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text('PLAY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              ],
            ),
          ),
          SpaceTheme.glossyOverlay(double.infinity, 60, 16),
        ],
      ),
    );
  }
}

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
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 4, spreadRadius: 1)],
      ),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 8)]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: isAI ? 'Bot ${kColors[index]!.name}' : kColors[index]!.name,
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _SegmentedToggle(options: const ['Human', 'Bot'], selected: isAI ? 1 : 0, color: color, onChanged: (i) => onTypeChanged(i == 1)),
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
      child: Container(
        width: 80, height: 32,
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.color.withValues(alpha: 0.5))),
        child: Stack(
          children: [
            AnimatedBuilder(animation: _anim, builder: (c, child) => Positioned(left: 2 + _anim.value * (76 - 38), top: 2, child: Container(width: 38, height: 26, decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: widget.color, blurRadius: 4)])))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(widget.options.length, (i) => AnimatedBuilder(animation: _anim, builder: (c, child) { final isSelected = (i == 0 && _anim.value < 0.5) || (i == 1 && _anim.value >= 0.5); return SizedBox(width: 38, child: Center(child: Text(widget.options[i], style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)))); }))),
          ],
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
        decoration: SpaceTheme.panelDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 12, 0), child: Row(children: [const Icon(Icons.tune_rounded, color: Color(0xFF4DBBFF), size: 24), const SizedBox(width: 8), const Text('OPTIONS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.redAccent, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints())])),
            Divider(color: const Color(0xFF4DBBFF).withValues(alpha: 0.3), height: 30, thickness: 1),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
              _Toggle(label: 'Double Six / One Bonus', sub: 'Rolling 6+6 or 1+1 grants an extra roll', icon: Icons.casino, value: _s.doubleSixBonus, onChanged: (v) => setState(() => _s = _s.copyWith(doubleSixBonus: v))),
              _Toggle(label: 'Kill to Enter Home', sub: 'Must capture before entering home stretch', icon: Icons.home, value: _s.killToEnter, onChanged: (v) => setState(() => _s = _s.copyWith(killToEnter: v))),
              _Toggle(label: 'Safe Zones', sub: 'Star cells protect pieces from capture', icon: Icons.star, value: _s.safeZonesEnabled, onChanged: (v) => setState(() => _s = _s.copyWith(safeZonesEnabled: v))),
              _Toggle(label: 'Prison Rule', sub: 'Captured pieces need 6 to escape prison', icon: Icons.lock, value: _s.prisonRule, onChanged: (v) => setState(() => _s = _s.copyWith(prisonRule: v))),
              _Toggle(label: 'Auto-Move Unambiguous', sub: 'Auto-play when only one valid move exists', icon: Icons.auto_fix_high, value: _s.autoMoveUnambiguous, onChanged: (v) => setState(() => _s = _s.copyWith(autoMoveUnambiguous: v))),
              _Toggle(label: 'Team Play (4 Players)', sub: 'Red+Yellow vs Green+Blue win together', icon: Icons.groups, value: _s.teamPlay && _s.playerCount == 4, onChanged: (v) => setState(() { if(_s.playerCount == 4) _s = _s.copyWith(teamPlay: v); }), isLast: true),
            ]))),
            Padding(padding: const EdgeInsets.all(20), child: GestureDetector(
              onTap: () { widget.onSave(_s); Navigator.pop(context); },
              child: Stack(
                children: [
                  Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: SpaceTheme.buttonDecoration(isPurple: true),
                    child: const Center(child: Text('SAVE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 1.5))),
                  ),
                  SpaceTheme.glossyOverlay(double.infinity, 48, 16),
                ],
              ),
            )),
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
        Container(width: 36, height: 36, decoration: BoxDecoration(color: value ? const Color(0xFF4DBBFF).withValues(alpha: 0.2) : Colors.black38, borderRadius: BorderRadius.circular(10), border: Border.all(color: value ? const Color(0xFF4DBBFF) : Colors.white24)), child: Icon(icon, size: 18, color: value ? const Color(0xFF4DBBFF) : Colors.white54)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11))])),
        Switch(value: value, onChanged: onChanged, activeColor: Colors.white, activeTrackColor: const Color(0xFF9D4EDD), inactiveThumbColor: Colors.white54, inactiveTrackColor: Colors.black38),
      ])),
      if (!isLast) Divider(color: const Color(0xFF4DBBFF).withValues(alpha: 0.2), height: 1),
    ]);
  }
}
