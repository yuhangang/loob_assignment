import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/models/app_config_model.dart';

class FulfillmentToggle extends StatelessWidget {
  final AppConfigModel? config;
  final bool isDeliverySelected;
  final void Function(bool isDeliverySelected) onToggle;

  const FulfillmentToggle({
    super.key,
    required this.config,
    required this.isDeliverySelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? AppColors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Delivery
          Expanded(
            child: GestureDetector(
              onTap: () {
                final enabled = config?.featureToggles.deliveryEnabled ?? true;
                if (!enabled) {
                  context.showSuccessSnackBar(
                    context.l10n.deliveryOfflineWarning,
                  );
                  return;
                }
                onToggle(true);
              },
              child: Container(
                decoration: isDeliverySelected && (config?.featureToggles.deliveryEnabled ?? true)
                    ? BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.warmFulfillmentGreenBg,
                            AppColors.lightFulfillmentGreenBg,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppColors.borderFulfillmentGreen,
                          width: 1.0,
                        ),
                      )
                    : BoxDecoration(
                        color: AppColors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delivery_dining_rounded,
                      color: isDeliverySelected && (config?.featureToggles.deliveryEnabled ?? true)
                          ? AppColors.textFulfillmentGreen
                          : theme.colorScheme.primary.withValues(
                              alpha: 0.5,
                            ),
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      (config?.featureToggles.deliveryEnabled ?? true)
                          ? context.l10n.delivery
                          : context.l10n.deliveryOff,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDeliverySelected && (config?.featureToggles.deliveryEnabled ?? true)
                            ? AppColors.textFulfillmentGreen
                            : theme.colorScheme.primary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Pickup
          Expanded(
            child: GestureDetector(
              onTap: () {
                final enabled = config?.featureToggles.pickupEnabled ?? true;
                if (!enabled) {
                  context.showSuccessSnackBar(
                    context.l10n.pickupOfflineWarning,
                  );
                  return;
                }
                onToggle(false);
              },
              child: Container(
                decoration: !isDeliverySelected && (config?.featureToggles.pickupEnabled ?? true)
                    ? BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.warmFulfillmentOrangeBg,
                            AppColors.lightFulfillmentOrangeBg,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppColors.borderFulfillmentOrange,
                          width: 1.0,
                        ),
                      )
                    : BoxDecoration(
                        color: AppColors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_drink_rounded,
                      color: !isDeliverySelected && (config?.featureToggles.pickupEnabled ?? true)
                          ? AppColors.textFulfillmentOrange
                          : theme.colorScheme.primary.withValues(
                              alpha: 0.5,
                            ),
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      (config?.featureToggles.pickupEnabled ?? true)
                          ? context.l10n.pickup
                          : context.l10n.pickupOff,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: !isDeliverySelected && (config?.featureToggles.pickupEnabled ?? true)
                            ? AppColors.textFulfillmentOrange
                            : theme.colorScheme.primary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
