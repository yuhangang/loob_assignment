import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_event.dart';
import '../bloc/checkout_cubit.dart';
import '../bloc/checkout_state.dart';
import '../../data/models/price_breakdown_model.dart';
import '../../data/models/checkout_response_model.dart';
import 'checkout_amount_row.dart';
import 'checkout_collection_card.dart';
import 'checkout_section.dart';
import 'payment_success_header.dart';

class CheckoutPaymentResult extends StatelessWidget {
  final CheckoutResponseModel checkout;
  final String currency;
  final CheckoutState state;

  const CheckoutPaymentResult({
    super.key,
    required this.checkout,
    required this.currency,
    required this.state,
  });

  void _confirmMockPayment(BuildContext context) {
    final appConfig = sl<AppConfig>();
    final transactionId = checkout.payment?.id ?? '';
    context.read<CheckoutCubit>().confirmMockPayment(
      orderTrackingId: checkout.orderTrackingId,
      transactionId: transactionId,
      mockSecret: appConfig.mockGatewaySecret,
      onCartCleared: () => context.read<CartBloc>().add(const CartCleared()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid = state.mockPaidOrders.contains(checkout.orderTrackingId);
    final breakdown = PriceBreakdownModel(
      subtotal: checkout.subtotal,
      charges: checkout.charges,
      taxAmount: checkout.taxAmount,
      discountAmount: checkout.discountAmount,
      totalAmount: checkout.totalAmount,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        if (isPaid)
          PaymentSuccessHeader(
            orderTrackingId: checkout.orderTrackingId,
            title: context.l10n.mockPaymentApproved,
          )
        else ...[
          Icon(
            Icons.pending_actions_rounded,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.paymentPending,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            checkout.orderTrackingId,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        // ── Collection QR + PIN (shown once payment is confirmed) ────────
        if (isPaid) ...[
          CheckoutCollectionCard(trackingId: checkout.orderTrackingId),
          const SizedBox(height: AppSpacing.xl),
        ],

        CheckoutSection(
          title: context.l10n.paymentDetails,
          child: Column(
            children: [
              CheckoutAmountRow(
                label: context.l10n.subtotalLabel,
                value: checkout.subtotal.toDisplayPrice(currency),
              ),
              for (final charge in checkout.charges.where(
                (charge) => !charge.waived,
              ))
                CheckoutAmountRow(
                  label: charge.name.isEmpty ? charge.code : charge.name,
                  value: charge.totalAmount.toDisplayPrice(currency),
                ),
              for (final charge in checkout.charges.where(
                (charge) => charge.waived,
              ))
                CheckoutAmountRow(
                  label: charge.name.isEmpty ? charge.code : charge.name,
                  value: context.l10n.waivedLabel,
                ),
              if (breakdown.payableTaxAmount > 0)
                CheckoutAmountRow(
                  label: context.l10n.taxLabel,
                  value: breakdown.payableTaxAmount.toDisplayPrice(currency),
                ),
              if (checkout.discountAmount > 0)
                CheckoutAmountRow(
                  label: context.l10n.discountLabel,
                  value: '-${checkout.discountAmount.toDisplayPrice(currency)}',
                ),
              if (breakdown.includedTaxAmount > 0)
                CheckoutAmountRow(
                  label: context.l10n.includedTaxLabel,
                  value: breakdown.includedTaxAmount.toDisplayPrice(currency),
                ),
              const Divider(height: AppSpacing.xl),
              CheckoutAmountRow(
                label: context.l10n.totalLabel,
                value: checkout.totalAmount.toDisplayPrice(currency),
                isTotal: true,
              ),
              if (checkout.payment != null) ...[
                const SizedBox(height: AppSpacing.md),
                CheckoutAmountRow(
                  label: context.l10n.methodLabel,
                  value: checkout.payment!.methodCode,
                ),
                CheckoutAmountRow(
                  label: context.l10n.providerLabel,
                  value: checkout.payment!.provider,
                ),
                CheckoutAmountRow(
                  label: context.l10n.statusLabel,
                  value: isPaid ? 'SUCCESS' : checkout.payment!.status,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!isPaid)
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: state.isCheckingOut
                  ? null
                  : () => _confirmMockPayment(context),
              icon: state.isCheckingOut
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.verified_rounded),
              label: Text(
                state.isCheckingOut
                    ? 'Confirming...'
                    : context.l10n.confirmMockPayment,
              ),
            ),
          )
        else
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                context.pushReplacement(
                  AppRouter.orderStatus,
                  extra: {'trackingId': checkout.orderTrackingId},
                );
              },
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(context.l10n.viewOrderStatus),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
