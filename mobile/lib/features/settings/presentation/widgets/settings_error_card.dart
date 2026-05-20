import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';

class SettingsErrorCard extends StatelessWidget {
  final String message;
  final String? errorCode;
  final String? traceId;
  final VoidCallback onRetry;

  const SettingsErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    this.errorCode,
    this.traceId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (errorCode != null || traceId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (errorCode != null) 'Code: $errorCode',
                  if (traceId != null) 'Trace: $traceId',
                ].join('  '),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.labelSmall?.color?.withValues(alpha: 0.55),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}
