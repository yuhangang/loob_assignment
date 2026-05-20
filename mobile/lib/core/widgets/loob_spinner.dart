import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/tokens/colors.dart';

/// A premium, brand-aware circular concentric spinner.
/// Can be customized with size and color, and smoothly pulses/rotates.
class LoobSpinner extends StatefulWidget {
  final double size;
  final Color? color;

  const LoobSpinner({super.key, this.size = 56.0, this.color});

  @override
  State<LoobSpinner> createState() => _LoobSpinnerState();
}

class _LoobSpinnerState extends State<LoobSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final val = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing circle
              Transform.scale(
                scale: 1.0 + (math.sin(val * math.pi * 2) * 0.08),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.12),
                      width: 4,
                    ),
                  ),
                ),
              ),
              // Outer rotating arc
              Transform.rotate(
                angle: val * math.pi * 2,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    value: 0.25,
                    strokeWidth: 3.0,
                    color: primaryColor.withValues(alpha: 0.4),
                    backgroundColor: AppColors.transparent,
                  ),
                ),
              ),
              // Middle counter-rotating arc
              Transform.rotate(
                angle: -val * math.pi * 4,
                child: SizedBox(
                  width: widget.size * 0.7,
                  height: widget.size * 0.7,
                  child: CircularProgressIndicator(
                    value: 0.35,
                    strokeWidth: 3.5,
                    color: primaryColor.withValues(alpha: 0.75),
                    backgroundColor: AppColors.transparent,
                  ),
                ),
              ),
              // Inner pulsing dot
              Transform.scale(
                scale: 0.8 + (math.cos(val * math.pi * 2) * 0.15),
                child: Container(
                  width: widget.size * 0.3,
                  height: widget.size * 0.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
