enum PieceState { yard, board, homeStretch, home, prison }

class Piece {
  final int id;
  final int color;
  PieceState state;
  int pos;
  int? prisonerOf;
  bool hasKilledThisTurn;

  Piece({
    required this.id,
    required this.color,
    this.state = PieceState.yard,
    this.pos = -1,
    this.prisonerOf,
    this.hasKilledThisTurn = false,
  });

  Piece copyWith({
    PieceState? state,
    int? pos,
    int? prisonerOf,
    bool clearPrisoner = false,
    bool? hasKilledThisTurn,
  }) {
    return Piece(
      id: id,
      color: color,
      state: state ?? this.state,
      pos: pos ?? this.pos,
      prisonerOf: clearPrisoner ? null : (prisonerOf ?? this.prisonerOf),
      hasKilledThisTurn: hasKilledThisTurn ?? this.hasKilledThisTurn,
    );
  }
}

class Player {
  final int id;
  final bool isAI;
  final bool isActive;
  final int partnerId;
  final String name;
  bool hasKilled;
  bool finished;
  bool isHelper;
  List<Piece> pieces;

  Player({
    required this.id,
    required this.isAI,
    required this.isActive,
    required this.partnerId,
    this.name = '',
    this.hasKilled = false,
    this.finished = false,
    this.isHelper = false,
    required this.pieces,
  });
}
