import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/language_cubit.dart';
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            UserProfileAvatar(
              avatarUrl: profile?.avatarUrl,
              displayName: profile?.displayName ?? 'Dev User',
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
                  profile?.displayName.isNotEmpty == true
                      ? profile!.displayName
                      : 'Dev User',
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
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.settings_outlined,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
