import 'dart:math' show pi;
import 'package:flutter/material.dart';

// Dot grid positions for each face value (row, col) in a 3x3 grid (0-indexed)
const _dotPositions = {
  1: [(1, 1)],
  2: [(0, 0), (2, 2)],
  3: [(0, 0), (1, 1), (2, 2)],
  4: [(0, 0), (0, 2), (2, 0), (2, 2)],
  5: [(0, 0), (0, 2), (1, 1), (2, 0), (2, 2)],
  6: [(0, 0), (0, 2), (1, 0), (1, 2), (2, 0), (2, 2)],
};

// Target rotations (rx, ry in radians) to show each face value on front
const _faceRotations = {
  1: (0.0, 0.0),
  6: (0.0, pi),
  3: (0.0, -pi / 2),
  4: (0.0, pi / 2),
  2: (-pi / 2, 0.0),
  5: (pi / 2, 0.0),
};

class DiceWidget extends StatefulWidget {
  final int value;
  final bool isRolling;
  final double size;
  final bool flipped;

  const DiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    this.size = 52,
    this.flipped = false,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rollAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _rollAnim = Tween<double>(begin: 0, end: 2 * pi).animate(_ctrl);
  }

  @override
  void didUpdateWidget(DiceWidget old) {
    super.didUpdateWidget(old);
    if (widget.isRolling && !old.isRolling) {
      _ctrl.repeat();
    } else if (!widget.isRolling && old.isRolling) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final half = s / 2;

    if (widget.isRolling) {
      return AnimatedBuilder(
        animation: _rollAnim,
        builder: (_, __) {
          final t = _rollAnim.value;
          return _buildDiceFace(
            s,
            rx: t,
            ry: t,
            translateY: -10 * (0.5 - (t / (2 * pi) - (t / (2 * pi)).floor() - 0.5).abs()),
            value: widget.value,
            half: half,
          );
        },
      );
    }

    final rot = _faceRotations[widget.value] ?? (0.0, 0.0);
    return _buildDiceFace(s, rx: rot.$1, ry: rot.$2, translateY: 0, value: widget.value, half: half);
  }

  Widget _buildDiceFace(double s, {
    required double rx,
    required double ry,
    required double translateY,
    required int value,
    required double half,
  }) {
    return SizedBox(
      width: s,
      height: s,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..translate(0.0, translateY)
          ..rotateX(rx)
          ..rotateY(ry),
        child: _DiceFace(value: value, size: s),
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  final int value;
  final double size;

  const _DiceFace({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    final dots = _dotPositions[value] ?? [];
    final dotSize = size * 0.18;
    final padding = size * 0.12;
    final cellSize = (size - padding * 2) / 3;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: const Color(0xFFeeeeee), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 4)),
          BoxShadow(color: Colors.black12, blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: dots.map((pos) {
          final row = pos.$1;
          final col = pos.$2;
          return Positioned(
            left: padding + col * cellSize + (cellSize - dotSize) / 2,
            top: padding + row * cellSize + (cellSize - dotSize) / 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  colors: [Color(0xFF444444), Color(0xFF000000)],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
