import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';

class ScannerModeToggle extends StatelessWidget {
  final bool isScannerMode;
  final Color accentColor;
  final void Function(bool value) onChanged;

  const ScannerModeToggle({
    super.key,
    required this.isScannerMode,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isScannerMode ? accentColor : AppColors.white12,
            ),
            child: Icon(
              Icons.wb_sunny_rounded,
              size: 18,
              color: isScannerMode ? AppColors.white : AppColors.white70,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Scanner Mode',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Enhances screen contrast for instant scanning.',
                  style: TextStyle(color: AppColors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(
            value: isScannerMode,
            onChanged: (val) {
              HapticFeedback.mediumImpact();
              onChanged(val);
            },
            activeThumbColor: accentColor,
            activeTrackColor: accentColor.withValues(alpha: 0.35),
            inactiveThumbColor: AppColors.grey400,
            inactiveTrackColor: AppColors.white10,
          ),
        ],
      ),
    );
  }
}
