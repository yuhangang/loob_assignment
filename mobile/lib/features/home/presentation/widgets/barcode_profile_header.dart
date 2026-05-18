import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/widgets/user_profile_avatar.dart';
import '../../../settings/data/models/user_profile_model.dart';

class BarcodeProfileHeader extends StatelessWidget {
  final UserProfileModel? profile;
  final Color accentColor;
  final Color primaryColor;
  final bool isTealive;

  const BarcodeProfileHeader({
    super.key,
    required this.profile,
    required this.accentColor,
    required this.primaryColor,
    required this.isTealive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        UserProfileAvatar(
          avatarUrl: profile?.avatarUrl,
          displayName: profile?.displayName ?? 'Dev User',
          size: 44,
          borderWidth: 2,
          borderColor: accentColor.withValues(alpha: 0.6),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.displayName.isNotEmpty == true
                    ? profile!.displayName
                    : 'Dev User',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      size: 11,
                      color: isTealive ? primaryColor : AppColors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile != null && profile!.loyaltyTier.isNotEmpty
                          ? '${profile!.loyaltyTier.toUpperCase()} MEMBER'
                          : 'GOLD MEMBER',
                      style: TextStyle(
                        color: isTealive ? primaryColor : AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
