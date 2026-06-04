import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../models/game_settings.dart';
import '../models/online_models.dart';
import '../services/signalr_service.dart';
import '../services/audio_service.dart';

enum OnlinePhase { idle, connecting, lobby, playing, ended, error }

class PendingRequest {
  final String connId;
  final String name;
  const PendingRequest({required this.connId, required this.name});
}

class OnlineGameNotifier extends ChangeNotifier {
  final SignalRService _hub = SignalRService();

  OnlinePhase onlinePhase = OnlinePhase.idle;
  String? roomId;
  int mySlot = -1;
  bool isHost = false;
  OnlineRoom? room;
  String? toast;
  String? errorMsg;
  List<RoomSummary> lobbyList = [];
  List<PendingRequest> pendingRequests = [];
  String? joinRequestStatus;

  bool get isHubConnected => _hub.isConnected;

  // ── Derived state ──────────────────────────────────────────────────────

  List<Player> get players =>
      room?.players.map((p) => p.toLocalPlayer()).toList() ?? [];
  List<int> get dicePool => room?.dicePool ?? [];
  bool get canRoll => room?.canRoll ?? false;
  int get turnSlot => room?.turnSlot ?? 0;
  GameSettings get settings =>
      room?.settings.toLocalSettings() ?? const GameSettings();

  bool get isMyTurn {
    if (room == null || mySlot < 0) return false;
    final actPlayer = room!.players[room!.turnSlot];
    if (actPlayer.isAI) return false;
    final ctrlSlot = actPlayer.finished && actPlayer.isHelper
        ? actPlayer.partnerId
        : actPlayer.id;
    return ctrlSlot == mySlot || actPlayer.id == mySlot;
  }

  // ── Connect / disconnect ───────────────────────────────────────────────

  Future<void> connect(String serverUrl) async {
    if (_hub.isConnected) return;
    _setPhase(OnlinePhase.connecting);
    try {
      await _hub.connect(serverUrl);
      _registerHandlers();
      // Fetch lobby immediately after connecting
      await _hub.invoke('GetLobby');
      if (onlinePhase == OnlinePhase.connecting) _setPhase(OnlinePhase.idle);
    } catch (e) {
      errorMsg = 'Cannot connect: $e';
      _setPhase(OnlinePhase.error);
    }
  }

  Future<void> disconnect() async {
    _hub.off('RoomCreated');
    _hub.off('RoomJoined');
    _hub.off('GameState');
    _hub.off('LobbyList');
    _hub.off('JoinRequest');
    _hub.off('JoinRequestSent');
    _hub.off('JoinDeclined');
    _hub.off('Error');
    await _hub.disconnect();
    room = null;
    roomId = null;
    mySlot = -1;
    isHost = false;
    pendingRequests = [];
    joinRequestStatus = null;
    lobbyList = [];
    onlinePhase = OnlinePhase.idle;
    notifyListeners();
  }

  // ── Lobby actions ──────────────────────────────────────────────────────

  Future<void> fetchLobby() async => _hub.invoke('GetLobby');

  Future<void> createRoom({required String hostName, required OnlineSettings settings}) async =>
      _hub.invoke('CreateRoom', args: [hostName, settings.toJson()]);

  Future<void> requestJoin(String targetRoomId, String playerName) async {
    joinRequestStatus = 'pending';
    notifyListeners();
    await _hub.invoke('RequestJoin', args: [targetRoomId, playerName]);
  }

  Future<void> approveJoin(String requesterConnId) async {
    pendingRequests.removeWhere((r) => r.connId == requesterConnId);
    notifyListeners();
    await _hub.invoke('ApproveJoin', args: [requesterConnId]);
  }

  Future<void> declineJoin(String requesterConnId) async {
    pendingRequests.removeWhere((r) => r.connId == requesterConnId);
    notifyListeners();
    await _hub.invoke('DeclineJoin', args: [requesterConnId]);
  }

  Future<void> startGame() async => _hub.invoke('StartGame');

  // ── Game actions ────────────────────────────────────────────────────────

  Future<void> rollDice() async {
    if (!isMyTurn || !canRoll) return;
    await _hub.invoke('RollDice');
  }

  Future<void> movePiece(Piece piece, List<int> dieIndices) async {
    if (!isMyTurn) return;
    await _hub.invoke('MovePiece', args: [piece.id, piece.color, dieIndices]);
  }

  /// Called when the player's 10-second dice-roll timer expires.
  /// Server rolls the dice on the player's behalf and uses AI logic
  /// to instantly play all available pieces.
  Future<void> autoPlay() async {
    if (!isMyTurn) return;
    try {
      await _hub.invoke('AutoPlay');
    } catch (_) {
      // Server may have already moved on; that's fine
    }
  }

