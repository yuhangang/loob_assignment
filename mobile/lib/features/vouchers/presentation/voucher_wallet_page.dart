import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/status_message.dart';
import '../data/models/wallet_model.dart';
import '../data/models/voucher_model.dart';
import '../data/repositories/voucher_repository.dart';

// ── State ────────────────────────────────────────────────────────────────────

abstract class VoucherState extends Equatable {
  const VoucherState();
  @override
  List<Object?> get props => [];
}

class VoucherInitial extends VoucherState {}

class VoucherLoading extends VoucherState {}

class VoucherLoaded extends VoucherState {
  final WalletModel wallet;
  const VoucherLoaded(this.wallet);

  List<VoucherModel> get vouchers => wallet.vouchers;

  @override
  List<Object?> get props => [wallet];
}

class VoucherError extends VoucherState {
  final String message;
  const VoucherError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class VoucherCubit extends Cubit<VoucherState> {
  final VoucherRepository _repository;

  VoucherCubit({VoucherRepository? repository})
    : _repository = repository ?? sl<VoucherRepository>(),
      super(VoucherInitial());

  Future<void> loadWallet({
    String? countryCode,
    String? userId,
    int brandId = 0,
  }) async {
    emit(VoucherLoading());
    try {
      final wallet = await _repository.getWallet(
        countryCode: countryCode,
        userId: userId,
        brandId: brandId,
      );
      emit(VoucherLoaded(wallet));
    } catch (e) {
      emit(VoucherError(e.toString()));
    }
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────

class VoucherWalletPage extends StatefulWidget {
  const VoucherWalletPage({super.key});

  @override
  State<VoucherWalletPage> createState() => _VoucherWalletPageState();
}

class _VoucherWalletPageState extends State<VoucherWalletPage> {
  @override
  void initState() {
    super.initState();
    context.read<VoucherCubit>().loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: SafeArea(
        child: BlocListener<LanguageCubit, Locale>(
          listener: (context, locale) {
            context.read<VoucherCubit>().loadWallet();
          },
          child: BlocBuilder<VoucherCubit, VoucherState>(
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  if (canPop)
                    SliverAppBar(
                      pinned: true,
                      leading: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      centerTitle: true,
                      title: Text(
                        context.l10n.myVouchers,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: theme.scaffoldBackgroundColor,
                      elevation: 0,
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageHorizontal,
                          AppSpacing.xl,
                          AppSpacing.pageHorizontal,
                          AppSpacing.lg,
                        ),
                        child: Text(
                          context.l10n.myVouchers,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                    ),
                  if (state is VoucherLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (state is VoucherError)
                    SliverFillRemaining(
                      child: Center(child: Text(state.message)),
                    ),
                  if (state is VoucherLoaded)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageHorizontal,
                          0,
                          AppSpacing.pageHorizontal,
                          AppSpacing.lg,
                        ),
                        child: _WalletSummaryCard(wallet: state.wallet),
                      ),
                    ),
                  if (state is VoucherLoaded && state.vouchers.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: StatusMessage(
                        icon: Icons.confirmation_number_outlined,
                        title: context.l10n.noVouchersAvailable,
                        subtitle: context.l10n.noActiveVouchersSub,
                      ),
                    ),
                  if (state is VoucherLoaded && state.vouchers.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pageHorizontal,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final voucher = state.vouchers[index];
                          return _VoucherCard(
                            voucher: voucher,
                            currencyCode: state.wallet.currencyCode.isEmpty
                                ? 'MYR'
                                : state.wallet.currencyCode,
                          );
                        }, childCount: state.vouchers.length),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxxl),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  final WalletModel wallet;

  const _WalletSummaryCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                icon: Icons.account_balance_wallet_rounded,
                label: context.l10n.balance,
                value: wallet.walletBalance.toDisplayPrice(
                  wallet.currencyCode.isEmpty ? 'MYR' : wallet.currencyCode,
                ),
              ),
            ),
            Container(width: 1, height: 44, color: theme.dividerColor),
            Expanded(
              child: _SummaryMetric(
                icon: Icons.stars_rounded,
                label: context.l10n.tpoints,
                value: wallet.loyaltyPoints.toString(),
              ),
            ),
            Container(width: 1, height: 44, color: theme.dividerColor),
            Expanded(
              child: _SummaryMetric(
                icon: Icons.local_activity_rounded,
                label: context.l10n.vouchers,
                value: wallet.voucherCount.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
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

// ── Voucher Card Widget ──────────────────────────────────────────────────────

class _VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  final String currencyCode;

  const _VoucherCard({required this.voucher, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = voucher.status == 'AVAILABLE';

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              // Discount badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: Text(
                    voucher.discountType == 'PERCENTAGE'
                        ? '${voucher.discountValue}%'
                        : voucher.discountValue.toDisplayPrice(currencyCode),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      voucher.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      voucher.code,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              // Status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  _statusText(context, voucher.status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isAvailable ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(BuildContext context, String status) {
    switch (status) {
      case 'AVAILABLE':
        return context.l10n.statusAvailable;
      case 'USED':
        return context.l10n.statusUsed;
      case 'EXPIRED':
        return context.l10n.statusExpired;
      default:
        return status;
    }
  }
}
