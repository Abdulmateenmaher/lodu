import '../constants/board_constants.dart';
import '../models/game_models.dart';
import '../models/game_settings.dart';
import '../models/move_destination.dart';

List<int> effectiveSafeZones(GameSettings s) =>
    s.safeZonesEnabled ? kSafeZones : [];

bool isCellBlocked(int cellIdx, int movingColor, List<Player> players) {
  final counts = {0: 0, 1: 0, 2: 0, 3: 0};
  for (final p in players) {
    for (final pc in p.pieces) {
      if (pc.state == PieceState.board && pc.pos == cellIdx) {
        counts[p.id] = (counts[p.id] ?? 0) + 1;
      }
    }
  }
  final partnerId = (movingColor + 2) % 4;
  for (int i = 0; i < 4; i++) {
    if (i != movingColor && i != partnerId && (counts[i] ?? 0) >= 2) {
      return true;
    }
  }
  return false;
}

bool hasOpponent(int pos, int myColor, List<Player> players) {
  final partnerId = (myColor + 2) % 4;
  for (final p in players) {
    if (p.id != myColor && p.id != partnerId) {
      if (p.pieces.any((pc) => pc.state == PieceState.board && pc.pos == pos)) {
        return true;
      }
    }
  }
  return false;
}

bool hasSameColorPiece(int pos, int myColor, List<Player> players) {
  for (final p in players) {
    if (p.id == myColor) {
      if (p.pieces.any((pc) => pc.state == PieceState.board && pc.pos == pos)) {
        return true;
      }
    }
  }
  return false;
}

MoveDestination? calculateDestSimple(
  Player player,
  Piece piece,
  int moveVal,
  List<Player> players,
  GameSettings settings,
  List<int> pool,
) {
  final safeZones = effectiveSafeZones(settings);

  if (piece.state == PieceState.yard) {
    if (moveVal == 6 && pool.isNotEmpty) {
      return MoveDestination(
        valid: true,
        targetState: PieceState.board,
        targetPos: kStartCells[player.id]!,
      );
    }
    return null;
  }
  if (piece.state == PieceState.prison) {
    if (!settings.prisonRule) return null;
    if (moveVal == 6 && pool.isNotEmpty) {
      return MoveDestination(
        valid: true,
        targetState: PieceState.yard,
        targetPos: -1,
      );
    }
    return null;
  }
  if (piece.state == PieceState.home) return null;

  if (piece.state == PieceState.homeStretch) {
    final remaining = 5 - piece.pos;
    if (moveVal == remaining) {
      return MoveDestination(
        valid: true,
        targetState: PieceState.home,
        targetPos: 999,
      );
    }
    if (moveVal < remaining) {
      return MoveDestination(
        valid: true,
        targetState: PieceState.homeStretch,
        targetPos: piece.pos + moveVal,
      );
    }
    return null;
  }

  if (piece.state == PieceState.board) {
    int curr = piece.pos;
    for (int step = 1; step <= moveVal; step++) {
      if (curr == kWhiteSquares[player.id]) {
        final canEnter = !settings.killToEnter || player.hasKilled;
        if (canEnter) {
          final remaining = moveVal - step;
          if (remaining == 5) {
            return MoveDestination(
              valid: true,
              targetState: PieceState.home,
              targetPos: 999,
            );
          }
          if (remaining < 5) {
            return MoveDestination(
              valid: true,
              targetState: PieceState.homeStretch,
              targetPos: remaining,
            );
          }
          return null;
        } else {
          return null;
        }
      }
      curr = (curr + 1) % 52;

      // Check if the cell is blocked - only on colored squares for non-partners
      if (safeZones.contains(curr)) {
        // Block on colored squares if 2+ pieces of same yard color, but not for the owner or partner
        int? owner;
        for (int i = 0; i < 4; i++) {
          if (kMyStops[i]?.contains(curr) ?? false) {
            owner = i;
            break;
          }
        }
        final partnerId = (player.id + 2) % 4;
        if (owner != null && owner != player.id && owner != partnerId) {
          int ownPieces = 0;
          for (final pc in players[owner].pieces) {
            if (pc.state == PieceState.board && pc.pos == curr) {
              ownPieces++;
            }
          }
          if (ownPieces >= 2) return null;
        }
      }
    }

    final targetPos = curr;

    return MoveDestination(
      valid: true,
      targetState: PieceState.board,
      targetPos: targetPos,
    );
  }
  return null;
}

