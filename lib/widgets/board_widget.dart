import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/board_constants.dart';
import '../logic/game_logic.dart';
import '../logic/game_notifier.dart';
import '../models/game_models.dart';
import '../theme/app_theme.dart';
import 'piece_widget.dart';

class BoardWidget extends StatelessWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: [
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.06),
                  blurRadius: 30,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Stack(
              children: [
                _BoardGrid(size: size),
                const _PiecesLayer(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BoardGrid extends StatelessWidget {
  final double size;
  const _BoardGrid({required this.size});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    final cw = size / 15;
    final List<Widget> cells = [];

    final yardDefs = [
      {'id': 0, 'top': 0.6, 'left': 0.0, 'nameSide': 'left'},
      {'id': 1, 'top': 0.0, 'left': 0.0, 'nameSide': 'top'},
      {'id': 2, 'top': 0.0, 'left': 0.6, 'nameSide': 'right'},
      {'id': 3, 'top': 0.6, 'left': 0.6, 'nameSide': 'bottom'},
    ];
    for (final y in yardDefs) {
      final id = y['id'] as int;
      final isActive = game.players.isEmpty || game.players[id].isActive;
      cells.add(
        Positioned(
          top: (y['top'] as double) * size,
          left: (y['left'] as double) * size,
          width: size * 0.4,
          height: size * 0.4,
          child: Opacity(
            opacity: isActive ? 1.0 : 0.25,
            child: _YardCell(playerId: id, size: size * 0.4, game: game),
          ),
        ),
      );
      final playerName = game.players.isNotEmpty ? game.players[id].name : '';
      if (playerName.isNotEmpty) {
        cells.add(
          _PlayerNameLabel(
            name: playerName,
            color: kColors[id]!.main,
            yardTop: y['top'] as double,
            yardLeft: y['left'] as double,
            boardSize: size,
            playerId: id,
          ),
        );
      }
    }

    cells.add(
      Positioned(
        left: size * 0.4,
        top: size * 0.4,
        width: size * 0.2,
        height: size * 0.2,
        child: CustomPaint(painter: _CenterPainter()),
      ),
    );

    for (int i = 0; i < kPathCoords.length; i++) {
      final pos = kPathCoords[i];
      cells.add(
        Positioned(
          left: pos['x']! * cw,
          top: pos['y']! * cw,
          width: cw,
          height: cw,
          child: _PathCell(index: i, cw: cw),
        ),
      );
    }

    for (int colorId = 0; colorId < 4; colorId++) {
      final isActive = game.players.isEmpty || game.players[colorId].isActive;
      final stretches = kHomeStretches[colorId]!;
      for (int i = 0; i < stretches.length; i++) {
        final pos = stretches[i];
        cells.add(
          Positioned(
            left: pos['x']! * cw,
            top: pos['y']! * cw,
            width: cw,
            height: cw,
            child: Opacity(
              opacity: isActive ? 1.0 : 0.4,
              child: Container(
                decoration: BoxDecoration(
                  color: kColors[colorId]!.main,
                  border: Border.all(color: Colors.black),
                ),
                child: Center(
                  child: Icon(
                    Icons.star,
                    size: cw * 0.55,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Stack(children: cells);
  }
}

class _YardCell extends StatelessWidget {
  final int playerId;
  final double size;
  final GameNotifier game;
  const _YardCell({required this.playerId, required this.size, required this.game});

  @override
  Widget build(BuildContext context) {
    final color = kColors[playerId]!.main;
    final showLock = game.players.isNotEmpty &&
        game.phase == GamePhase.play &&
        (game.players[playerId].finished ||
            (!game.players[playerId].hasKilled &&
                !game.players[playerId].isHelper));
    final partnerId = (playerId + 2) % 4;
    final showHelper = game.players.isNotEmpty &&
        game.phase == GamePhase.play &&
        (game.players[playerId].isHelper ||
            game.players[partnerId].isHelper);
    final circleSize = size * 0.18;
    final innerSize = size * 0.667;
    final gap = (innerSize - circleSize * 2) / 3;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.9),
            color.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.167),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: gap,
                top: gap,
                child: _YardCircle(size: circleSize, color: color),
              ),
              Positioned(
                right: gap,
                top: gap,
                child: _YardCircle(size: circleSize, color: color),
              ),
              Positioned(
                left: gap,
                bottom: gap,
                child: _YardCircle(size: circleSize, color: color),
              ),
              Positioned(
                right: gap,
                bottom: gap,
                child: _YardCircle(size: circleSize, color: color),
              ),
              if (showLock)
                Center(
                  child: Opacity(
                    opacity: 0.4,
                    child: Icon(
                      Icons.lock,
                      color: Colors.black,
                      size: size * 0.3,
                    ),
                  ),
                ),
              if (showHelper)
                Center(
                  child: Opacity(
                    opacity: 0.4,
                    child: Icon(
                      Icons.people,
                      color: Colors.black,
                      size: size * 0.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YardCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _YardCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
}

class _PathCell extends StatelessWidget {
  final int index;
  final double cw;
  const _PathCell({required this.index, required this.cw});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Widget? content;
    if (kStartCells[0] == index) {
      bg = kColors[0]!.main;
    } else if (kStartCells[1] == index) {
      bg = kColors[1]!.main;
    } else if (kStartCells[2] == index) {
      bg = kColors[2]!.main;
    } else if (kStartCells[3] == index) {
      bg = kColors[3]!.main;
    }
    if (index == 8) {
      bg = kColors[1]!.main;
    }
    if (index == 21) {
      bg = kColors[2]!.main;
    }
    if (index == 34) {
      bg = kColors[3]!.main;
    }
    if (index == 47) {
      bg = kColors[0]!.main;
    }
    if (kSafeZones.contains(index)) {
      content = Icon(
        Icons.star,
        size: cw * 0.65,
        color: bg == Colors.white
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.6),
      );
    }
    if (index == 11) {
      content = Icon(Icons.chevron_right,
          size: cw * 0.85, color: kColors[1]!.main);
      bg = Colors.white;
    } else if (index == 24) {
      content = Icon(Icons.expand_more,
          size: cw * 0.85, color: kColors[2]!.main);
      bg = Colors.white;
    } else if (index == 37) {
      content = Icon(Icons.chevron_left,
          size: cw * 0.85, color: kColors[3]!.main);
      bg = Colors.white;
    } else if (index == 50) {
      content = Icon(Icons.expand_less,
          size: cw * 0.85, color: kColors[0]!.main);
      bg = Colors.white;
    }
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.black),
      ),
      child: content != null ? Center(child: content) : null,
    );
  }
}

class _CenterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    void tri(List<Offset> pts, Color c) {
      final p = Path()..addPolygon(pts, true);
      canvas.drawPath(p, Paint()..color = c);
      canvas.drawPath(p, stroke);
    }

    tri([Offset(0, 0), Offset(w, 0), Offset(w / 2, h / 2)],
        const Color(0xFFfacc15));
    tri([Offset(w, 0), Offset(w, h), Offset(w / 2, h / 2)],
        const Color(0xFF3b82f6));
    tri([Offset(0, h), Offset(w, h), Offset(w / 2, h / 2)],
        const Color(0xFFef4444));
    tri([Offset(0, 0), Offset(0, h), Offset(w / 2, h / 2)],
        const Color(0xFF22c55e));
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PiecesLayer extends StatelessWidget {
  const _PiecesLayer();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    if (game.players.isEmpty) return const SizedBox();
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: _buildPieces(game, constraints.maxWidth),
      ),
    );
  }

  List<Widget> _buildPieces(GameNotifier game, double size) {
    final cw = size / 15;
    final elements = <Widget>[];
    final selectableElements = <Widget>[];
    final groups = <String, List<Map<String, dynamic>>>{};
    final ctrlId = game.getControlPlayerId();
    final actId = game.activePlayerId;
    for (final p in game.players) {
      if (!p.isActive) continue;
      for (final pc in p.pieces) {
        final key =
            '${pc.state.name}-${pc.pos == -1 ? '${p.id}-${pc.id}' : pc.pos}-${pc.color}';
        groups.putIfAbsent(key, () => []);
        groups[key]!.add({'pc': pc, 'player': p});
      }
    }
    groups.forEach((_, group) {
      for (int index = 0; index < group.length; index++) {
        final pc = group[index]['pc'] as Piece;
        final p = group[index]['player'] as Player;
        bool isSelectable = false;
        if (p.id == ctrlId &&
            !game.players[actId].isAI &&
            game.phase == GamePhase.play &&
            game.selectedDieIndex != null &&
            game.dicePool.isNotEmpty) {
          final moveVal = game.dicePool[game.selectedDieIndex!];
          if (!pc.hasKilledThisTurn) {
            final dest = calculateDestination(
              p,
              pc,
              moveVal,
              game.players,
              pool: game.dicePool,
              dieIndex: game.selectedDieIndex!,
              settings: game.settings,
            );
            if (dest != null) isSelectable = true;
          }
        }
        final coord = _getPieceCoord(pc, cw);
        double cx = coord['cx']!;
        double cy = coord['cy']!;
        double offsetX = 0, offsetY = 0;
        if (group.length > 1 &&
            (pc.state == PieceState.board ||
                pc.state == PieceState.homeStretch)) {
          const offsets = [
            [-1.0, -1.0],
            [1.0, 1.0],
            [1.0, -1.0],
            [-1.0, 1.0],
            [0.0, -1.5],
            [0.0, 1.5],
            [-1.5, 0.0],
            [1.5, 0.0],
          ];
          final o = offsets[index % offsets.length];
          offsetX = o[0] * cw * 0.08;
          offsetY = o[1] * cw * 0.08;
        } else if (pc.state == PieceState.home) {
          offsetY = -(index * cw * 0.2);
        } else if (pc.state == PieceState.yard && group.length > 1) {
          final offsetPatterns = [
            [0.0, 0.0],
            [0.0, 0.0],
            [0.0, 0.0],
            [0.0, 0.0],
          ];
          final o = offsetPatterns[pc.id % offsetPatterns.length];
          offsetX = o[0];
          offsetY = o[1];
        }
        final double pieceSize = cw * 1;
        final entry = AnimatedPositioned(
          key: ValueKey('${pc.color}-${pc.id}'),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          left: cx + offsetX - pieceSize / 2,
          top: cy + offsetY - pieceSize / 2,
          width: pieceSize,
          height: pieceSize,
          child: PieceWidget(
            piece: pc,
            isSelectable: isSelectable,
            zIndex: isSelectable ? 40 : 20,
            onTap: () => game.handlePieceClick(pc),
          ),
        );
        if (isSelectable) {
          selectableElements.add(entry);
        } else {
          elements.add(entry);
        }
      }
    });
    elements.addAll(selectableElements);
    return elements;
  }

  Map<String, double> _getPieceCoord(Piece pc, double cw) {
    double x = 0, y = 0;
    if (pc.state == PieceState.yard) {
      final c = kYardCoords[pc.color]![pc.id];
      x = c['x']!.toDouble();
      y = c['y']!.toDouble();
      return {'cx': x * cw, 'cy': y * cw};
    } else if (pc.state == PieceState.prison) {
      final base = kPrisonCoords[pc.prisonerOf ?? pc.color]!;
      x = base['x']! + pc.id * 0.4;
      y = base['y']! + pc.id * 0.4;
    } else if (pc.state == PieceState.homeStretch) {
      final c = kHomeStretches[pc.color]![pc.pos];
      x = c['x']!.toDouble();
      y = c['y']!.toDouble();
    } else if (pc.state == PieceState.home) {
      final c = kHomeStackCoords[pc.color]!;
      x = c['x']!;
      y = c['y']!;
    } else if (pc.state == PieceState.board) {
      final c = kPathCoords[pc.pos];
      x = c['x']!.toDouble();
      y = c['y']!.toDouble();
    }
    return {'cx': (x + 0.5) * cw, 'cy': (y + 0.5) * cw};
  }
}

/// Player name label positioned INSIDE the yard area at the top.
/// All players have names at the top of their respective yards.
class _PlayerNameLabel extends StatelessWidget {
  final String name;
  final Color color;
  final double yardTop;
  final double yardLeft;
  final double boardSize;
  final int playerId;

  const _PlayerNameLabel({
    required this.name,
    required this.color,
    required this.yardTop,
    required this.yardLeft,
    required this.boardSize,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context) {
    final yardSize = boardSize * 0.4;
    final labelHeight = boardSize * 0.04;
    final labelWidth = yardSize * 0.65;

    final double top;
    if (playerId == 0 || playerId == 3) {
      top = (yardTop + 0.4) * boardSize - labelHeight - boardSize * 0.015;
    } else {
      top = yardTop * boardSize + boardSize * 0.015;
    }
    final left = yardLeft * boardSize + (yardSize - labelWidth) / 2;

    return Positioned(
      top: top,
      left: left,
      width: labelWidth,
      height: labelHeight,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.85)],
          ),
          borderRadius: BorderRadius.circular(labelHeight / 2),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: labelHeight * 0.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
