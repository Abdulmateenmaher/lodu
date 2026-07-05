import 'package:flutter/material.dart';
import '../logic/online_game_notifier.dart';
import '../models/online_models.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/gradient_button.dart';
import '../widgets/common/glowing_grid_background.dart';
import 'online_game_screen.dart';

const String _kServerUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'https://ludu-backend.onrender.com',
);

String _normalizeServerUrl(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;

class OnlineSetupScreen extends StatefulWidget {
  const OnlineSetupScreen({super.key});

  @override
  State<OnlineSetupScreen> createState() => _OnlineSetupScreenState();
}

class _OnlineSetupScreenState extends State<OnlineSetupScreen>
    with TickerProviderStateMixin {
  late final OnlineGameNotifier _notifier;
  final _nameCtrl = TextEditingController();
  int _playerCount = 4;
  bool _isConnecting = false;
  bool _navigatedToGame = false;
  late AnimationController _pulseCtrl;
  late AnimationController _diceCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _diceAnim;

  @override
  void initState() {
    super.initState();
    _notifier = OnlineGameNotifier();
    debugPrint('[Lodu] Backend URL = $_kServerUrl');
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
    _notifier.addListener(_onPhaseChanged);

    final auth = AuthService();
    final user = auth.currentUser;
    if (user != null && _nameCtrl.text.trim().isEmpty) {
      _nameCtrl.text = user.displayLabel;
    }

    // Setup animations for the loading screen
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _diceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _diceAnim = Tween<double>(begin: 0, end: 1).animate(_diceCtrl);
  }

  void _onPhaseChanged() {
    if (!_navigatedToGame &&
        (_notifier.onlinePhase == OnlinePhase.lobby ||
            _notifier.onlinePhase == OnlinePhase.playing)) {
      _navigatedToGame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (ctx) => OnlineGameScreen(notifier: _notifier),
            ),
          );
        }
      });
    }
  }

  Future<void> _autoConnect() async {
    setState(() => _isConnecting = true);
    try {
      await _notifier.connect(_normalizeServerUrl(_kServerUrl));
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _diceCtrl.dispose();
    _notifier.removeListener(_onPhaseChanged);
    _nameCtrl.dispose();
    if (!_navigatedToGame) {
      _notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (ctx, _) {
        if (_notifier.onlinePhase == OnlinePhase.lobby ||
            _notifier.onlinePhase == OnlinePhase.playing ||
            _notifier.onlinePhase == OnlinePhase.ended) {
          return OnlineGameScreen(notifier: _notifier);
        }
        return Scaffold(
          backgroundColor: AppTheme.bgDeep,
          body: Stack(
            children: [
              const Positioned.fill(child: GlowingGridBackground()),
              _notifier.onlinePhase == OnlinePhase.connecting || _isConnecting
                  ? _buildLoadingState()
                  : _buildBody(ctx),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated dice row
          AnimatedBuilder(
            animation: _diceAnim,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedDie(value: 4, animValue: _diceAnim.value),
                  const SizedBox(width: 16),
                  _AnimatedDie(value: 2, animValue: _diceAnim.value),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          // Loading text
          const Text(
            'Activating Server',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          // Server URL with pulse effect
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              return Opacity(
                opacity: _pulseAnim.value,
                child: Text(
                  _kServerUrl,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Progress indicator
          const SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFF1e293b),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.accentBlue,
              ),
              minHeight: 3,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(height: 32),
          // Connecting status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Connecting...',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ServerUrlChip(url: _kServerUrl),
          const SizedBox(height: 16),
          const _SectionLabel('Your Name', icon: Icons.badge_rounded),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDec('Enter your name'),
          ),
          const SizedBox(height: 20),
          if (_notifier.onlinePhase == OnlinePhase.error) ...[
            _ErrorCard(message: _notifier.errorMsg ?? 'Unknown error'),
            const SizedBox(height: 16),
          ],
          const _SectionLabel(
            'Host a Game',
            icon: Icons.add_circle_outline_rounded,
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Players',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [2, 3, 4].map((n) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CountButton(
                        label: '$n',
                        selected: _playerCount == n,
                        onTap: () {
                          Haptics.selection();
                          setState(() => _playerCount = n);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: 'Create Room',
                  icon: Icons.add_circle_outline_rounded,
                  onPressed: _createRoom,
                  expand: true,
                  gradient: AppTheme.primaryButton,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel(
                'Available Rooms',
                icon: Icons.meeting_room_rounded,
              ),
              TextButton.icon(
                onPressed: _refreshLobby,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppTheme.accentBlue,
                ),
                label: const Text(
                  'Refresh',
                  style: TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_notifier.lobbyList.isEmpty)
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: const [
                  Icon(
                    Icons.videogame_asset_off_rounded,
                    color: AppTheme.textFaint,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No rooms available',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Create one or refresh in a few seconds.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._notifier.lobbyList.map((room) {
              return _RoomTile(
                room: room,
                onJoin: () => _requestJoin(room.roomId),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _ensureConnected() async {
    if (_notifier.onlinePhase == OnlinePhase.error) {
      _notifier.onlinePhase = OnlinePhase.idle;
    }
    if (!_notifier.isHubConnected) {
      await _notifier.connect(_normalizeServerUrl(_kServerUrl));
    }
  }

  Future<void> _createRoom() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter your name first');
      return;
    }
    setState(() => _isConnecting = true);
    try {
      await _ensureConnected();
      if (_notifier.onlinePhase == OnlinePhase.error) return;
      await _notifier.createRoom(
        hostName: name,
        settings: OnlineSettings(playerCount: _playerCount),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _refreshLobby() async {
    setState(() => _isConnecting = true);
    try {
      await _ensureConnected();
      if (_notifier.onlinePhase == OnlinePhase.error) return;
      await _notifier.fetchLobby();
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _requestJoin(String roomId) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter your name first');
      return;
    }
    setState(() => _isConnecting = true);
    try {
      await _ensureConnected();
      if (_notifier.onlinePhase == OnlinePhase.error) return;
      await _notifier.requestJoin(roomId, name);
      if (mounted) _showPendingDialog();
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ListenableBuilder(
        listenable: _notifier,
        builder: (ctx, _) {
          final status = _notifier.joinRequestStatus;
          final phase = _notifier.onlinePhase;
          if (status == 'declined' || phase == OnlinePhase.lobby) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            });
          }
          return Dialog(
            backgroundColor: AppTheme.bgPanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTheme.accentYellow,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Join Request Sent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status == 'declined'
                        ? 'Host declined your request.'
                        : 'Waiting for host to approve…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.bgPanelAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: AppTheme.bgPanel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(
            color: AppTheme.accentBlue,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      );
}

class _AnimatedDie extends StatelessWidget {
  final int value;
  final double animValue;

  const _AnimatedDie({required this.value, required this.animValue});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: animValue * 0.5,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2563eb),
              Color(0xFF60a5fa),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3b82f6).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerUrlChip extends StatelessWidget {
  final String url;
  const _ServerUrlChip({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgPanel,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_rounded, color: AppTheme.accentBlue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.accentRed.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.accentRed,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.accentRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionLabel(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 14),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CountButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CountButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.durFast,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.primaryButton : null,
            color: selected ? null : AppTheme.bgPanel,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected
                  ? AppTheme.accentBlueDeep
                  : AppTheme.borderStrong,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
}

class _RoomTile extends StatelessWidget {
  final RoomSummary room;
  final VoidCallback onJoin;
  const _RoomTile({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1e293b),
            Color(0xFF0f172a),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF60a5fa), Color(0xFF2563eb)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: const Icon(Icons.videogame_asset_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${room.filledSlots}/${room.maxSlots} players - ${room.settingsLabel}',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: onJoin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            elevation: 4,
            shadowColor: AppTheme.accentGreen.withValues(alpha: 0.5),
          ),
          child: const Text(
            'Join',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ]),
    );
  }
}