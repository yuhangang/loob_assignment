import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
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

  void _showSimulatedAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  _showSimulatedAction(
                    context,
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
                            Color(0xFFE2F0D9),
                            Color(0xFFF2F9EE),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFC5E0B4),
                          width: 1.0,
                        ),
                      )
                    : BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delivery_dining_rounded,
                      color: isDeliverySelected && (config?.featureToggles.deliveryEnabled ?? true)
                          ? const Color(0xFF385723)
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
                            ? const Color(0xFF385723)
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
                  _showSimulatedAction(
                    context,
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
                            Color(0xFFFFF2CC),
                            Color(0xFFFFF9E6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFF8CBAD),
                          width: 1.0,
                        ),
                      )
                    : BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_drink_rounded,
                      color: !isDeliverySelected && (config?.featureToggles.pickupEnabled ?? true)
                          ? const Color(0xFFC65911)
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
                            ? const Color(0xFFC65911)
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
