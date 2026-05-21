import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../vouchers/data/models/voucher_model.dart';
import '../bloc/cart_state.dart';
import '../bloc/checkout_cubit.dart';
import '../bloc/checkout_state.dart';
import 'checkout_section.dart';

class CheckoutVoucherSection extends StatelessWidget {
  final TextEditingController voucherController;
  final CartState cart;
  final CheckoutState state;
  final VoidCallback onBrowsePressed;

  const CheckoutVoucherSection({
    super.key,
    required this.voucherController,
    required this.cart,
    required this.state,
    required this.onBrowsePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voucherValidation = state.voucherValidation;

    return CheckoutSection(
      title: context.l10n.voucherLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: voucherController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: context.l10n.optionalVoucherCode,
                    prefixIcon: const Icon(
                      Icons.confirmation_number_outlined,
                    ),
                  ),
                  onChanged: (value) {
                    context.read<CheckoutCubit>().onVoucherCodeChanged(value);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: onBrowsePressed,
                icon: const Icon(Icons.local_activity_rounded, size: 18),
                label: Text(context.l10n.browseBtn),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMd,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (state.activeVoucherCodes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: state.activeVoucherCodes.map((code) {
                final voucher = state.selectedVouchers
                    .cast<VoucherModel?>()
                    .firstWhere(
                      (v) => v?.code.toUpperCase() == code.toUpperCase(),
                      orElse: () => null,
                    );

                final isThisInvalid =
                    voucherValidation != null &&
                    !voucherValidation.isValid &&
                    voucherValidation.code.toUpperCase() ==
                        code.toUpperCase();

                final text = isThisInvalid
                    ? voucherValidation.reason ??
                          context.l10n.checkoutFailedMsg
                    : voucher == null
                    ? context.l10n.voucherWillBeValidated(code)
                    : context.l10n.voucherApplied(voucher.code);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isThisInvalid
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.primaryContainer)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusFull,
                    ),
                    border: Border.all(
                      color:
                          (isThisInvalid
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary)
                              .withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isThisInvalid
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary)
                                .withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isThisInvalid
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_rounded,
                        color: isThisInvalid
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isThisInvalid
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      GestureDetector(
                        onTap: () {
                          context.read<CheckoutCubit>().removeVoucher(code);
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color:
                                  (isThisInvalid
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.primary)
                                      .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: isThisInvalid
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
