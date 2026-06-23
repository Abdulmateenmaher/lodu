import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/board_constants.dart';
import '../logic/game_notifier.dart';
import '../models/game_settings.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/gradient_button.dart';
import '../widgets/common/player_avatar.dart';
import '../widgets/common/glowing_grid_background.dart';
import 'history_screen.dart';
import 'online_setup_screen.dart';
import 'settings_sheet.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with TickerProviderStateMixin {
  final List<bool> _isAI = [false, false, false, false];
  final List<TextEditingController> _nameCtrl =
      List.generate(4, (i) => TextEditingController());
  late GameSettings _settings;
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<GameNotifier>().settings;
    for (int i = 0; i < 4; i++) {
      _nameCtrl[i].text = kColors[i]!.name;
    }
    _muted = AudioService.isMuted;
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _enterAnim =
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    for (final c in _nameCtrl) c.dispose();
    super.dispose();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(
        settings: _settings,
        onSave: (s) => setState(() => _settings = s),
      ),
    );
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    AudioService.setMuted(_muted);
    Haptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowingGridBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.gap20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: FadeTransition(
                    opacity: _enterAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(_enterAnim),
                      child: Column(
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: AppTheme.gap12),
                          _buildLogo(),
                          const SizedBox(height: AppTheme.gap24),
                          _buildPlayersCard(),
                          const SizedBox(height: AppTheme.gap20),
                          _buildStartButton(),
                          const SizedBox(height: AppTheme.gap12),
                          _buildSecondaryActions(),
                          const SizedBox(height: AppTheme.gap20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleIconBtn(
          icon: Icons.tune_rounded,
          color: AppTheme.accentBlue,
          onTap: _openSettings,
        ),
        const Spacer(),
        _CircleIconBtn(
          icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: _muted ? AppTheme.textMuted : AppTheme.accentGreen,
          onTap: _toggleMute,
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => AppTheme.titleGradient.createShader(b),
          child: const Text(
            'وطني چکه',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayersCard() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.people_rounded,
                    color: AppTheme.accentBlue, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'PLAYERS',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.gap14),
          ...List.generate(4, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlayerRow(
                index: i,
                isAI: _isAI[i],
                nameCtrl: _nameCtrl[i],
                onTypeChanged: (v) {
                  Haptics.selection();
                  setState(() {
                    _isAI[i] = v;
                    _nameCtrl[i].text =
                        v ? 'Bot ${kColors[i]!.name}' : kColors[i]!.name;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return GradientButton(
      label: 'Start Match',
      icon: Icons.play_arrow_rounded,
      onPressed: () {
        Haptics.medium();
        final game = context.read<GameNotifier>();
        game.updateSettings(_settings.copyWith(playerCount: 4));
        game.startGame(List.generate(4, (i) {
          return {
            'isAI': _isAI[i],
            'name': _nameCtrl[i].text.trim().isEmpty
                ? (_isAI[i] ? 'Bot ${kColors[i]!.name}' : kColors[i]!.name)
                : _nameCtrl[i].text.trim(),
          };
        }));
      },
      expand: true,
    );
  }

  Widget _buildSecondaryActions() {
    return Column(
      children: [
        OutlinedPillButton(
          label: 'Play Online',
          icon: Icons.wifi_rounded,
          color: AppTheme.accentGreen,
          onPressed: () {
            Haptics.light();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OnlineSetupScreen()),
            );
          },
        ),
        const SizedBox(height: AppTheme.gap10),
        OutlinedPillButton(
          label: 'View History',
          icon: Icons.history_rounded,
          color: AppTheme.textMuted,
          onPressed: () {
            Haptics.light();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            );
          },
        ),
      ],
    );
  }
}


class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.bgPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final int index;
  final bool isAI;
  final TextEditingController nameCtrl;
  final ValueChanged<bool> onTypeChanged;
  const _PlayerRow({
    required this.index,
    required this.isAI,
    required this.nameCtrl,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = kColors[index]!.main;
    return AnimatedContainer(
      duration: AppTheme.durFast,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Row(
        children: [
          PlayerAvatar(color: color, isAI: isAI, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: nameCtrl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                suffixIcon: Icon(
                  Icons.edit_rounded,
                  color: color.withValues(alpha: 0.7),
                  size: 14,
                ),
              ),
            ),
          ),
          _SegmentedToggle(
            options: const ['Human', 'AI'],
            selected: isAI ? 1 : 0,
            color: color,
            onChanged: (i) => onTypeChanged(i == 1),
          ),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatefulWidget {
  final List<String> options;
  final int selected;
  final Color color;
  final ValueChanged<int> onChanged;
  const _SegmentedToggle({
    required this.options,
    required this.selected,
    required this.color,
    required this.onChanged,
  });
  @override
  State<_SegmentedToggle> createState() => _SegmentedToggleState();
}

class _SegmentedToggleState extends State<_SegmentedToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppTheme.durMed,
    value: widget.selected == 1 ? 1.0 : 0.0,
  );
  late final Animation<double> _anim =
      Tween<double>(begin: 0, end: 1).animate(_ctrl);

  @override
  void didUpdateWidget(_SegmentedToggle old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected) {
      if (widget.selected == 1) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(widget.selected == 0 ? 1 : 0),
      child: Container(
        width: 92,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF0f172a),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: widget.color.withValues(alpha: 0.5)),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (c, child) => Positioned(
                left: 2 + _anim.value * 46,
                top: 2,
                child: Container(
                  width: 38,
                  height: 30,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(widget.options.length, (i) {
                return AnimatedBuilder(
                  animation: _anim,
                  builder: (c, child) {
                    final isSelected = (i == 0 && _anim.value < 0.5) ||
                        (i == 1 && _anim.value >= 0.5);
                    return SizedBox(
                      width: 42,
                      child: Center(
                        child: Icon(
                          i == 0 ? Icons.person : Icons.computer,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSubtle,
                          size: 18,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
