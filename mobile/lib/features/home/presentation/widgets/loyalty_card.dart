import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/login_bottom_sheet.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/loob_skeleton.dart';
import '../../../settings/data/models/user_profile_model.dart';

class LoyaltyCard extends StatelessWidget {
  final UserProfileModel? profile;
  final bool isLoading;

  const LoyaltyCard({
    super.key,
    required this.profile,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoobSkeleton(width: 100, height: 10, borderRadius: 4),
                  SizedBox(height: 8),
                  LoobSkeleton(width: 60, height: 20, borderRadius: 4),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoobSkeleton(width: 100, height: 10, borderRadius: 4),
                  SizedBox(height: 8),
                  LoobSkeleton(width: 60, height: 20, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isGuest = profile == null;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: isGuest
          ? _GuestRewardsPrompt(theme: theme)
          : _MemberSummary(profile: profile!),
    );
  }
}

class _GuestRewardsPrompt extends StatelessWidget {
  final ThemeData theme;

  const _GuestRewardsPrompt({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.stars_rounded,
            color: theme.colorScheme.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.homeGuestRewardsTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.homeGuestRewardsDesc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          height: 36,
          child: FilledButton(
            onPressed: () => LoginBottomSheet.show(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.l10n.loginSignup,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberSummary extends StatelessWidget {
  final UserProfileModel profile;

  const _MemberSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Balance
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: theme.colorScheme.primary,
                      size: 11,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Balance (${(profile.currencyCode.isEmpty ? 'MYR' : profile.currencyCode).currencySymbol})',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GestureDetector(
                    onTap: () => context.showSuccessSnackBar(
                      context.l10n.topUpInitiated,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: theme.colorScheme.primary,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (profile.walletBalance / 100).toStringAsFixed(2),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        // Divider
        Container(
          height: 28,
          width: 1,
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        // TPoints
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFEE140), Color(0xFFFA709A)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        't',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'TPoints (PTS)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                profile.loyaltyPoints.toString(),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        // Barcode scanner button
        GestureDetector(
          onTap: () => context.push(AppRouter.barcode),
          child: Container(
            width: 44,
            height: 40,
            margin: const EdgeInsets.only(left: AppSpacing.xs),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
