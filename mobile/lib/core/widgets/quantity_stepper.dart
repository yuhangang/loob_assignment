import 'package:flutter/material.dart';
import '../theme/tokens/spacing.dart';

enum QuantityStepperStyle {
  /// Compact style with subtle border and grey background, used in Cart page list items.
  compact,

  /// Full-width/Standard style with rounded/box decoration and customizable button sizes, used in detail sheets.
  standard,
}

class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final QuantityStepperStyle style;
  final bool compactButtonSize;

  const QuantityStepper({
    super.key,
    required this.quantity,
    this.onDecrease,
    this.onIncrease,
    this.style = QuantityStepperStyle.standard,
    this.compactButtonSize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (style == QuantityStepperStyle.compact) {
      return Container(
        height: 36,
        decoration: BoxDecoration(
          color: theme.dividerColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
              onPressed: onDecrease,
            ),
            SizedBox(
              width: 26,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
              onPressed: onIncrease,
            ),
          ],
        ),
      );
    }

    // Standard/Customizable style used in customization sheets and product detail pages
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : theme.dividerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            icon: Icons.remove_rounded,
            onPressed: onDecrease,
            theme: theme,
          ),
          Container(
            alignment: Alignment.center,
            constraints: BoxConstraints(
              minWidth: compactButtonSize ? 24 : 32,
            ),
            child: Text(
              '$quantity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _buildButton(
            icon: Icons.add_rounded,
            onPressed: onIncrease,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ThemeData theme,
  }) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: compactButtonSize ? 38 : 48,
        height: 52,
        color: Colors.transparent,
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? theme.textTheme.bodyMedium?.color
                : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}
