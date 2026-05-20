import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';

class CheckoutCollectionCard extends StatefulWidget {
  final String trackingId;

  const CheckoutCollectionCard({super.key, required this.trackingId});

  @override
  State<CheckoutCollectionCard> createState() => _CheckoutCollectionCardState();
}

class _CheckoutCollectionCardState extends State<CheckoutCollectionCard> {
  bool _isCopied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.trackingId));
    
    _copyTimer?.cancel();
    setState(() {
      _isCopied = true;
    });

    _copyTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });

    // Provide a subtle haptic feedback if possible
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pin = widget.trackingId.collectionPin;

    final gradientColors = isDark
        ? [
            theme.colorScheme.primary.withValues(alpha: 0.22),
            theme.colorScheme.secondary.withValues(alpha: 0.12),
          ]
        : [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
          ];

    final borderColor = theme.colorScheme.primary.withValues(alpha: 0.25);
    final dashedColor = theme.colorScheme.primary.withValues(alpha: 0.3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final punchPercent = 0.42;

        return TicketContainer(
          gradientColors: gradientColors,
          borderColor: borderColor,
          dashedColor: dashedColor,
          punchPercent: punchPercent,
          punchRadius: 10.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Your Collection Code)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      context.l10n.yourCollectionCode.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Main stub content row
                Row(
                  children: [
                    // Left Section: QR Code Stub (42% Width)
                    SizedBox(
                      width: cardWidth * punchPercent,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: QrImageView(
                            data: widget.trackingId,
                            version: QrVersions.auto,
                            size: 96,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF1A1A2E),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right Section: Details (58% Width)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.xs,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PIN',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(
                                  alpha: 0.55,
                                ),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            
                            // Tactical Pin Digits
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: pin
                                  .split('')
                                  .map((d) => CheckoutPinDigit(digit: d))
                                  .toList(),
                            ),
                            
                            const SizedBox(height: AppSpacing.md),

                            // Order ID Copy trigger
                            Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                InkWell(
                                  onTap: _handleCopy,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.trackingId,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontFamily: 'monospace',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: theme.textTheme.bodySmall?.color
                                                  ?.withValues(alpha: 0.65),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: Icon(
                                            _isCopied
                                                ? Icons.check_circle_rounded
                                                : Icons.copy_rounded,
                                            key: ValueKey<bool>(_isCopied),
                                            size: 12,
                                            color: _isCopied
                                                ? AppColors.success
                                                : theme.colorScheme.primary.withValues(
                                                    alpha: 0.6,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Floating bubble "Copied!" notification
                                Positioned(
                                  top: -28,
                                  child: IgnorePointer(
                                    child: AnimatedOpacity(
                                      opacity: _isCopied ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: AnimatedScale(
                                        scale: _isCopied ? 1.0 : 0.8,
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOutBack,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.success,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.success.withValues(
                                                  alpha: 0.3,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Text(
                                            'Copied!',
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Footer Text
                Text(
                  'Show this to the staff at the counter',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.5,
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CheckoutPinDigit extends StatelessWidget {
  final String digit;

  const CheckoutPinDigit({super.key, required this.digit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3.5),
      width: 36,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withValues(alpha: 0.7),
                ]
              : [
                  AppColors.white,
                  theme.colorScheme.primary.withValues(alpha: 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          // Tactical soft shadow
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          // Inner 3D highlights
          BoxShadow(
            color: isDark ? AppColors.white10 : AppColors.white,
            blurRadius: 0,
            offset: const Offset(0, -1.5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.primary,
          fontSize: 20,
          height: 1,
        ),
      ),
    );
  }
}

/// A high-fidelity ticket wrapper clipper.
class TicketClipper extends CustomClipper<Path> {
  final double punchPercent;
  final double punchRadius;

  const TicketClipper({
    required this.punchPercent,
    required this.punchRadius,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final punchX = size.width * punchPercent;
    const cornerRadius = 16.0;

    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Top Notch
    path.lineTo(punchX - punchRadius, 0);
    path.arcToPoint(
      Offset(punchX + punchRadius, 0),
      radius: Radius.circular(punchRadius),
      clockwise: false,
    );

    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );

    // Bottom Notch
    path.lineTo(punchX + punchRadius, size.height);
    path.arcToPoint(
      Offset(punchX - punchRadius, size.height),
      radius: Radius.circular(punchRadius),
      clockwise: false,
    );

    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketClipper oldClipper) {
    return oldClipper.punchPercent != punchPercent ||
        oldClipper.punchRadius != punchRadius;
  }
}

/// A custom ticket background, shadow, border, and perforation line painter.
class TicketContainer extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color dashedColor;
  final double punchPercent;
  final double punchRadius;

  const TicketContainer({
    super.key,
    required this.child,
    required this.gradientColors,
    required this.borderColor,
    required this.dashedColor,
    required this.punchPercent,
    required this.punchRadius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketPainter(
        gradientColors: gradientColors,
        borderColor: borderColor,
        dashedColor: dashedColor,
        punchPercent: punchPercent,
        punchRadius: punchRadius,
      ),
      child: ClipPath(
        clipper: TicketClipper(
          punchPercent: punchPercent,
          punchRadius: punchRadius,
        ),
        child: child,
      ),
    );
  }
}

class _TicketPainter extends CustomPainter {
  final List<Color> gradientColors;
  final Color borderColor;
  final Color dashedColor;
  final double punchPercent;
  final double punchRadius;

  _TicketPainter({
    required this.gradientColors,
    required this.borderColor,
    required this.dashedColor,
    required this.punchPercent,
    required this.punchRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final punchX = size.width * punchPercent;
    final rect = Offset.zero & size;
    const cornerRadius = 16.0;

    final path = Path();
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Top Notch
    path.lineTo(punchX - punchRadius, 0);
    path.arcToPoint(
      Offset(punchX + punchRadius, 0),
      radius: Radius.circular(punchRadius),
      clockwise: false,
    );

    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );

    // Bottom Notch
    path.lineTo(punchX + punchRadius, size.height);
    path.arcToPoint(
      Offset(punchX - punchRadius, size.height),
      radius: Radius.circular(punchRadius),
      clockwise: false,
    );

    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.close();

    // 1. Draw smooth soft shadow
    final shadowPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(path.shift(const Offset(0, 6)), shadowPaint);

    // 2. Fill gradient background
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ).createShader(rect);
    canvas.drawPath(path, bgPaint);

    // 3. Draw border stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);

    // 4. Draw perforation vertical dashed line
    final dashPaint = Paint()
      ..color = dashedColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    double startY = punchRadius + 3.0;
    final double endY = size.height - punchRadius - 3.0;
    const double dashHeight = 5.0;
    const double dashSpace = 4.0;

    while (startY < endY) {
      canvas.drawLine(
        Offset(punchX, startY),
        Offset(punchX, (startY + dashHeight).clamp(startY, endY)),
        dashPaint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.dashedColor != dashedColor ||
        oldDelegate.punchPercent != punchPercent ||
        oldDelegate.punchRadius != punchRadius;
  }
}

extension on String {
  /// Last 4 numeric digits of the tracking ID used as collection PIN.
  String get collectionPin {
    final digits = replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) return digits.substring(digits.length - 4);
    return digits.padLeft(4, '0');
  }
}
