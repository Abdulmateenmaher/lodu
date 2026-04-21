import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/board_constants.dart';
import '../models/game_models.dart';
import '../models/game_settings.dart';
import '../models/move_destination.dart';
import '../logic/game_logic.dart';

import '../models/match_record.dart';

enum GamePhase { setup, play, end }

class GameNotifier extends ChangeNotifier {
  GamePhase phase = GamePhase.setup;
  List<Player> players = [];
  int turnSlot = 0;
  List<int> dicePool = [];
  int consecutiveExtra = 0;
  bool canRoll = false;
  int? selectedDieIndex;
  bool isRolling = false;
  bool _aiTurnActive = false; // prevents AI re-entrant scheduling
  String? toast;
  GameSettings settings = const GameSettings();
  final List<MatchRecord> history = [];

  void updateSettings(GameSettings s) {
    settings = s;
    notifyListeners();
  }

  void startGame(List<Map<String, dynamic>> configs) {
    players = List.generate(
      4,
      (id) => Player(
        id: id,
        isAI: configs[id]['isAI'] as bool,
        isActive: true,
        partnerId: (id + 2) % 4,
        name: configs[id]['name'] as String? ?? '',
        pieces: List.generate(4, (pId) => Piece(id: pId, color: id)),
      ),
    );
    turnSlot = 0;
    dicePool = [];
    consecutiveExtra = 0;
    canRoll = true;
    selectedDieIndex = null;
    _aiTurnActive = false;
    phase = GamePhase.play;
    _showToast('Match Started!');
    notifyListeners();

    // Kick off AI if first player is AI
    if (players[0].isAI) {
      Timer(const Duration(milliseconds: 600), rollDice);
    }
  }

  void leaveMatch() {
    resetToSetup();
  }

  void _showToast(String msg, [int ms = 2000]) {
    toast = msg;
    notifyListeners();
    Timer(Duration(milliseconds: ms), () {
      toast = null;
      notifyListeners();
    });
  }

  int get activePlayerId => turnSlot;

  int getControlPlayerId([List<Player>? p]) {
    final ps = p ?? players;
    final act = ps[turnSlot];
    if (act.finished && act.isHelper) return act.partnerId;
    return act.id;
  }

  void _autoSelectDie() {
    if (dicePool.isEmpty) {
      selectedDieIndex = null;
      return;
    }
    selectedDieIndex = 0;
  }