MoveDestination? calculateDestination(
  Player player,
  Piece piece,
  int moveVal,
  List<Player> players, {
  List<int> pool = const [],
  int dieIndex = -1,
  GameSettings settings = const GameSettings(),
}) {
  final dest = calculateDestSimple(player, piece, moveVal, players, settings, pool);
  if (dest == null) return null;

  final safeZones = effectiveSafeZones(settings);
  if (dest.targetState == PieceState.board &&
      !safeZones.contains(dest.targetPos) &&
      hasOpponent(dest.targetPos, player.id, players)) {
    if (pool.length > 1 && dieIndex != -1) {
      final remainingPool = List<int>.from(pool)..removeAt(dieIndex);
      bool hasAnyOtherMove = false;
      outer:
      for (final rVal in remainingPool) {
        for (final p in player.pieces) {
          if (p.id == piece.id) continue;
          if (p.state == PieceState.home || p.hasKilledThisTurn) continue;
          final d = calculateDestSimple(player, p, rVal, players, settings, remainingPool);
          if (d != null) {
            hasAnyOtherMove = true;
            break outer;
          }
        }
      }
      if (!hasAnyOtherMove) return null;
    }
  }
  // Avoid stacking on own white square if possible
  if (dest.targetState == PieceState.board &&
      dest.targetPos == kWhiteSquares[player.id] &&
      hasSameColorPiece(dest.targetPos, player.id, players)) {
    if (pool.length > 1 && dieIndex != -1) {
      final remainingPool = List<int>.from(pool)..removeAt(dieIndex);
      bool hasAnyOtherMove = false;
      outer:
      for (final rVal in remainingPool) {
        for (final p in player.pieces) {
          if (p.id == piece.id) continue;
          if (p.state == PieceState.home || p.hasKilledThisTurn) continue;
          final d = calculateDestSimple(player, p, rVal, players, settings, remainingPool);
          if (d != null) {
            hasAnyOtherMove = true;
            break outer;
          }
        }
      }
      if (hasAnyOtherMove) return null;
    }
  }
  return dest;
}

class AiMove {
  final Piece piece;
  final MoveDestination target;
  final List<int> dieIndices;
  final int dieValue;
  AiMove({
    required this.piece,
    required this.target,
    required this.dieIndices,
    required this.dieValue,
  });
}

List<AiMove> getAllValidMoves(
  Player player,
  List<int> pool,
  List<Player> players,
  GameSettings settings,
) {
  final List<AiMove> moves = [];
  final List<AiMove> combinedMoves = [];
  
  // Single die moves
  for (int i = 0; i < pool.length; i++) {
    for (final pc in player.pieces) {
      if (pc.state == PieceState.home || pc.hasKilledThisTurn) continue;
      final dest = calculateDestination(
        player,
        pc,
        pool[i],
        players,
        pool: pool,
        dieIndex: i,
        settings: settings,
      );
      if (dest != null) {
        moves.add(
          AiMove(piece: pc, target: dest, dieIndices: [i], dieValue: pool[i]),
        );
      }
    }
  }
  
  // 🔥 ENHANCED: Combined moves for pairs - ALWAYS generate these alongside singles
  // AI should consider sum-of-dice moves as alternatives, not just fallback
  if (pool.length >= 2) {
    for (int i = 0; i < pool.length; i++) {
      for (int j = i + 1; j < pool.length; j++) {
        int sum = pool[i] + pool[j];
        for (final pc in player.pieces) {
          if (pc.state == PieceState.home || pc.hasKilledThisTurn) continue;
          final dest = calculateDestination(
            player,
            pc,
            sum,
            players,
            pool: [], // no blocking for combined
            dieIndex: -1,
            settings: settings,
          );
          if (dest != null) {
            combinedMoves.add(
              AiMove(piece: pc, target: dest, dieIndices: [i, j], dieValue: sum),
            );
          }
        }
      }
    }
  }
  
  // If no single moves exist, use combined moves
  // If single moves exist, also include combined moves for AI evaluation
  if (moves.isEmpty) {
    return combinedMoves;
  } else {
    // Include combined moves alongside singles for richer AI evaluation
    moves.addAll(combinedMoves);
    return moves;
  }
}