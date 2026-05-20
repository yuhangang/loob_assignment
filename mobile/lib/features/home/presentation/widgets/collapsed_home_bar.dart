import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/widgets/user_profile_avatar.dart';
import '../../../settings/data/models/user_profile_model.dart';

class CollapsedHomeBar extends StatelessWidget {
  final UserProfileModel? profile;

  const CollapsedHomeBar({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName
        : context.l10n.guestLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          // Avatar
          UserProfileAvatar(
            avatarUrl: profile?.avatarUrl,
            displayName: displayName,
            size: 30,
            borderWidth: 1.5,
            borderColor: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 10),
          // Name
          Text(
            displayName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const Spacer(),

          // Settings icon
        ],
      ),
    );
  }
}
