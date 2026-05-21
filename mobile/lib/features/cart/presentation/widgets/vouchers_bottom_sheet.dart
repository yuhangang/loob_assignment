import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/loob_error_dialog.dart';
import '../../../../core/widgets/loob_loading_overlay.dart';
import '../../../../core/widgets/loob_skeleton.dart';
import '../../../vouchers/data/models/voucher_model.dart';
import '../../../vouchers/data/models/wallet_model.dart';
import '../../../vouchers/domain/repositories/voucher_repository.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_state.dart';
import '../bloc/checkout_cubit.dart';
import '../bloc/checkout_state.dart';
import '../../data/models/checkout_request_model.dart';

class VouchersBottomSheet extends StatefulWidget {
  final CartState cart;
  final Future<WalletModel> walletFuture;

  const VouchersBottomSheet({
    super.key,
    required this.cart,
    required this.walletFuture,
  });

  static Future<void> show(BuildContext parentContext, CartState cart) {
    final theme = Theme.of(parentContext);
    final checkoutCubit = parentContext.read<CheckoutCubit>();
    final walletFuture = sl<IVoucherRepository>().getWallet(
      countryCode: cart.countryCode,
      userId: parentContext.read<CartBloc>().userId,
    );

    return showModalBottomSheet(
      context: parentContext,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (modalContext) {
        return BlocProvider.value(
          value: checkoutCubit,
          child: VouchersBottomSheet(cart: cart, walletFuture: walletFuture),
        );
      },
    );
  }

  @override
  State<VouchersBottomSheet> createState() => _VouchersBottomSheetState();
}

