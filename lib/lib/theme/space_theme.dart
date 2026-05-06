import 'package:flutter/material.dart';

class SpaceTheme {
  static const Color bgDark = Color(0xFF0B1033);
  static const Color panelBorder = Color(0xFF4DBBFF);
  
  static BoxDecoration get panelDecoration => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF174391), Color(0xFF0F265C)],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: panelBorder, width: 2),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, 6)),
      BoxShadow(color: panelBorder.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
    ],
  );

  static BoxDecoration buttonDecoration({bool isPurple = false}) {
    final colors = isPurple 
      ? const [Color(0xFFB057FF), Color(0xFF7524DD)]
      : const [Color(0xFF38BDF8), Color(0xFF0284C7)];
    final borderColor = isPurple ? const Color(0xFFE8B4FF) : const Color(0xFFBAE6FD);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor, width: 1.5),
      boxShadow: [
        BoxShadow(color: colors[1].withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 4)),
      ],
    );
  }

  static Widget glossyOverlay(double width, double height, double radius) {
    return Positioned(
      top: 0, left: 0, right: 0, height: height * 0.4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }

  static CustomPaint backgroundStars() {
    return CustomPaint(
      painter: _StarPainter(),
      size: Size.infinite,
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final stars = [
      Offset(size.width * 0.1, size.height * 0.2), Offset(size.width * 0.8, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.4), Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.9, size.height * 0.8), Offset(size.width * 0.6, size.height * 0.9),
      Offset(size.width * 0.3, size.height * 0.5), Offset(size.width * 0.7, size.height * 0.6),
      Offset(size.width * 0.15, size.height * 0.85), Offset(size.width * 0.85, size.height * 0.35),
    ];
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      canvas.drawCircle(s, (i % 3) + 1.0, paint..color = Colors.white.withValues(alpha: 0.3 + (i % 5) * 0.1));
    }
  }
  @override bool shouldRepaint(_) => false;
}
