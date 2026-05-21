import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loob_app/core/localization/app_localizations.dart';
import 'package:loob_app/core/router/app_router.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/widgets/user_profile_avatar.dart';
import '../../data/models/user_profile_model.dart';

class ProfileCard extends StatelessWidget {
  final UserProfileModel profile;

  const ProfileCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = profile.displayName.isNotEmpty
        ? profile.displayName
        : 'Dev User';
    final subtitle = profile.phoneNumber.isNotEmpty
        ? profile.phoneNumber
        : profile.userId;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                UserProfileAvatar(
                  avatarUrl: profile.avatarUrl,
                  displayName: profile.displayName,
                  size: 56,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.primary),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.push(AppRouter.vouchers),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    child: Icon(
                      Icons.confirmation_number_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.myVouchers,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.myVouchersDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