  // ── SignalR handlers ────────────────────────────────────────────────────

  void _registerHandlers() {
    _hub.on('RoomCreated', (args) {
      if (args == null || args.isEmpty) return;
      final data = _d(args[0]);
      mySlot = data['yourSlot'];
      isHost = true;
      room = OnlineRoom.fromJson(data['room'] as Map<String, dynamic>);
      roomId = room!.roomId;
      _setPhase(OnlinePhase.lobby);
    });

    _hub.on('RoomJoined', (args) {
      if (args == null || args.isEmpty) return;
      final data = _d(args[0]);
      mySlot = data['yourSlot'];
      isHost = false;
      room = OnlineRoom.fromJson(data['room'] as Map<String, dynamic>);
      roomId = room!.roomId;
      joinRequestStatus = null;
      _setPhase(OnlinePhase.lobby);
    });

    _hub.on('GameState', (args) {
      if (args == null || args.isEmpty) return;
      final data = _d(args[0]);
      final prev = room;
      room = OnlineRoom.fromJson(data['room'] as Map<String, dynamic>);
      final msg = data['toast'] as String?;
      _playSounds(prev, room!, msg);
      if (msg != null && msg.isNotEmpty) _showToast(msg);
      if (room!.phase == OnlineGamePhase.play && onlinePhase != OnlinePhase.playing) {
        AudioService.play('start_game');
        _setPhase(OnlinePhase.playing);
      } else if (room!.phase == OnlineGamePhase.end) {
        AudioService.stopAll();
        _setPhase(OnlinePhase.ended);
      } else {
        notifyListeners();
      }
    });

    _hub.on('LobbyList', (args) {
      if (args == null || args.isEmpty) return;
      final data = _d(args[0]);
      final list = data['rooms'] as List? ?? [];
      lobbyList = list.map((r) => RoomSummary.fromJson(r as Map<String, dynamic>)).toList();
      notifyListeners();
    });

    _hub.on('JoinRequest', (args) {
      if (args == null || args.isEmpty) return;
      final data = _d(args[0]);
      pendingRequests.add(PendingRequest(
        connId: data['requesterConnId'] as String,
        name: data['requesterName'] as String,
      ));
      notifyListeners();
    });

    _hub.on('JoinRequestSent', (_) {
      joinRequestStatus = 'waiting';
      notifyListeners();
    });

    _hub.on('JoinDeclined', (_) {
      joinRequestStatus = 'declined';
      notifyListeners();
    });

    _hub.on('Error', (args) {
      if (args == null || args.isEmpty) return;
      errorMsg = (_d(args[0]))['error'] as String?;
      _setPhase(OnlinePhase.error);
    });
  }

  // ── Sound mirroring ─────────────────────────────────────────────────────

  void _playSounds(OnlineRoom? prev, OnlineRoom next, String? msg) {
    if (msg == 'Game Over!' || prev == null) return;
    if (next.dicePool.length > prev.dicePool.length ||
        (prev.dicePool.isEmpty && next.dicePool.isNotEmpty)) {
      AudioService.play('rolling');
      if (next.canRoll) AudioService.play('extra_turn');
    }
    for (int pi = 0; pi < next.players.length; pi++) {
      if (pi >= prev.players.length) continue;
      final np = next.players[pi];
      final pp = prev.players[pi];
      for (int pci = 0; pci < np.pieces.length; pci++) {
        if (pci >= pp.pieces.length) continue;
        final npc = np.pieces[pci];
        final ppc = pp.pieces[pci];
        if (npc.state == ppc.state && npc.pos == ppc.pos) continue;
        if (npc.state == PieceState.home) {
          AudioService.play('reach_goal');
        } else if (npc.state == PieceState.prison ||
            (npc.state == PieceState.yard && ppc.state == PieceState.board)) {
          AudioService.play('hit_piece');
        } else {
          final sameColor = np.pieces
              .where((x) => x.id != npc.id && x.state == PieceState.board && x.pos == npc.pos)
              .length;
          AudioService.play(sameColor >= 1 ? 'block_border' : 'moving_piece');
        }
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _showToast(String msg) {
    toast = msg;
    notifyListeners();
    Timer(const Duration(milliseconds: 2200), () {
      toast = null;
      notifyListeners();
    });
  }

  void _setPhase(OnlinePhase p) {
    onlinePhase = p;
    notifyListeners();
  }

  Map<String, dynamic> _d(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
    return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  }
}
