import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:go_router/go_router.dart';

import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_state.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/status_message.dart';
import '../data/models/wallet_model.dart';
import '../data/models/voucher_model.dart';
import '../domain/repositories/voucher_repository.dart';

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
  final IVoucherRepository _repository;

  VoucherCubit({IVoucherRepository? repository})
    : _repository = repository ?? sl<IVoucherRepository>(),
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
    final country = context.read<CartBloc>().state.countryCode;
    context.read<VoucherCubit>().loadWallet(countryCode: country);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: SafeArea(
        child: BlocListener<CartBloc, CartState>(
          listenWhen: (previous, current) =>
              previous.countryCode != current.countryCode,
          listener: (context, cartState) {
            context.read<VoucherCubit>().loadWallet(
              countryCode: cartState.countryCode,
            );
          },
          child: BlocListener<LanguageCubit, Locale>(
            listener: (context, locale) {
              final country = context.read<CartBloc>().state.countryCode;
              context.read<VoucherCubit>().loadWallet(countryCode: country);
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
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.08),
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
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
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
      ),
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
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Discount badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
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
                const SizedBox(width: AppSpacing.md),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              voucher.title,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: voucher.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.voucherCodeCopied),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                voucher.code,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Status
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: GestureDetector(
                        onTap: () {
                          context.push(
                            AppRouter.voucherTerms,
                            extra: {'voucher': voucher},
                          );
                        },
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.grey500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Text(
                        _statusText(context, voucher.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isAvailable
                              ? AppColors.success
                              : AppColors.grey500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
