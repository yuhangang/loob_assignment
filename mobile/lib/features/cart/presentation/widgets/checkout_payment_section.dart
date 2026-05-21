import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/widgets/loob_skeleton.dart';
import '../bloc/cart_state.dart';
import '../bloc/checkout_cubit.dart';
import '../bloc/checkout_state.dart';
import 'checkout_section.dart';

class CheckoutPaymentSection extends StatelessWidget {
  final CartState cart;
  final CheckoutState state;

  const CheckoutPaymentSection({
    super.key,
    required this.cart,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final methods = state.methods
        .where((method) => state.getSubtotal(cart) >= method.minAmount)
        .toList(growable: false);

    return CheckoutSection(
      title: context.l10n.paymentTitle,
      child: state.isLoadingMethods
          ? Column(
              children: [
                for (int i = 0; i < 2; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        const LoobSkeleton(
                          width: 24,
                          height: 24,
                          borderRadius: 12,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const LoobSkeleton(
                                width: 120,
                                height: 16,
                                borderRadius: 4,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              const LoobSkeleton(
                                width: 180,
                                height: 12,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const LoobSkeleton(
                          width: 24,
                          height: 24,
                          borderRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : methods.isEmpty
          ? Text(
              context.l10n.noPaymentMethods,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          : Column(
              children: [
                for (final method in methods)
                  ListTile(
                    onTap: () => context
                        .read<CheckoutCubit>()
                        .selectPaymentMethod(method.code),
                    leading: Icon(
                      state.selectedMethod == method.code
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: state.selectedMethod == method.code
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    title: Text(method.displayName),
                    subtitle: Text(method.description),
                    trailing: Icon(
                      method.providerCode == 'mock_gateway'
                          ? Icons.bolt_rounded
                          : Icons.account_balance_wallet_outlined,
                    ),
                  ),
              ],
            ),
    );
  }
}
