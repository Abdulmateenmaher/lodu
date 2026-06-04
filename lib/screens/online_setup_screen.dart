import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../logic/online_game_notifier.dart';
import '../models/online_models.dart';
import 'online_game_screen.dart';

/// Backend base URL.
///
/// IMPORTANT — read this if the deployed app can't connect:
/// In Flutter Web *release* builds the value of a `const` String is
/// **baked into the generated `main.dart.js`** at compile time. It is
/// *not* read from the source at runtime. That means if you ever change
/// the value here, you MUST re-run `flutter build web` AND redeploy
/// the new `build/web/` folder — otherwise the browser keeps hitting
/// whichever URL was compiled into the previous bundle (this is exactly
/// why the Netlify deploy was still pointing at the old
/// `ludo-game.runasp.net` even after the source was updated to
/// `ludu-backend.onrender.com`).
///
/// To override at build time use:
///   flutter build web --dart-define=SERVER_URL=https://your-server.com
/// If `--dart-define` is not supplied, the `defaultValue` below is used.
const String _kServerUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'https://ludu-backend.onrender.com',
);

/// Strips a trailing slash so we never produce `…//gamehub` when the
/// caller (or a future `--dart-define`) passes a URL ending with `/`.
String _normalizeServerUrl(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;


class OnlineSetupScreen extends StatefulWidget {
  const OnlineSetupScreen({super.key});

  @override
  State<OnlineSetupScreen> createState() => _OnlineSetupScreenState();
}

class _OnlineSetupScreenState extends State<OnlineSetupScreen> {
  late final OnlineGameNotifier _notifier;
  final _nameCtrl = TextEditingController();
  int _playerCount = 4;
  bool _isConnecting = false;
  bool _pendingDialogOpen = false;
  bool _navigatedToGame = false;

  @override
  void initState() {
    super.initState();
    _notifier = OnlineGameNotifier();
    // Log the resolved backend URL exactly once so you can verify in the
    // browser console which server the deployed build is pointing at.
    // (In release mode this still goes to `console.log` — no UI cost.)
    debugPrint('[Lodu] Backend URL = $_kServerUrl');
    // Connect immediately so lobby loads on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());

    // Listen for phase changes to navigate to game screen
    _notifier.addListener(_onPhaseChanged);
  }
  
  void _onPhaseChanged() {
    // When phase changes to lobby/playing (after being accepted as a player),
    // navigate to the game screen as a new route to avoid setup screen issues
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
    _notifier.removeListener(_onPhaseChanged);
    _nameCtrl.dispose();
    // Don't dispose _notifier if we navigated to game screen
    // The game screen will handle disposal
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
          backgroundColor: const Color(0xFF0a0f1e),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111827),
            title: const Text('Play Online', style: TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _notifier.onlinePhase == OnlinePhase.connecting || _isConnecting
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(ctx),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Your name
          _SectionLabel('Your Name'),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDec('Enter your name'),
          ),

          const SizedBox(height: 24),

          if (_notifier.onlinePhase == OnlinePhase.error) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Text(_notifier.errorMsg ?? 'Unknown error',
                  style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 16),
          ],

          // ── Host a game ──
          _SectionLabel('Host a Game'),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Players: ', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            ...[2, 3, 4].map((n) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CountButton(
                    label: '$n',
                    selected: _playerCount == n,
                    onTap: () => setState(() => _playerCount = n),
                  ),
                )),
          ]),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _createRoom,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Room',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563eb),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 28),

          // ── Join a game ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel('Available Rooms'),
              TextButton.icon(
                onPressed: _refreshLobby,
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF60a5fa)),
                label: const Text('Refresh',
                    style: TextStyle(color: Color(0xFF60a5fa), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_notifier.lobbyList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No rooms available.\nCreate one or refresh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38)),
              ),
            )
          else
            ..._notifier.lobbyList.map((room) => _RoomTile(
                  room: room,
                  onJoin: () => _requestJoin(room.roomId),
                )),
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
    if (name.isEmpty) { _showSnack('Enter your name first'); return; }
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
    if (name.isEmpty) { _showSnack('Enter your name first'); return; }
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
    _pendingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ListenableBuilder(
        listenable: _notifier,
        builder: (ctx, __) {
          final status = _notifier.joinRequestStatus;
          final phase = _notifier.onlinePhase;
          
          // Close dialog when declined or when successfully joined (phase changes to lobby)
          if (status == 'declined' || phase == OnlinePhase.lobby) {
            _pendingDialogOpen = false;
            // Use WidgetsBinding to safely close the dialog after frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            });
          }
          
          return AlertDialog(
            backgroundColor: const Color(0xFF111827),
            title: const Text('Join Request Sent', style: TextStyle(color: Colors.white)),
            content: Text(
              status == 'declined'
                  ? 'Host declined your request.'
                  : 'Waiting for host to approve…',
              style: const TextStyle(color: Color(0xFF94a3b8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748b))),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1e293b),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF60a5fa))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF94a3b8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

class _CountButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CountButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563eb) : const Color(0xFF1e293b),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? const Color(0xFF2563eb) : const Color(0xFF334155)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold)),
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
        color: const Color(0xFF1e293b),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(children: [
        const Icon(Icons.videogame_asset, color: Color(0xFF60a5fa), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(room.hostName,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${room.filledSlots}/${room.maxSlots} players  •  ${room.settingsLabel}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        ElevatedButton(
          onPressed: onJoin,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22c55e),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Join',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ]),
    );
  }
}
