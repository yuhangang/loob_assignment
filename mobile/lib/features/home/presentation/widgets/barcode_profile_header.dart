import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/tokens/spacing.dart';
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
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white12,
            backgroundImage: profile != null && profile!.avatarUrl.isNotEmpty
                ? NetworkImage(profile!.avatarUrl)
                : NetworkImage(
                    '${sl<AppConfig>().baseUrl}/cdn/cute_avatar.png',
                  ),
          ),
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
                  color: Colors.white,
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
                      color: isTealive ? primaryColor : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile != null && profile!.loyaltyTier.isNotEmpty
                          ? '${profile!.loyaltyTier.toUpperCase()} MEMBER'
                          : 'GOLD MEMBER',
                      style: TextStyle(
                        color: isTealive ? primaryColor : Colors.white,
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
