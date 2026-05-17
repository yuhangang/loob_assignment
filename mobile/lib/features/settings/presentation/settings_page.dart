import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../data/models/user_profile_model.dart';
import 'user_profile_cubit.dart';

/// Simple profile/settings page with multi-language selection support.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeLocale = context.watch<LanguageCubit>().state;

    return SafeArea(
      child: BlocBuilder<UserProfileCubit, UserProfileState>(
        builder: (context, state) {
          final profile = state is UserProfileLoaded ? state.profile : null;

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.xl,
            ),
            children: [
              Text(context.l10n.profile, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xl),
              if (state is UserProfileLoading)
                const Center(child: CircularProgressIndicator())
              else if (state is UserProfileError)
                _SettingsErrorCard(
                  message: state.message,
                  onRetry: () => context.read<UserProfileCubit>().loadProfile(),
                )
              else if (profile != null) ...[
                _ProfileCard(profile: profile),
                const SizedBox(height: AppSpacing.lg),
                _RewardsCard(profile: profile),
              ],
              const SizedBox(height: AppSpacing.xl),
              _SettingsGroup(
                title: context.l10n.preferences,
                items: [
                  _SettingsItem(
                    icon: Icons.language,
                    title: context.l10n.language,
                    trailing: activeLocale.languageCode == 'ms'
                        ? 'Bahasa Melayu'
                        : 'English',
                    onTap: () => _showLanguageSwitcher(context),
                  ),
                  _SettingsItem(
                    icon: Icons.public,
                    title: context.l10n.country,
                    trailing: _countryLabel(profile?.registeredCountryId),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettingsGroup(
                title: context.l10n.support,
                items: [
                  _SettingsItem(
                    icon: Icons.help_outline,
                    title: context.l10n.helpCentre,
                  ),
                  _SettingsItem(
                    icon: Icons.info_outline,
                    title: context.l10n.about,
                    trailing: 'v1.0.0',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  child: Text(context.l10n.signOut),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    final currentLocale = context.read<LanguageCubit>().state;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.xl,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.selectLanguage,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _LanguageOptionRow(
                  languageName: 'English',
                  isSelected: currentLocale.languageCode == 'en',
                  onTap: () {
                    context.read<LanguageCubit>().switchLanguage('en');
                    context.read<UserProfileCubit>().updatePreferredLanguage(
                      'en',
                    );
                    Navigator.of(context).pop();
                  },
                ),
                const Divider(height: 1),
                _LanguageOptionRow(
                  languageName: 'Bahasa Melayu',
                  isSelected: currentLocale.languageCode == 'ms',
                  onTap: () {
                    context.read<LanguageCubit>().switchLanguage('ms');
                    context.read<UserProfileCubit>().updatePreferredLanguage(
                      'ms',
                    );
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  String _countryLabel(String? countryCode) {
    switch (countryCode) {
      case 'TH':
        return 'Thailand';
      case 'MY':
      case null:
      case '':
        return 'Malaysia';
      default:
        return countryCode;
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfileModel profile;

  const _ProfileCard({required this.profile});

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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: profile.avatarUrl.isNotEmpty
                  ? NetworkImage(profile.avatarUrl)
                  : null,
              child: profile.avatarUrl.isEmpty
                  ? Icon(
                      Icons.person_outline,
                      size: 28,
                      color: theme.colorScheme.primary,
                    )
                  : null,
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
    );
  }
}

class _RewardsCard extends StatelessWidget {
  final UserProfileModel profile;

  const _RewardsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = profile.currencyCode.isEmpty
        ? 'MYR'
        : profile.currencyCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            Expanded(
              child: _RewardMetric(
                label: context.l10n.balance,
                value: profile.walletBalance.toDisplayPrice(currency),
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
            Container(width: 1, height: 44, color: theme.dividerColor),
            Expanded(
              child: _RewardMetric(
                label: context.l10n.tpoints,
                value: profile.loyaltyPoints.toString(),
                icon: Icons.stars_rounded,
              ),
            ),
            Container(width: 1, height: 44, color: theme.dividerColor),
            Expanded(
              child: _RewardMetric(
                label: 'Tier',
                value: profile.loyaltyTier,
                icon: Icons.workspace_premium_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RewardMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SettingsErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SettingsErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionRow extends StatelessWidget {
  final String languageName;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionRow({
    required this.languageName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        languageName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.textTheme.bodyMedium?.color,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: items.asMap().entries.map((entry) {
              final isLast = entry.key == items.length - 1;
              final item = entry.value;
              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    leading: Icon(
                      item.icon,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    title: Text(item.title, style: theme.textTheme.bodyMedium),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.trailing != null)
                          Text(
                            item.trailing!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 56, color: theme.dividerColor),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });
}
