import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/colors.dart';

// ── Custom Barcode Vector Painter ─────────────────────────────────────────────
class BarcodePainter extends CustomPainter {
  final String code;
  BarcodePainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.fill;

    // Use a robust deterministic mapping of the string characters
    // to draw a high-fidelity barcode structure.
    final List<int> widths = [];
    for (int i = 0; i < code.length; i++) {
      final char = code.codeUnitAt(i);
      // Map char values to standard width patterns
      widths.addAll([
        (char % 2 == 0) ? 1 : 2,
        (char % 3 == 0) ? 3 : 1,
        (char % 5 == 0) ? 2 : 1,
        ((char + i) % 4 == 0) ? 4 : 2,
        1, // white line spacing
      ]);
    }

    // Always pad with leading and trailing code standard marks
    final List<int> finalPattern = [2, 1, 1, 2, 1]; // Start guard
    finalPattern.addAll(widths);
    finalPattern.addAll([2, 1, 2, 1, 1]); // Stop guard

    double totalPatternWidth = 0.0;
    for (final width in finalPattern) {
      totalPatternWidth += width;
    }

    final barUnitWidth = size.width / totalPatternWidth;
    double currentX = 0.0;
    bool isBar = true;

    for (final width in finalPattern) {
      final w = width * barUnitWidth;
      if (isBar) {
        canvas.drawRect(Rect.fromLTWH(currentX, 0, w, size.height), paint);
      }
      currentX += w;
      isBar = !isBar; // Alternate between black bar and white spacing
    }
  }

  @override
  bool shouldRepaint(covariant BarcodePainter oldDelegate) =>
      oldDelegate.code != code;
}

// ── Custom QR Code Vector Painter ─────────────────────────────────────────────
class QrCodePainter extends CustomPainter {
  final String data;
  QrCodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.fill;

    const int gridCount = 21; // standard QR Version 1 grid size
    final cellSize = size.width / gridCount;

    // 1. Draw 3 Finder Patterns at corners (Top-Left, Top-Right, Bottom-Left)
    _drawFinderPattern(canvas, paint, 0.0, 0.0, cellSize);
    _drawFinderPattern(
      canvas,
      paint,
      (gridCount - 7) * cellSize,
      0.0,
      cellSize,
    );
    _drawFinderPattern(
      canvas,
      paint,
      0.0,
      (gridCount - 7) * cellSize,
      cellSize,
    );

    // 2. Draw pseudorandom deterministic pixels using data string hashing
    final random = math.Random(data.hashCode);

    for (int row = 0; row < gridCount; row++) {
      for (int col = 0; col < gridCount; col++) {
        // Skip finder pattern zones
        final isTopLeftFinder = row < 8 && col < 8;
        final isTopRightFinder = row < 8 && col >= gridCount - 8;
        final isBottomLeftFinder = row >= gridCount - 8 && col < 8;

        if (isTopLeftFinder || isTopRightFinder || isBottomLeftFinder) {
          continue;
        }

        // Draw pixel cells pseudorandomly (simulating QR encoding data)
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize,
              row * cellSize,
              cellSize + 0.2,
              cellSize + 0.2,
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double cellSize,
  ) {
    // Outer 7x7 square
    paint.color = AppColors.black;
    canvas.drawRect(Rect.fromLTWH(x, y, cellSize * 7, cellSize * 7), paint);

    // Inner 5x5 white cutout
    paint.color = AppColors.white;
    canvas.drawRect(
      Rect.fromLTWH(x + cellSize, y + cellSize, cellSize * 5, cellSize * 5),
      paint,
    );

    // Core 3x3 solid black square
    paint.color = AppColors.black;
    canvas.drawRect(
      Rect.fromLTWH(
        x + cellSize * 2,
        y + cellSize * 2,
        cellSize * 3,
        cellSize * 3,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant QrCodePainter oldDelegate) =>
      oldDelegate.data != data;
}
