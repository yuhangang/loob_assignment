import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/models/user_profile_model.dart';
import 'reward_metric.dart';
import 'history_section.dart';
import 'history_row.dart';

class RewardsCard extends StatelessWidget {
  final UserProfileModel profile;
  final WalletHistoryModel walletHistory;
  final LoyaltyHistoryModel loyaltyHistory;
  final bool isTopUpSubmitting;
  final VoidCallback onTopUp;

  const RewardsCard({
    super.key,
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
                  child: RewardMetric(
                    label: context.l10n.balance,
                    value: profile.walletBalance.toDisplayPrice(currency),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                Container(width: 1, height: 44, color: theme.dividerColor),
                Expanded(
                  child: RewardMetric(
                    label: context.l10n.tpoints,
                    value: profile.loyaltyPoints.toString(),
                    icon: Icons.stars_rounded,
                  ),
                ),
                Container(width: 1, height: 44, color: theme.dividerColor),
                Expanded(
                  child: RewardMetric(
                    label: context.l10n.tier,
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
                label: Text(context.l10n.walletTopUpAmount),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            HistorySection(
              title: context.l10n.walletActivity,
              emptyText: context.l10n.noWalletActivity,
              children: walletHistory.transactions
                  .take(3)
                  .map(
                    (tx) => HistoryRow(
                      icon: tx.amount >= 0
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                      title: _walletTitle(context, tx),
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
            HistorySection(
              title: context.l10n.pointsActivity,
              emptyText: context.l10n.noPointsActivity,
              children: loyaltyHistory.transactions
                  .take(3)
                  .map(
                    (tx) => HistoryRow(
                      icon: tx.pointsDelta >= 0
                          ? Icons.stars_rounded
                          : Icons.redeem_rounded,
                      title: _loyaltyTitle(context, tx),
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
    return rawTimestamp.toLocalDateTimeLabel();
  }

  String _walletTitle(BuildContext context, WalletTransactionModel tx) {
    switch (tx.transactionType) {
      case 'TOPUP':
        return context.l10n.walletTopUp;
      case 'SPEND':
        return context.l10n.walletSpend;
      case 'REFUND':
        return context.l10n.walletRefund;
      default:
        return context.l10n.walletAdjustment;
    }
  }

  String _loyaltyTitle(BuildContext context, LoyaltyTransactionModel tx) {
    switch (tx.transactionType) {
      case 'EARN':
        return context.l10n.pointsEarned;
      case 'REDEEM':
        return context.l10n.pointsRedeemed;
      case 'EXPIRE':
        return context.l10n.pointsExpired;
      default:
        return context.l10n.pointsAdjusted;
    }
  }
}
