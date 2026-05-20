import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/widgets/user_profile_avatar.dart';
import '../../../settings/data/models/user_profile_model.dart';

class HomeHeaderProfileRow extends StatelessWidget {
  final String greetingText;
  final UserProfileModel? profile;

  const HomeHeaderProfileRow({
    super.key,
    required this.greetingText,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGuest = profile == null;
    final displayName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName
        : context.l10n.guestLabel;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            UserProfileAvatar(
              avatarUrl: profile?.avatarUrl,
              displayName: displayName,
              size: 36,
              borderWidth: 2,
              borderColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greetingText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                Text(
                  isGuest ? context.l10n.welcomeGuest : displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
