import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/widgets/loob_skeleton.dart';
import '../../../../core/widgets/user_profile_avatar.dart';
import '../../../settings/data/models/user_profile_model.dart';

class HomeHeaderProfileRow extends StatelessWidget {
  final String greetingText;
  final UserProfileModel? profile;
  final bool isLoading;

  const HomeHeaderProfileRow({
    super.key,
    required this.greetingText,
    required this.profile,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Row(
        children: [
          const LoobSkeleton(
            width: 42,
            height: 42,
            borderRadius: 21,
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LoobSkeleton(
                width: 80,
                height: 12,
                borderRadius: 4,
              ),
              const SizedBox(height: 6),
              LoobSkeleton(
                width: 140,
                height: 20,
                borderRadius: 4,
              ),
            ],
          ),
        ],
      );
    }

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
