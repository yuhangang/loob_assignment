import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/bloc/auth_bloc.dart';
import '../../../core/auth/bloc/auth_event.dart';
import '../../../core/auth/bloc/auth_state.dart';
import '../../../core/auth/login_bottom_sheet.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/user_profile_avatar.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_event.dart';
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
    final activeCountry = context.watch<CartBloc>().state.countryCode;
    final authState = context.watch<AuthBloc>().state;
    final isAuthenticated = authState is Authenticated;

    return SafeArea(
      child: BlocBuilder<UserProfileCubit, UserProfileState>(
        builder: (context, state) {
          final loadedState = state is UserProfileLoaded ? state : null;
          final profile = loadedState?.profile;

          return ListView(
            padding: EdgeInsets.only(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.xl,
              bottom: AppSpacing.xl + context.cartFloatingBarPadding,
            ),
            children: [
              Text(context.l10n.profile, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xl),

              if (!isAuthenticated)
                const _GuestCard()
              else if (state is UserProfileLoading)
                const Center(child: CircularProgressIndicator())
              else if (state is UserProfileError)
                _SettingsErrorCard(
                  message: state.message,
                  errorCode: state.errorCode,
                  traceId: state.traceId,
                  onRetry: () => context.read<UserProfileCubit>().loadProfile(),
                )
              else if (loadedState != null && profile != null) ...[
                _ProfileCard(profile: profile),
                const SizedBox(height: AppSpacing.lg),
                _RewardsCard(
                  profile: profile,
                  walletHistory: loadedState.walletHistory,
                  loyaltyHistory: loadedState.loyaltyHistory,
                  isTopUpSubmitting: loadedState.isTopUpSubmitting,
                  onTopUp: () =>
                      context.read<UserProfileCubit>().topUpWallet(1000),
                ),
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
                    trailing: _countryLabel(activeCountry),
                    onTap: () => _showCountrySwitcher(context, activeCountry),
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
              if (isAuthenticated) ...[
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.5),
                      ),
                      foregroundColor: theme.colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                      ),
                    ),
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthSignOut());
                    },
                    child: Text(
                      context.l10n.signOut,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    final currentLocale = context.read<LanguageCubit>().state;
    final theme = Theme.of(context);
    final isAuthenticated = context.read<AuthBloc>().state is Authenticated;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
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
                    if (isAuthenticated) {
                      context.read<UserProfileCubit>().updatePreferredLanguage(
                        'en',
                      );
                    }
                    Navigator.of(context).pop();
                  },
                ),
                const Divider(height: 1),
                _LanguageOptionRow(
                  languageName: 'Bahasa Melayu',
                  isSelected: currentLocale.languageCode == 'ms',
                  onTap: () {
                    context.read<LanguageCubit>().switchLanguage('ms');
                    if (isAuthenticated) {
                      context.read<UserProfileCubit>().updatePreferredLanguage(
                        'ms',
                      );
                    }
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

  void _showCountrySwitcher(BuildContext context, String? registeredCountryId) {
    final theme = Theme.of(context);
    final currentCountry = registeredCountryId ?? 'MY';
    final isAuthenticated = context.read<AuthBloc>().state is Authenticated;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
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
                  context.l10n.selectCountryTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _LanguageOptionRow(
                  languageName: 'Malaysia',
                  isSelected: currentCountry == 'MY',
                  onTap: () {
                    if (isAuthenticated) {
                      context.read<UserProfileCubit>().updateRegisteredCountry(
                        'MY',
                      );
                    }
                    context.read<CartBloc>().add(
                      const CartSwitchCountry(
                        countryCode: 'MY',
                        currency: 'MYR',
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
                const Divider(height: 1),
                _LanguageOptionRow(
                  languageName: 'Thailand',
                  isSelected: currentCountry == 'TH',
                  onTap: () {
                    if (isAuthenticated) {
                      context.read<UserProfileCubit>().updateRegisteredCountry(
                        'TH',
                      );
                    }
                    context.read<CartBloc>().add(
                      const CartSwitchCountry(
                        countryCode: 'TH',
                        currency: 'THB',
                      ),
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
    );
  }
}

class _RewardsCard extends StatelessWidget {
  final UserProfileModel profile;
  final WalletHistoryModel walletHistory;
  final LoyaltyHistoryModel loyaltyHistory;
  final bool isTopUpSubmitting;
  final VoidCallback onTopUp;

  const _RewardsCard({
    required this.profile,
    required this.walletHistory,
    required this.loyaltyHistory,
    required this.isTopUpSubmitting,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = profile.currencyCode.isEmpty
        ? 'MYR'
        : profile.currencyCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          children: [
            Row(
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
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isTopUpSubmitting ? null : onTopUp,
                icon: isTopUpSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_card_rounded),
                label: const Text('Top up RM 10.00'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _HistorySection(
              title: 'Wallet activity',
              emptyText: 'No wallet activity yet',
              children: walletHistory.transactions
                  .take(3)
                  .map(
                    (tx) => _HistoryRow(
                      icon: tx.amount >= 0
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                      title: _walletTitle(tx),
                      subtitle: tx.description,
                      timestamp: _formatTimestamp(tx.createdAt),
                      value: tx.amount.toDisplayPrice(
                        tx.currencyCode.isEmpty ? currency : tx.currencyCode,
                      ),
                      isPositive: tx.amount >= 0,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            _HistorySection(
              title: 'Points activity',
              emptyText: 'No points activity yet',
              children: loyaltyHistory.transactions
                  .take(3)
                  .map(
                    (tx) => _HistoryRow(
                      icon: tx.pointsDelta >= 0
                          ? Icons.stars_rounded
                          : Icons.redeem_rounded,
                      title: _loyaltyTitle(tx),
                      subtitle: tx.description,
                      timestamp: _formatTimestamp(tx.createdAt),
                      value:
                          '${tx.pointsDelta > 0 ? '+' : ''}${tx.pointsDelta} pts',
                      isPositive: tx.pointsDelta >= 0,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String rawTimestamp) {
    if (rawTimestamp.isEmpty) return '';
    final parsed = DateTime.tryParse(rawTimestamp);
    if (parsed == null) return rawTimestamp;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  String _walletTitle(WalletTransactionModel tx) {
    switch (tx.transactionType) {
      case 'TOPUP':
        return 'Wallet top-up';
      case 'SPEND':
        return 'Wallet spend';
      case 'REFUND':
        return 'Wallet refund';
      default:
        return 'Wallet adjustment';
    }
  }

  String _loyaltyTitle(LoyaltyTransactionModel tx) {
    switch (tx.transactionType) {
      case 'EARN':
        return 'Points earned';
      case 'REDEEM':
        return 'Points redeemed';
      case 'EXPIRE':
        return 'Points expired';
      default:
        return 'Points adjusted';
    }
  }
}

class _HistorySection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<Widget> children;

  const _HistorySection({
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

class _HistoryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String timestamp;
  final String value;
  final bool isPositive;

  const _HistoryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.value,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = isPositive
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: valueColor, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.55,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    timestamp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.45,
                      ),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(color: valueColor),
          ),
        ],
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
  final String? errorCode;
  final String? traceId;
  final VoidCallback onRetry;

  const _SettingsErrorCard({
    required this.message,
    required this.onRetry,
    this.errorCode,
    this.traceId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (errorCode != null || traceId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (errorCode != null) 'Code: $errorCode',
                  if (traceId != null) 'Trace: $traceId',
                ].join('  '),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.labelSmall?.color?.withValues(alpha: 0.55),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
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

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.welcomeGuest,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        context.l10n.guestDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => LoginBottomSheet.show(context),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  context.l10n.loginSignup,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
