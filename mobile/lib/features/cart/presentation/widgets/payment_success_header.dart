import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';

class PaymentSuccessHeader extends StatefulWidget {
  final String orderTrackingId;
  final String title;

  const PaymentSuccessHeader({
    super.key,
    required this.orderTrackingId,
    required this.title,
  });

  @override
  State<PaymentSuccessHeader> createState() => _PaymentSuccessHeaderState();
}

class _PaymentSuccessHeaderState extends State<PaymentSuccessHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      
      // Generate a dynamic palette based on the current brand colors
      final List<Color> palette = [
        theme.colorScheme.primary,
        theme.colorScheme.secondary,
        theme.colorScheme.tertiary,
        AppColors.success,
        if (!isDark) AppColors.tealiveAccent,
      ];
      
      _generateParticles(palette);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generateParticles(List<Color> palette) {
    _particles.clear();
    for (int i = 0; i < 36; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      // Explode outwards with varying speeds
      final speed = 50.0 + _random.nextDouble() * 150.0;
      final size = 5.0 + _random.nextDouble() * 6.0;
      final color = palette[_random.nextInt(palette.length)];
      final isCircle = _random.nextBool();
      final rotationSpeed = (_random.nextDouble() - 0.5) * 8.0;
      final arcIntensity = 100.0 + _random.nextDouble() * 100.0; // Gravity simulation intensity

      _particles.add(
        _ConfettiParticle(
          angle: angle,
          speed: speed,
          size: size,
          color: color,
          isCircle: isCircle,
          rotationSpeed: rotationSpeed,
          arcIntensity: arcIntensity,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;

        return Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            
            // Celebration Stack: Confetti + Animated checkmark + Glow rings
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Confetti explosion behind the checkmark
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: progress,
                  ),
                ),

                // Pulsing glow rings (Concentric glow wave)
                if (progress > 0.0 && progress < 0.6)
                  ...List.generate(2, (index) {
                    final double delay = index * 0.25;
                    final double waveProgress = ((progress * 1.6) - delay).clamp(0.0, 1.0);
                    if (waveProgress <= 0.0 || waveProgress >= 1.0) return const SizedBox.shrink();

                    final double scale = 1.0 + waveProgress * 0.7;
                    final double opacity = (1.0 - waveProgress) * 0.35;

                    return Container(
                      width: 80 * scale,
                      height: 80 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(alpha: opacity),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: opacity),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),

                // Self-drawing checkmark circular badge
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08 + (progress * 0.06),
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    size: const Size(80, 80),
                    painter: _CheckmarkPainter(
                      progress: progress,
                      checkColor: AppColors.success,
                      strokeColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Animated slide/fade for Title
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 15 * (1.0 - opacity)),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.orderTrackingId,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Sleek Glow SUCCESS Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Small glowing dot
                        _PulsatingDot(color: AppColors.success),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'SUCCESS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final bool isCircle;
  final double rotationSpeed;
  final double arcIntensity;

  _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.isCircle,
    required this.rotationSpeed,
    required this.arcIntensity,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      // Calculate dynamic radius distance based on current progress
      final double distance = p.speed * progress;
      final double x = center.dx + math.cos(p.angle) * distance;
      // Arc gravity fall simulation
      final double y = center.dy +
          math.sin(p.angle) * distance +
          (p.arcIntensity * progress * progress);

      // Fade out slowly after 50% progress
      final double alpha = progress < 0.5 ? 1.0 : (1.0 - progress) * 2.0;

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * progress);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color checkColor;
  final Color strokeColor;

  _CheckmarkPainter({
    required this.progress,
    required this.checkColor,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3.5;

    // 1. Draw solid circle outline
    final outlinePaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, outlinePaint);

    // 2. Draw animated circle outline path
    final pathPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final double circleProgress = (progress * 2.0).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      pathPaint,
    );

    // 3. Draw animated checkmark drawing once circle outline finishes first phase (progress > 0.4)
    if (progress > 0.4) {
      final double checkProgress = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
      final checkPaint = Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      
      final startX = size.width * 0.32;
      final startY = size.height * 0.50;
      
      final midX = size.width * 0.46;
      final midY = size.height * 0.64;
      
      final endX = size.width * 0.68;
      final endY = size.height * 0.38;

      path.moveTo(startX, startY);

      if (checkProgress < 0.4) {
        final double segment = checkProgress / 0.4;
        path.lineTo(
          startX + (midX - startX) * segment,
          startY + (midY - startY) * segment,
        );
      } else {
        path.lineTo(midX, midY);
        final double segment = (checkProgress - 0.4) / 0.6;
        path.lineTo(
          midX + (endX - midX) * segment,
          midY + (endY - midY) * segment,
        );
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _PulsatingDot extends StatefulWidget {
  final Color color;

  const _PulsatingDot({required this.color});

  @override
  State<_PulsatingDot> createState() => _PulsatingDotState();
}

class _PulsatingDotState extends State<_PulsatingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 7.0,
          height: 7.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: 0.15 + (_pulseController.value * 0.5),
                ),
                blurRadius: 4.0 + (_pulseController.value * 5.0),
                spreadRadius: _pulseController.value * 1.5,
              ),
            ],
          ),
        );
      },
    );
  }
}
