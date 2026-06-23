import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A dark background widget that renders a subtle grid network visualization.
///
/// **Performance**: The grid is rendered once into an offscreen [ui.Picture]
/// and cached — subsequent frames only blit the cached picture (~1 µs per
/// frame).  No per‑frame allocation, no blur filters.
class GlowingGridBackground extends StatelessWidget {
  /// Spacing between grid cells.
  final double gridSize;

  /// Overall opacity multiplier (0.0 – 1.0).
  final double globalOpacity;

  const GlowingGridBackground({
    super.key,
    this.gridSize = 28,
    this.globalOpacity = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CachedGridPainter(
          gridSize: gridSize,
          globalOpacity: globalOpacity,
        ),
        size: Size.infinite,
        isComplex: false,
        willChange: false,
      ),
    );
  }
}

// ── Color pairs ─────────────────────────────────────────────────────────────

const _colorPairs = <List<Color>>[
  [Color(0xFFC8B4E6), Color(0xFFB4BEF0)], // Lavender & Periwinkle
  [Color(0xFFFFC8D2), Color(0xFFFFD2BE)], // Soft Pink & Peach
  [Color(0xFFBEE6D2), Color(0xFFAADCDC)], // Mint & Teal
  [Color(0xFFDCB4C8), Color(0xFFC8B4C8)], // Rose & Mauve
  [Color(0xFFB4D2F0), Color(0xFFC8D7F5)], // Sky & Baby Blue
];
const _pairCount = 5;

// ── Cached painter ──────────────────────────────────────────────────────────

class _CachedGridPainter extends CustomPainter {
  final double gridSize;
  final double globalOpacity;

  _CachedGridPainter({required this.gridSize, required this.globalOpacity});

  // Cached picture — built once, replayed forever.
  ui.Picture? _cachedPicture;
  Size _cachedSize = Size.zero;

  ui.Picture _buildPicture(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0a0f1e),
    );

    final cols = (size.width / gridSize).ceil() + 1;
    final rows = (size.height / gridSize).ceil() + 1;
    final count = cols * rows;

    // Edges
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final nodeGlow = Paint()..style = PaintingStyle.fill;
    final nodeCore = Paint()..style = PaintingStyle.fill;
    final vertexPaint = Paint()..style = PaintingStyle.fill;

    for (int rIdx = 0; rIdx < rows; rIdx++) {
      for (int cIdx = 0; cIdx < cols; cIdx++) {
        final i = rIdx * cols + cIdx;
        final x = cIdx * gridSize;
        final y = rIdx * gridSize;
        final pairIdx = (cIdx + rIdx) % _pairCount;
        final colorIdx = cIdx % 2;
        final color = _colorPairs[pairIdx][colorIdx];
        final opacity = globalOpacity;

        // Edges
        if (cIdx + 1 < cols) {
          final nx = (cIdx + 1) * gridSize;
          final ri = rIdx * cols + (cIdx + 1);
          final riColor = _colorPairs[((cIdx + 1) + rIdx) % _pairCount][(cIdx + 1) % 2];
          edgePaint.color = Color.fromARGB(
            (0.35 * opacity * 255).round().clamp(0, 255),
            (color.red + riColor.red) ~/ 2,
            (color.green + riColor.green) ~/ 2,
            (color.blue + riColor.blue) ~/ 2,
          );
          canvas.drawLine(Offset(x, y), Offset(nx, y), edgePaint);
        }
        if (rIdx + 1 < rows) {
          final ny = (rIdx + 1) * gridSize;
          final bi = (rIdx + 1) * cols + cIdx;
          final biColor = _colorPairs[(cIdx + (rIdx + 1)) % _pairCount][cIdx % 2];
          edgePaint.color = Color.fromARGB(
            (0.35 * opacity * 255).round().clamp(0, 255),
            (color.red + biColor.red) ~/ 2,
            (color.green + biColor.green) ~/ 2,
            (color.blue + biColor.blue) ~/ 2,
          );
          canvas.drawLine(Offset(x, y), Offset(x, ny), edgePaint);
        }

        // Node glow (multi-radius, no blur)
        final alpha = (0.45 * opacity * 255).round().clamp(0, 255);
        final baseColor = Color.fromARGB(alpha, color.red, color.green, color.blue);
        nodeGlow.color = baseColor.withValues(alpha: 0.12);
        canvas.drawCircle(Offset(x, y), 5.0, nodeGlow);
        nodeGlow.color = baseColor.withValues(alpha: 0.25);
        canvas.drawCircle(Offset(x, y), 3.5, nodeGlow);
        nodeCore.color = baseColor;
        canvas.drawCircle(Offset(x, y), 2.2, nodeCore);

        // Vertex
        vertexPaint.color = Color.fromARGB(
          (0.25 * opacity * 255).round().clamp(0, 255),
          color.red, color.green, color.blue,
        );
        canvas.drawCircle(Offset(x, y), 1.2, vertexPaint);
      }
    }

    return recorder.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedPicture == null || _cachedSize != size) {
      _cachedPicture?.dispose();
      _cachedPicture = _buildPicture(size);
      _cachedSize = size;
    }
    canvas.drawPicture(_cachedPicture!);
  }

  @override
  bool shouldRepaint(covariant _CachedGridPainter oldDelegate) {
    // Rebuild only if parameters changed or size changed (handled in paint())
    return oldDelegate.gridSize != gridSize ||
        oldDelegate.globalOpacity != globalOpacity;
  }
}