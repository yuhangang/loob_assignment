import 'package:flutter/material.dart';

import '../theme/tokens/colors.dart';
import '../theme/tokens/spacing.dart';

/// An elegant, premium error alert dialog.
/// Displays structured error information, with optional expandable trace logs.
class LoobErrorDialog extends StatefulWidget {
  final String title;
  final String message;
  final String? errorCode;
  final String? traceId;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const LoobErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.errorCode,
    this.traceId,
    this.actionLabel,
    this.onActionPressed,
  });

  /// Launch the custom error modal with pre-configured style parameters.
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String? errorCode,
    String? traceId,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return LoobErrorDialog(
          title: title,
          message: message,
          errorCode: errorCode,
          traceId: traceId,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed,
        );
      },
    );
  }

  @override
  State<LoobErrorDialog> createState() => _LoobErrorDialogState();
}

class _LoobErrorDialogState extends State<LoobErrorDialog> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasDetails = widget.errorCode != null || widget.traceId != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      backgroundColor: isDark ? AppColors.grey900 : AppColors.white,
      surfaceTintColor: AppColors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.xl,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Soft pink/red warning icon container
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Dialog Title
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.white : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // User-friendly Error Message
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.grey300 : AppColors.grey600,
              height: 1.45,
            ),
          ),
          // Collapsible technical trace logs
          if (hasDetails) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              onTap: () {
                setState(() {
                  _showDetails = !_showDetails;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showDetails
                          ? 'Hide technical details'
                          : 'Show technical details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(
                      _showDetails
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showDetails
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.grey800 : AppColors.grey100,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.errorCode != null) ...[
                            Text(
                              'Code: ${widget.errorCode}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: isDark
                                    ? AppColors.grey300
                                    : AppColors.grey700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (widget.traceId != null)
                            Text(
                              'Trace ID: ${widget.traceId}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: isDark
                                    ? AppColors.grey300
                                    : AppColors.grey700,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      actions: [
        Column(
          children: [
            if (widget.actionLabel != null && widget.onActionPressed != null) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onActionPressed!();
                  },
                  child: Text(
                    widget.actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