  void rollDice() {
    if (!canRoll || isRolling) return;
    isRolling = true;
    canRoll = false;
    notifyListeners();

    Timer(const Duration(milliseconds: 350), () {
      final actId = activePlayerId;
      final newPlayers = _deepCopyPlayers(players);
      final activeP = newPlayers[actId];

      final d1 = Random().nextInt(6) + 1;
      final d2 = Random().nextInt(6) + 1;

      if (activeP.finished && !activeP.isHelper) {
        if (d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1)) {
          activeP.isHelper = true;
        } else {
          isRolling = false;
          players = newPlayers;
          notifyListeners();
          Timer(const Duration(milliseconds: 700), () => _endTurn(newPlayers));
          return;
        }
      }

      bool extra = false;
      final newPool = List<int>.from(dicePool);
      final isDoubleSix = d1 == 6 && d2 == 6;
      final isDoubleOne = d1 == 1 && d2 == 1;

      if (settings.doubleSixBonus && (isDoubleSix || isDoubleOne)) {
        extra = consecutiveExtra < 3;
        newPool.addAll([6, 6]);
      } else {
        newPool.addAll([d1, d2]);
      }
      newPool.sort((a, b) => b.compareTo(a));

      if (d1 == d2 && (d1 == 6 || d1 == 1)) {
        extra = true;
      }

      isRolling = false;
      players = newPlayers;
      dicePool = newPool;
      consecutiveExtra = extra ? consecutiveExtra + 1 : 0;
      canRoll = extra;
      selectedDieIndex = dicePool.isEmpty ? null : 0;
      notifyListeners();

      Timer(const Duration(milliseconds: 140), () {
        _checkAndAutoPlay(newPool, newPlayers, extra);
      });
    });
  }

  void _checkAndAutoPlay(
    List<int> pool,
    List<Player> currentPlayers,
    bool currentCanRoll,
  ) {
    // Snapshot the turn so stale callbacks don't act on a new turn
    final snapSlot = turnSlot;
    final actId = snapSlot;
    final actPlayer = currentPlayers[actId];
    final ctrlId = actPlayer.finished && actPlayer.isHelper
        ? actPlayer.partnerId
        : actPlayer.id;
    final pCtrl = currentPlayers[ctrlId];

    if (actPlayer.isAI) {
      if (_aiTurnActive) return;
      _aiTurnActive = true;

      if (currentCanRoll) {
        // Extra roll (double-six bonus) — roll again
        Timer(const Duration(milliseconds: 490), () {
          if (turnSlot != snapSlot) {
            _aiTurnActive = false;
            return;
          }
          _aiTurnActive = false;
          rollDice();
        });
        return;
      }

      if (pCtrl.finished && !pCtrl.isHelper) {
        Timer(const Duration(milliseconds: 350), () {
          _aiTurnActive = false;
          _endTurn(currentPlayers);
        });
        return;
      }

      final allMoves = getAllValidMoves(pCtrl, pool, currentPlayers, settings);
      if (allMoves.isNotEmpty) {
        allMoves.sort((a, b) {
          final aKills =
              a.target.targetState == PieceState.board &&
              !_effectiveSafeZones.contains(a.target.targetPos) &&
              hasOpponent(a.target.targetPos, ctrlId, currentPlayers);
          final bKills =
              b.target.targetState == PieceState.board &&
              !_effectiveSafeZones.contains(b.target.targetPos) &&
              hasOpponent(b.target.targetPos, ctrlId, currentPlayers);
          if (aKills && !bKills) return -1;
          if (bKills && !aKills) return 1;
          return b.dieValue - a.dieValue;
        });
        final best = allMoves.first;
        Timer(const Duration(milliseconds: 420), () {
          if (turnSlot != snapSlot) {
            _aiTurnActive = false;
            return;
          }
          _aiTurnActive = false;
          _executeMove(
            best.piece,
            best.target,
            best.dieIndex,
            currentPlayers,
            pool,
            currentCanRoll,
          );
        });
      } else {
        Timer(const Duration(milliseconds: 420), () {
          _aiTurnActive = false;
          _endTurn(currentPlayers);
        });
      }
      return;
    }

    // ── Human player ──────────────────────────────────────────────────────
    if (pCtrl.finished && !pCtrl.isHelper) {
      Timer(const Duration(milliseconds: 280), () => _endTurn(currentPlayers));
      return;
    }

    final allMoves = getAllValidMoves(pCtrl, pool, currentPlayers, settings);

    if (allMoves.isEmpty && !currentCanRoll && pool.isNotEmpty) {
      Timer(const Duration(milliseconds: 1120), () => _endTurn(currentPlayers));
      return;
    }

    if (!settings.autoMoveUnambiguous) return;

    // Auto-move: 1 die left, 1 valid move
    if (pool.length == 1 && allMoves.length == 1 && !currentCanRoll) {
      final only = allMoves.first;
      Timer(const Duration(milliseconds: 420), () {
        _executeMove(
          only.piece,
          only.target,
          only.dieIndex,
          currentPlayers,
          pool,
          currentCanRoll,
        );
      });
      return;
    }

    // Auto-move: 2 dice, all pieces in yard, one die is 6
    if (pool.length == 2 && !currentCanRoll) {
      final has6 = pool.contains(6);
      final allInYard = pCtrl.pieces.every(
        (pc) =>
            pc.state == PieceState.yard ||
            pc.state == PieceState.prison ||
            pc.state == PieceState.home,
      );
      if (has6 && allInYard) {
        final sixIdx = pool.indexOf(6);
        final movesFor6 = <AiMove>[];
        for (final pc in pCtrl.pieces) {
          if (pc.state == PieceState.home || pc.hasKilledThisTurn) continue;
          final dest = calculateDestination(
            pCtrl,
            pc,
            6,
            currentPlayers,
            pool: pool,
            dieIndex: sixIdx,
            settings: settings,
          );
          if (dest != null)
            movesFor6.add(
              AiMove(piece: pc, target: dest, dieIndex: sixIdx, dieValue: 6),
            );
        }
        if (movesFor6.length == 1) {
          final bring = movesFor6.first;
          Timer(const Duration(milliseconds: 420), () {
            _executeMove(
              bring.piece,
              bring.target,
              bring.dieIndex,
              currentPlayers,
              pool,
              currentCanRoll,
            );
          });
          return;
        }
      }
    }

    // Auto-combine: exactly 1 piece on board, 2 dice
    if (pool.length == 2 && !currentCanRoll) {
      final boardPieces = pCtrl.pieces
          .where((pc) => pc.state == PieceState.board && !pc.hasKilledThisTurn)
          .toList();
      if (boardPieces.length == 1) {
        final combined = pool[0] + pool[1];
        final combinedDest = calculateDestSimple(
          pCtrl,
          boardPieces.first,
          combined,
          currentPlayers,
          settings,
        );
        if (combinedDest != null) {
          final largerIdx = 0;
          final largerMoves = <AiMove>[];
          for (final pc in pCtrl.pieces) {
            if (pc.state == PieceState.home || pc.hasKilledThisTurn) continue;
            final dest = calculateDestination(
              pCtrl,
              pc,
              pool[largerIdx],
              currentPlayers,
              pool: pool,
              dieIndex: largerIdx,
              settings: settings,
            );
            if (dest != null)
              largerMoves.add(
                AiMove(
                  piece: pc,
                  target: dest,
                  dieIndex: largerIdx,
                  dieValue: pool[largerIdx],
                ),
              );
          }
          if (largerMoves.length == 1) {
            final mv = largerMoves.first;
            Timer(const Duration(milliseconds: 420), () {
              _executeMove(
                mv.piece,
                mv.target,
                mv.dieIndex,
                currentPlayers,
                pool,
                currentCanRoll,
              );
            });
          }
        }
      }
    }
  }

  List<int> get _effectiveSafeZones =>
      settings.safeZonesEnabled ? kSafeZones : [];

  String _nameOf(Player p) {
    if (p.name.isNotEmpty) return p.name;
    return p.isAI ? 'Bot ${kColors[p.id]!.name}' : kColors[p.id]!.name;
  }

  void handleDieClick(int index) {
    if (players[activePlayerId].isAI || isRolling) return;
    if (index >= dicePool.length) return;
    selectedDieIndex = index;
    notifyListeners();
  }

  void handlePieceClick(Piece piece) {
    final actId = activePlayerId;
    final ctrlId = getControlPlayerId(players);
    if (piece.color != ctrlId || isRolling || players[actId].isAI) return;
    if (selectedDieIndex == null || piece.hasKilledThisTurn) return;

    final pCtrl = players[ctrlId];
    final moveVal = dicePool[selectedDieIndex!];
    final dest = calculateDestination(
      pCtrl,
      piece,
      moveVal,
      players,
      pool: dicePool,
      dieIndex: selectedDieIndex!,
      settings: settings,
    );
    if (dest != null) {
      _executeMove(piece, dest, selectedDieIndex!, players, dicePool, canRoll);
    }
  }

  void _executeMove(
    Piece piece,
    MoveDestination target,
    int dieIndexUsed,
    List<Player> currentPlayers,
    List<int> currentPool,
    bool currentCanRoll,
  ) {
    final newPlayers = _deepCopyPlayers(currentPlayers);
    final ctrlId = getControlPlayerId(currentPlayers);
    final pCtrl = newPlayers[ctrlId];
    final pPiece = pCtrl.pieces.firstWhere(
      (pc) => pc.id == piece.id && pc.color == piece.color,
    );

    pPiece.state = target.targetState;
    pPiece.pos = target.targetPos;

    bool rewardTurn = currentCanRoll;
    if (target.targetState == PieceState.home) rewardTurn = true;

    final newPool = List<int>.from(currentPool)..removeAt(dieIndexUsed);

    if (target.targetState == PieceState.board &&
        !_effectiveSafeZones.contains(target.targetPos)) {
      for (final op in newPlayers) {
        if (op.id != ctrlId && op.id != pCtrl.partnerId) {
          for (final opc in op.pieces) {
            if (opc.state == PieceState.board && opc.pos == target.targetPos) {
              if (settings.prisonRule) {
                opc.state = PieceState.prison;
                opc.pos = -2;
                opc.prisonerOf = ctrlId;
              } else {
                opc.state = PieceState.yard;
                opc.pos = -1;
                opc.prisonerOf = null;
              }
              pCtrl.hasKilled = true;
              pPiece.hasKilledThisTurn = true;
            }
          }
        }
      }
    }

    if (!settings.killToEnter) pCtrl.hasKilled = true;

    final justFinished =
        !pCtrl.finished &&
        pCtrl.pieces.every((pc) => pc.state == PieceState.home);
    if (justFinished) pCtrl.finished = true;

    players = newPlayers;
    dicePool = newPool;
    canRoll = rewardTurn;
    _autoSelectDie();

    final team1Done = newPlayers[0].finished && newPlayers[2].finished;
    final team2Done = newPlayers[1].finished && newPlayers[3].finished;
    final gameOver =
        (settings.teamPlay && (team1Done || team2Done)) ||
        (!settings.teamPlay && newPlayers.any((p) => p.finished));

    if (gameOver) {
      // Record history
      final winLabel = team1Done
          ? '${_nameOf(newPlayers[0])} & ${_nameOf(newPlayers[2])}'
          : '${_nameOf(newPlayers[1])} & ${_nameOf(newPlayers[3])}';
      history.add(
        MatchRecord(
          winnerLabel: winLabel,
          playerNames: newPlayers.map(_nameOf).toList(),
          playerIsAI: newPlayers.map((p) => p.isAI).toList(),
          playedAt: DateTime.now(),
        ),
      );
      phase = GamePhase.end;
      notifyListeners();
      return;
    }

    // If the active player just finished their last piece this move,
    // end their turn immediately — don't let reward roll bleed to partner
    if (justFinished) {
      dicePool = [];
      canRoll = false;
      notifyListeners();
      Timer(const Duration(milliseconds: 300), () => _endTurn(newPlayers));
      return;
    }

    notifyListeners();

    if (newPool.isEmpty && !rewardTurn) {
      Timer(const Duration(milliseconds: 210), () => _endTurn(newPlayers));
    } else {
      Timer(const Duration(milliseconds: 140), () {
        _checkAndAutoPlay(newPool, newPlayers, rewardTurn);
      });
    }
  }

  void _endTurn([List<Player>? latestPlayers]) {
    _aiTurnActive = false;
    final ps = latestPlayers ?? players;
    final newPlayers = _deepCopyPlayers(ps);
    for (final p in newPlayers) {
      for (final pc in p.pieces) {
        pc.hasKilledThisTurn = false;
      }
    }
    players = newPlayers;
    turnSlot = (turnSlot + 1) % 4;
    dicePool = [];
    consecutiveExtra = 0;
    canRoll = true;
    selectedDieIndex = null;
    notifyListeners();

    // If next player is AI, kick off their turn
    if (players[turnSlot].isAI) {
      Timer(const Duration(milliseconds: 560), rollDice);
    }
  }

  void resetToSetup() {
    phase = GamePhase.setup;
    players = [];
    dicePool = [];
    notifyListeners();
  }

  List<Player> _deepCopyPlayers(List<Player> source) {
    return source
        .map(
          (p) => Player(
            id: p.id,
            isAI: p.isAI,
            isActive: p.isActive,
            partnerId: p.partnerId,
            name: p.name,
            hasKilled: p.hasKilled,
            finished: p.finished,
            isHelper: p.isHelper,
            pieces: p.pieces
                .map(
                  (pc) => Piece(
                    id: pc.id,
                    color: pc.color,
                    state: pc.state,
                    pos: pc.pos,
                    prisonerOf: pc.prisonerOf,
                    hasKilledThisTurn: pc.hasKilledThisTurn,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }
}
