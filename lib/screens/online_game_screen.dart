import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/online_game_notifier.dart';
import '../logic/game_notifier.dart';
import '../logic/game_logic.dart';
import '../models/game_models.dart';
import '../models/online_models.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_cell_widget.dart';
import '../widgets/common/glowing_grid_background.dart';
import '../constants/board_constants.dart';

const _yardAlignments = [
  Alignment.bottomLeft,
  Alignment.topLeft,
  Alignment.topRight,
  Alignment.bottomRight,
];

// ── Root router for the online game ────────────────────────────────────────

class OnlineGameScreen extends StatelessWidget {
  final OnlineGameNotifier notifier;
  const OnlineGameScreen({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (ctx, _) {
        switch (notifier.onlinePhase) {
          case OnlinePhase.lobby:
            return _LobbyScreen(notifier: notifier);
          case OnlinePhase.ended:
            return _OnlineEndScreen(notifier: notifier);
          case OnlinePhase.playing:
            return _OnlinePlayScreen(notifier: notifier);
          default:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
        }
      },
    );
  }
}

// ── Lobby ───────────────────────────────────────────────────────────────────

class _LobbyScreen extends StatelessWidget {
  final OnlineGameNotifier notifier;
  const _LobbyScreen({required this.notifier});

  PreferredSizeWidget _buildAppBar(OnlineGameNotifier notifier, BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF111827),
      title: Text('Room  •  ${notifier.isHost ? "Host" : "Guest"}',
          style: const TextStyle(color: Colors.white)),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () async {
          await notifier.disconnect();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = notifier.room!;
    return Scaffold(
      backgroundColor: const Color(0xFF0a0f1e),
      body: Stack(
        children: [
          const Positioned.fill(child: GlowingGridBackground()),
          Column(
            children: [
              _buildAppBar(notifier, context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Room ID card
                      _Card(
                        child: Column(children: [
                          const Text('Room ID', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(room.roomId,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 6)),
                          const SizedBox(height: 4),
                          Text('Host: ${room.hostName}',
                              style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // Player slots
                      const Text('Players',
                          style: TextStyle(
                              color: Color(0xFF94a3b8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      ...room.players.where((p) => p.isActive).map((p) => _PlayerTile(
                            player: p,
                            isMe: p.id == notifier.mySlot,
                          )),

                      const SizedBox(height: 16),

                      // Host: pending join requests
                      if (notifier.isHost && notifier.pendingRequests.isNotEmpty) ...[
                        const Text('Join Requests',
                            style: TextStyle(
                                color: Color(0xFFfacc15),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        ...notifier.pendingRequests.map((req) => _JoinRequestTile(
                              request: req,
                              onApprove: () => notifier.approveJoin(req.connId),
                              onDecline: () => notifier.declineJoin(req.connId),
                            )),
                        const SizedBox(height: 16),
                      ],

                      // Guest: request status
                      if (!notifier.isHost) ...[
                        if (notifier.joinRequestStatus == 'declined')
                          const _StatusBadge(
                              'Request declined by host', Colors.red)
                        else if (notifier.joinRequestStatus == 'waiting')
                          const _StatusBadge(
                              'Waiting for host to approve...', Color(0xFFfacc15)),
                        const SizedBox(height: 12),
                      ],

                      const Spacer(),

                      if (notifier.isHost)
                        ElevatedButton.icon(
                          onPressed: notifier.startGame,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start Game',
                              style:
                                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563eb),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      else
                        const Center(
                            child: Text('Waiting for host to start…',
                                style: TextStyle(color: Colors.white54))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final OnlinePlayer player;
  final bool isMe;
  const _PlayerTile({required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = kColors[player.id]!.main;
    final name = player.name.isNotEmpty ? player.name : '— empty —';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
            child: Text('$name${isMe ? '  (You)' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 14))),
        if (player.connectionId != null)
          const Icon(Icons.check_circle, color: Colors.green, size: 16)
        else
          const Icon(Icons.radio_button_unchecked,
              color: Colors.white24, size: 16),
      ]),
    );
  }
}

class _JoinRequestTile extends StatelessWidget {
  final PendingRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  const _JoinRequestTile(
      {required this.request,
      required this.onApprove,
      required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1e293b),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFfacc15).withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.person_add, color: Color(0xFFfacc15), size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(request.name,
                style: const TextStyle(color: Colors.white, fontSize: 14))),
        TextButton(
          onPressed: onDecline,
          child: const Text('Decline',
              style: TextStyle(color: Colors.red, fontSize: 12)),
        ),
        ElevatedButton(
          onPressed: onApprove,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22c55e),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
          ),
          child: const Text('Accept',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 13)),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1e293b),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: child,
      );
}

// ── Play screen — proxy GameNotifier so BoardWidget works unchanged ──────────

class _OnlinePlayScreen extends StatefulWidget {
  final OnlineGameNotifier notifier;
  const _OnlinePlayScreen({required this.notifier});

  @override
  State<_OnlinePlayScreen> createState() => _OnlinePlayScreenState();
}

class _OnlinePlayScreenState extends State<_OnlinePlayScreen> {
  late _OnlineGameProxy _proxy;

  @override
  void initState() {
    super.initState();
    _proxy = _OnlineGameProxy(widget.notifier);
  }

  @override
  void dispose() {
    _proxy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: provide the proxy as GameNotifier so BoardWidget resolves it
    return ChangeNotifierProvider<GameNotifier>.value(
      value: _proxy,
      child: _OnlineGameBody(
          notifier: widget.notifier, proxy: _proxy),
    );
  }
}

/// Thin GameNotifier subclass — all fields populated from server state.
/// No local dice/move logic is ever called.
class _OnlineGameProxy extends GameNotifier {
  final OnlineGameNotifier _online;

  _OnlineGameProxy(this._online) {
    _online.addListener(_sync);
    _sync();
  }

  void _sync() {
    phase = _online.onlinePhase == OnlinePhase.playing
        ? GamePhase.play
        : GamePhase.end;
    players = _online.players;
    dicePool = List<int>.from(_online.dicePool);
    canRoll = _online.canRoll && _online.isMyTurn;
    turnSlot = _online.turnSlot;
    settings = _online.settings;
    toast = _online.toast;
    isRolling = false;
    // Use server-computed selectedDieIndex
    selectedDieIndex = _online.room?.selectedDieIndex;
    notifyListeners();
  }

  // ── Actions forwarded to server ──

  @override
  void rollDice() => _online.rollDice();

  @override
  void handleDieClick(int index) {
    if (index < dicePool.length) {
      selectedDieIndex = index;
      notifyListeners();
    }
  }

  @override
  void handlePieceClick(Piece piece) {
    if (!_online.isMyTurn) return;
    if (dicePool.isEmpty) return;
    if (selectedDieIndex != null && piece.hasKilledThisTurn) return;

    final ctrlId = getControlPlayerId();
    final pCtrl = players[ctrlId];
    final allValidMoves = getAllValidMoves(pCtrl, dicePool, players, settings);
    if (allValidMoves.length == 1) return; // server auto-moves single valid moves

    if (selectedDieIndex != null) {
      _online.movePiece(piece, [selectedDieIndex!]);
    } else if (dicePool.length == 2) {
      // Check if any single move possible; if not, try combined
      bool hasSingle = false;
      for (int i = 0; i < dicePool.length; i++) {
        final dest = calculateDestination(pCtrl, piece, dicePool[i], players,
            pool: dicePool, dieIndex: i, settings: settings);
        if (dest != null) { hasSingle = true; break; }
      }
      if (!hasSingle) {
        _online.movePiece(piece, [0, 1]);
      }
      // if hasSingle, user must click a die first to specify which
    }
  }

  @override
  void leaveMatch() {
    _online.disconnect();
  }

  @override
  void dispose() {
    _online.removeListener(_sync);
    // Do NOT call super.dispose() GameNotifier's dispose — it would affect
    // the real game notifier if shared. Safe to call since proxy is separate.
    super.dispose();
  }
}

// ── Game body (board + HUD) ─────────────────────────────────────────────────

class _OnlineGameBody extends StatelessWidget {
  final OnlineGameNotifier notifier;
  final _OnlineGameProxy proxy;
  const _OnlineGameBody(
      {required this.notifier, required this.proxy});

  @override
  Widget build(BuildContext context) {
    // Watch the proxy as GameNotifier — BoardWidget uses context.watch<GameNotifier>()
    final game = context.watch<GameNotifier>();
    final actId = game.turnSlot.clamp(0, 3);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowingGridBackground()),
          SafeArea(
            child: Stack(
              children: [
                // Board
                Center(
                  child: LayoutBuilder(builder: (ctx, c) {
                    final size =
                        c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
                    return SizedBox(
                        width: size,
                        height: size,
                        child: const BoardWidget());
                  }),
                ),

                // HUD overlay — animates to active player corner
                AnimatedAlign(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  alignment: _yardAlignments[actId],
                  child: Padding(
                    padding: _pad(_yardAlignments[actId]),
                    child: _OnlineHud(notifier: notifier, proxy: proxy),
                  ),
                ),

                // Leave button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _confirmLeave(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xCC111827),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: const Color(0xFF1f2937)),
                      ),
                      child: const Icon(Icons.exit_to_app_rounded,
                          color: Color(0xFFef4444), size: 20),
                    ),
                  ),
                ),

                // Toast
                if (game.toast != null)
                  Positioned(
                    top: 52,
                    left: 0,
                    right: 0,
                    child: Center(
                        child: _ToastBadge(message: game.toast!)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Match?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('You will disconnect from the online game.',
            style: TextStyle(color: Color(0xFF94a3b8))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748b)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await notifier.disconnect();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFef4444)),
            child: const Text('Leave',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  EdgeInsets _pad(Alignment a) {
    const p = 12.0;
    if (a == Alignment.topLeft) {
      return const EdgeInsets.only(top: p, left: p);
    }
    if (a == Alignment.topRight) {
      return const EdgeInsets.only(top: p, right: p);
    }
    if (a == Alignment.bottomLeft) {
      return const EdgeInsets.only(bottom: p, left: p);
    }
    return const EdgeInsets.only(bottom: p, right: p);
  }
}

// ── HUD ─────────────────────────────────────────────────────────────────────

class _OnlineHud extends StatefulWidget {
  final OnlineGameNotifier notifier;
  final _OnlineGameProxy proxy;
  const _OnlineHud({required this.notifier, required this.proxy});

  @override
  State<_OnlineHud> createState() => _OnlineHudState();
}

class _OnlineHudState extends State<_OnlineHud> {
  // Only the dice-roll timer is kept. There is no move timer in online mode.
  // When 10s pass without a roll, the server auto-rolls and auto-plays all
  // available pieces (using the same AI logic the bot uses).
  Timer? _autoRollTimer;
  double _countdownProgress = 1.0; // 1.0 = full, 0.0 = empty
  static const int _countdownSeconds = 10;

  @override
  void didUpdateWidget(_OnlineHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndStartTimer();
  }

  @override
  void dispose() {
    _autoRollTimer?.cancel();
    super.dispose();
  }

  void _checkAndStartTimer() {
    final game = widget.proxy;
    final isMyTurn = widget.notifier.isMyTurn;
    final isAI = game.players.isNotEmpty && game.players[game.turnSlot.clamp(0, 3)].isAI;

    // Only the dice-roll timer is used in online mode. The move timer is gone.
    // As soon as dice appear, the player can take as long as they like to move.
    if (!isMyTurn || isAI || !game.canRoll || game.dicePool.isNotEmpty) {
      _autoRollTimer?.cancel();
      _autoRollTimer = null;
      if (mounted) setState(() { _countdownProgress = 1.0; });
      return;
    }

    if (_autoRollTimer == null) {
      _startAutoRollTimer();
    }
  }

  void _startAutoRollTimer() {
    _countdownProgress = 1.0;
    final startTime = DateTime.now();
    _autoRollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final game = widget.proxy;
      final isMyTurn = widget.notifier.isMyTurn;
      final isAI = game.players.isNotEmpty && game.players[game.turnSlot.clamp(0, 3)].isAI;

      if (!isMyTurn || isAI || !game.canRoll || game.dicePool.isNotEmpty) {
        timer.cancel();
        _autoRollTimer = null;
        setState(() { _countdownProgress = 1.0; });
        return;
      }

      final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      final progress = 1.0 - (elapsed / _countdownSeconds);

      if (progress <= 0) {
        // 10 seconds passed without a roll — server auto-rolls and auto-plays
        // all available pieces (using AI logic).
        timer.cancel();
        _autoRollTimer = null;
        setState(() { _countdownProgress = 0.0; });
        widget.notifier.autoPlay();
        return;
      }

      setState(() {
        _countdownProgress = progress;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    final actId = game.turnSlot.clamp(0, 3);
    final color = kColors[actId]!.main;
    final isMyTurn = widget.notifier.isMyTurn;
    final playerName = game.players.isNotEmpty
        ? (game.players[actId].name.isNotEmpty
            ? game.players[actId].name
            : kColors[actId]!.name)
        : kColors[actId]!.name;
    final isAI =
        game.players.isNotEmpty && game.players[actId].isAI;

    // Show auto-roll countdown only when waiting for the player to roll.
    final showAutoRollCountdown = isMyTurn && !isAI && game.canRoll &&
        game.dicePool.isEmpty && _autoRollTimer != null;

    return GestureDetector(
      onTap: isMyTurn && game.canRoll ? game.rollDice : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xE61e293b),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 12)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Player name row
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(playerName,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              if (actId == widget.notifier.mySlot) ...[
                const SizedBox(width: 4),
                Text('(you)',
                    style: TextStyle(
                        color: color.withValues(alpha: 0.6),
                        fontSize: 10)),
              ],
            ]),
            const SizedBox(height: 6),

            // Dice row
            DiceCellRow(
              diceValues: game.dicePool,
              selectedIndex: game.selectedDieIndex,
              onDieTap: game.handleDieClick,
              cellSize: 48,
            ),
            const SizedBox(height: 8),

            // Status row - progress bar for the auto-roll countdown
            if (isAI)
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.memory,
                    color: Color(0xFF94a3b8), size: 14),
                SizedBox(width: 4),
                Text('AI thinking…',
                    style: TextStyle(
                        color: Color(0xFF94a3b8), fontSize: 11)),
              ])
            else if (!isMyTurn)
              Text('Waiting for ${playerName}…',
                  style: const TextStyle(
                      color: Color(0xFF94a3b8), fontSize: 11))
            else if (showAutoRollCountdown)
              // Show progress bar for the 10s auto-roll countdown
              SizedBox(
                height: 4,
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _countdownProgress,
                    backgroundColor: color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              )
            else if (game.canRoll)
              Text('Tap to roll',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))
            else
              Text('Tap a piece to move',
                  style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── End screen ───────────────────────────────────────────────────────────────

class _OnlineEndScreen extends StatelessWidget {
  final OnlineGameNotifier notifier;
  const _OnlineEndScreen({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final room = notifier.room;
    final OnlinePlayer? winner = room == null
        ? null
        : room.players.firstWhere((p) => p.isActive && p.finished,
            orElse: () => room.players.first);

    return Scaffold(
      backgroundColor: const Color(0xFF0a0f1e),
      body: Stack(
        children: [
          const Positioned.fill(child: GlowingGridBackground()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events,
                    size: 80, color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  '${winner?.name.isNotEmpty == true ? winner!.name : 'Player'} Wins!',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await notifier.disconnect();
                    if (context.mounted) {
                      Navigator.popUntil(context, (r) => r.isFirst);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563eb)),
                  child: const Text('Back to Menu',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastBadge extends StatelessWidget {
  final String message;
  const _ToastBadge({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF0f172a), width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 16)
          ],
        ),
        child: Text(message,
            style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      );
}