import 'game_models.dart';

class MoveDestination {
  final bool valid;
  final PieceState targetState;
  final int targetPos;

  const MoveDestination({
    required this.valid,
    required this.targetState,
    required this.targetPos,
  });
}
