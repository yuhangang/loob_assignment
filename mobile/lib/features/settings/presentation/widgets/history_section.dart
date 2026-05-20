import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/spacing.dart';

class HistorySection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<Widget> children;

  const HistorySection({
    super.key,
    required this.title,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (children.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          )
        else
          ...children,
      ],
    );
  }
}
