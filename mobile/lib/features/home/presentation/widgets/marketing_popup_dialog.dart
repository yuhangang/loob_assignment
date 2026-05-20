import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/models/app_config_model.dart';

class MarketingPopupDialog extends StatelessWidget {
  final MarketingPopupModel popup;

  const MarketingPopupDialog({super.key, required this.popup});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: Image.network(
                  popup.imageUrl.startsWith('http')
                      ? popup.imageUrl
                      : '${sl<AppConfig>().baseUrl}${popup.imageUrl}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    child: Icon(
                      Icons.celebration_rounded,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Title
            Text(
              popup.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Description
            Text(
              popup.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.black87,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.close),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, true);
                      context.showSuccessSnackBar(
                        context.l10n.eventClaimedToast,
                      );
                    },
                    child: Text(
                      popup.buttonText.isNotEmpty
                          ? popup.buttonText
                          : context.l10n.claim,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
