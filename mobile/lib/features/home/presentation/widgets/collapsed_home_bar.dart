import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/language_cubit.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../settings/data/models/user_profile_model.dart';

class CollapsedHomeBar extends StatelessWidget {
  final UserProfileModel? profile;

  const CollapsedHomeBar({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
              backgroundImage: profile != null && profile!.avatarUrl.isNotEmpty
                  ? NetworkImage(profile!.avatarUrl)
                  : const NetworkImage(
                      'http://localhost:8080/cdn/cute_avatar.png',
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Text(
            profile?.displayName.isNotEmpty == true
                ? profile!.displayName
                : 'Dev User',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          // Settings icon
          GestureDetector(
            onTap: () {
              final currentLang = context.read<LanguageCubit>().state.languageCode;
              context.read<LanguageCubit>().switchLanguage(
                    currentLang == 'en' ? 'ms' : 'en',
                  );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