class _VouchersBottomSheetState extends State<VouchersBottomSheet> {
  final Map<String, Future<Map<String, VoucherSheetEligibility>>>
  _voucherEligibilityFutures = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (scrollContext, scrollController) {
        return FutureBuilder<WalletModel>(
          future: widget.walletFuture,
          builder: (futureContext, snapshot) {
            return BlocBuilder<CheckoutCubit, CheckoutState>(
              builder: (context, state) {
                final hasVouchers =
                    snapshot.hasData &&
                    (snapshot.data?.vouchers.isNotEmpty ?? false);
                return Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            futureContext.l10n.selectVoucherTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(futureContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Content
                    Expanded(
                      child: _buildBottomSheetContent(
                        futureContext,
                        snapshot,
                        widget.cart,
                        scrollController,
                        state,
                      ),
                    ),
                    if (hasVouchers) ...[
                      const Divider(height: 1),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(futureContext),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull,
                                  ),
                                ),
                              ),
                              child: const Text('Apply Selection'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheetContent(
    BuildContext context,
    AsyncSnapshot<WalletModel> snapshot,
    CartState cart,
    ScrollController scrollController,
    CheckoutState state,
  ) {
    final theme = Theme.of(context);

    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (int i = 0; i < 3; i++)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.08),
                ),
              ),
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Row(
                  children: [
                    LoobSkeleton(
                      width: 64,
                      height: 64,
                      borderRadius: AppSpacing.radiusMd,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LoobSkeleton(width: 140, height: 16, borderRadius: 4),
                          SizedBox(height: AppSpacing.sm),
                          LoobSkeleton(width: 200, height: 12, borderRadius: 4),
                          SizedBox(height: AppSpacing.xs),
                          LoobSkeleton(width: 160, height: 12, borderRadius: 4),
                          SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              LoobSkeleton(
                                width: 80,
                                height: 20,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.unableLoadVouchers,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                snapshot.error.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final wallet = snapshot.data;
    final vouchers = wallet?.vouchers ?? const [];

    if (vouchers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_activity_outlined,
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                size: 64,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.noVouchersAvailable,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.noActiveVouchersSub,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final eligibilityKey = _voucherEligibilityKey(cart, state, vouchers);
    final eligibilityFuture = _voucherEligibilityFutures.putIfAbsent(
      eligibilityKey,
      () => _loadVoucherEligibility(cart, state, vouchers),
    );

    return FutureBuilder<Map<String, VoucherSheetEligibility>>(
      future: eligibilityFuture,
      builder: (context, eligibilitySnapshot) {
        final eligibilityByCode =
            eligibilitySnapshot.data ??
            const <String, VoucherSheetEligibility>{};
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: vouchers.length,
          itemBuilder: (context, index) {
            final voucher = vouchers[index];
            final localMinSpendEligible =
                state.getSubtotal(cart) >= voucher.minSpend;
            final eligibility =
                eligibilityByCode[voucher.code.toUpperCase()] ??
                VoucherSheetEligibility(
                  isEligible: localMinSpendEligible,
                  isLoading:
                      eligibilitySnapshot.connectionState !=
                      ConnectionState.done,
                  reason: localMinSpendEligible
                      ? null
                      : context.l10n.spendMoreToUse(
                          (voucher.minSpend - state.getSubtotal(cart))
                              .toDisplayPrice(cart.currency),
                        ),
                );
            final isEligible = eligibility.isEligible;
            final isSelected = state.selectedVouchers.any(
              (v) => v.code.toUpperCase() == voucher.code.toUpperCase(),
            );

            return Opacity(
              opacity: isEligible || isSelected ? 1.0 : 0.48,
              child: Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.dividerColor.withValues(alpha: 0.08),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                elevation: isSelected ? 2 : 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  onTap: isEligible || isSelected
                      ? () async {
                          final isSelected = state.selectedVouchers.any(
                            (v) =>
                                v.code.toUpperCase() ==
                                voucher.code.toUpperCase(),
                          );
                          if (isSelected) {
                            context.read<CheckoutCubit>().selectVoucher(
                              voucher,
                            );
                            return;
                          }

                          LoobLoadingOverlay.show(
                            context,
                            message: 'Validating voucher...',
                          );
                          try {
                            final result = await context
                                .read<CheckoutCubit>()
                                .validateAndSelectVoucher(
                                  voucher: voucher,
                                  cart: cart,
                                );

                            if (!context.mounted) return;
                            LoobLoadingOverlay.hide();

                            if (!result.isValid) {
                              LoobErrorDialog.show(
                                context,
                                title: 'Voucher Not Eligible',
                                message:
                                    result.message ??
                                    'This voucher is not eligible for this order.',
                              );
                              return;
                            }

                            if (result.replacedSelection) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${voucher.code} replaced your previous voucher selection.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            LoobLoadingOverlay.hide();
                            final message = e is ApiException
                                ? e.message
                                : 'Voucher validation failed';
                            LoobErrorDialog.show(
                              context,
                              title: 'Validation Error',
                              message: message,
                            );
                          }
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        // Discount badge container
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color:
                                (isEligible
                                        ? theme.colorScheme.primary
                                        : AppColors.grey500)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              voucher.discountType == 'PERCENTAGE'
                                  ? '${voucher.discountValue}%'
                                  : voucher.discountValue.toDisplayPrice(
                                      cart.currency,
                                    ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isEligible
                                    ? theme.colorScheme.primary
                                    : AppColors.grey500,
                                fontWeight: FontWeight.w900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Details column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      voucher.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  GestureDetector(
                                    onTap: () {
                                      context.push(
                                        AppRouter.voucherTerms,
                                        extra: {'voucher': voucher},
                                      );
                                    },
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                voucher.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: voucher.code),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.l10n.voucherCodeCopied,
                                          ),
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
                                        color:
                                            (isEligible
                                                    ? theme.colorScheme.primary
                                                    : AppColors.grey500)
                                                .withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusSm,
                                        ),
                                        border: Border.all(
                                          color:
                                              (isEligible
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : AppColors.grey500)
                                                  .withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            voucher.code,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: isEligible
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : AppColors.grey500,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Icon(
                                            Icons.copy_rounded,
                                            size: 12,
                                            color:
                                                (isEligible
                                                        ? theme
                                                              .colorScheme
                                                              .primary
                                                        : AppColors.grey500)
                                                    .withValues(alpha: 0.7),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isEligible)
                                Container(
                                  margin: const EdgeInsets.only(
                                    top: AppSpacing.sm,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    eligibility.reason ??
                                        'Not eligible for this order',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, VoucherSheetEligibility>> _loadVoucherEligibility(
    CartState cart,
    CheckoutState state,
    List<VoucherModel> vouchers,
  ) async {
    final repository = sl<IVoucherRepository>();
    final items = state
        .getItems(cart)
        .where((item) => item.isAvailable)
        .map(
          (item) => CartItemModel(
            menuItemId: item.product.id,
            quantity: item.quantity,
            customizationOptionIds: item.selectedCustomizationIds,
          ),
        )
        .toList();

    final entries = await Future.wait(
      vouchers.map((voucher) async {
        final code = voucher.code.toUpperCase();
        if (state.getSubtotal(cart) < voucher.minSpend) {
          return MapEntry(
            code,
            VoucherSheetEligibility(
              isEligible: false,
              reason: context.l10n.spendMoreToUse(
                (voucher.minSpend - state.getSubtotal(cart)).toDisplayPrice(
                  cart.currency,
                ),
              ),
            ),
          );
        }
        try {
          final validation = await repository.validateVoucher(
            countryCode: cart.countryCode,
            body: {
              'store_id': cart.storeId,
              'voucher_code': code,
              'voucher_codes': [code],
              'payment_method': state.selectedMethod ?? '',
              'items': items.map((item) => item.toJson()).toList(),
            },
          );
          return MapEntry(
            code,
            VoucherSheetEligibility(
              isEligible: validation.isValid,
              reason: validation.reason,
            ),
          );
        } catch (_) {
          return MapEntry(
            code,
            const VoucherSheetEligibility(isEligible: true),
          );
        }
      }),
    );
    return Map.fromEntries(entries);
  }

  String _voucherEligibilityKey(
    CartState cart,
    CheckoutState state,
    List<VoucherModel> vouchers,
  ) {
    final itemKey = state
        .getItems(cart)
        .where((item) => item.isAvailable)
        .map(
          (item) =>
              '${item.product.id}:${item.quantity}:${item.selectedCustomizationIds.join(".")}',
        )
        .join('|');
    final voucherKey = vouchers.map((voucher) => voucher.code).join('|');
    return [
      cart.countryCode,
      cart.storeId,
      state.selectedMethod ?? '',
      state.getSubtotal(cart),
      itemKey,
      voucherKey,
    ].join('::');
  }
}

class VoucherSheetEligibility {
  final bool isEligible;
  final bool isLoading;
  final String? reason;

  const VoucherSheetEligibility({
    required this.isEligible,
    this.isLoading = false,
    this.reason,
  });
}
