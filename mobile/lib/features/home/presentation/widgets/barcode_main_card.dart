import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/spacing.dart';
import 'barcode_painters.dart';

class BarcodeMainCard extends StatelessWidget {
  final bool isBarcodeMode;
  final bool isScannerMode;
  final String membershipId;
  final String securityToken;
  final int secondsRemaining;
  final int maxSeconds;
  final Color accentColor;
  final Color surfaceColor;
  final bool isTealive;
  final AnimationController laserController;
  final VoidCallback onCopy;
  final void Function(bool isBarcode) onToggleMode;

  const BarcodeMainCard({
    super.key,
    required this.isBarcodeMode,
    required this.isScannerMode,
    required this.membershipId,
    required this.securityToken,
    required this.secondsRemaining,
    required this.maxSeconds,
    required this.accentColor,
    required this.surfaceColor,
    required this.isTealive,
    required this.laserController,
    required this.onCopy,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isScannerMode ? Colors.white : surfaceColor;
    final cardBorder = isScannerMode
        ? accentColor.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.1);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          if (isScannerMode)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.24),
              blurRadius: 32,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Elegant Header inside card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'PRESENT AT CHECKOUT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isScannerMode ? Colors.black54 : Colors.white60,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              // Code Dynamic Timer Capsule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isScannerMode
                      ? Colors.grey.shade100
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isScannerMode
                        ? Colors.grey.shade300
                        : Colors.white12,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        value: secondsRemaining / maxSeconds,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      '${secondsRemaining}s',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isScannerMode
                            ? Colors.black.withValues(alpha: 0.85)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Beautiful Vector paint layout box ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              height: 180,
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Stack(
                children: [
                  // Vector Code
                  Positioned.fill(
                    child: Center(
                      child: isBarcodeMode
                          ? CustomPaint(
                              size: const Size(double.infinity, 120),
                              painter: BarcodePainter(
                                '$membershipId-$securityToken',
                              ),
                            )
                          : CustomPaint(
                              size: const Size(130, 130),
                              painter: QrCodePainter(
                                '$membershipId-$securityToken',
                              ),
                            ),
                    ),
                  ),

                  // Neon scan laser line
                  AnimatedBuilder(
                    animation: laserController,
                    builder: (context, child) {
                      final topOffset =
                          laserController.value *
                          (180.0 - 2 * AppSpacing.md - 4);
                      return Positioned(
                        top: topOffset,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: accentColor,
                            boxShadow: [
                              BoxShadow(
                                color: accentColor,
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Membership Copy Action ─────────────────────────────────────────────
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isScannerMode
                    ? Colors.grey.shade50
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isScannerMode
                      ? Colors.grey.shade200
                      : Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$membershipId-',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isScannerMode
                          ? Colors.black.withValues(alpha: 0.85)
                          : Colors.white,
                    ),
                  ),
                  Text(
                    securityToken,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.copy_all_rounded, size: 16, color: accentColor),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Divider
          Container(
            height: 1,
            color: isScannerMode
                ? Colors.grey.shade200
                : Colors.white.withValues(alpha: 0.08),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Toggle Switch between Barcode and QR ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabOption(
                label: 'BARCODE',
                icon: Icons.line_weight_rounded,
                isSelected: isBarcodeMode,
                onTap: () => onToggleMode(true),
                accentColor: accentColor,
              ),
              _buildTabOption(
                label: 'QR CODE',
                icon: Icons.qr_code_2_rounded,
                isSelected: !isBarcodeMode,
                onTap: () => onToggleMode(false),
                accentColor: accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mini Switch Bar Tab Widget ──────────────────────────────────────────────
  Widget _buildTabOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    final labelColor = isSelected
        ? (isScannerMode ? Colors.black : Colors.white)
        : (isScannerMode ? Colors.black38 : Colors.white30);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 8,
        ),
        decoration: isSelected
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: accentColor, width: 2.5),
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? accentColor
                  : (isScannerMode ? Colors.black38 : Colors.white30),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: labelColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
