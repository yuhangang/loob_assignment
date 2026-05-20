import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/bloc/auth_bloc.dart';
import '../../../core/auth/bloc/auth_event.dart';
import '../../../core/auth/bloc/auth_state.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/loob_error_dialog.dart';
import '../../../core/widgets/loob_loading_overlay.dart';
import '../../cart/data/models/checkout_response_model.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_event.dart';
import 'user_profile_cubit.dart';
import 'widgets/guest_card.dart';
import 'widgets/language_option_row.dart';
import 'widgets/profile_card.dart';
import 'widgets/rewards_card.dart';
import 'widgets/settings_error_card.dart';
import 'widgets/settings_group.dart';

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
                const GuestCard()
              else if (state is UserProfileLoading)
                const Center(child: CircularProgressIndicator())
              else if (state is UserProfileError)
                SettingsErrorCard(
                  message: state.message,
                  errorCode: state.errorCode,
                  traceId: state.traceId,
                  onRetry: () => context.read<UserProfileCubit>().loadProfile(),
                )
              else if (loadedState != null && profile != null) ...[
                ProfileCard(profile: profile),
                const SizedBox(height: AppSpacing.lg),
                RewardsCard(
                  profile: profile,
                  walletHistory: loadedState.walletHistory,
                  loyaltyHistory: loadedState.loyaltyHistory,
                  isTopUpSubmitting: loadedState.isTopUpSubmitting,
                  onTopUp: () async {
                    try {
                      LoobLoadingOverlay.show(
                        context,
                        message: 'Initiating top-up...',
                      );
                      final payment = await context
                          .read<UserProfileCubit>()
                          .topUpWallet(1000);
                      if (context.mounted) {
                        LoobLoadingOverlay.hide();
                        if (payment != null) {
                          _showMockPaymentGatewayBottomSheet(context, payment);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        LoobLoadingOverlay.hide();
                        LoobErrorDialog.show(
                          context,
                          title: 'Top-Up Failed',
                          message: e.toString().replaceAll('Exception: ', ''),
                        );
                      }
                    }
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SettingsGroup(
                title: context.l10n.preferences,
                items: [
                  SettingsItem(
                    icon: Icons.language,
                    title: context.l10n.language,
                    trailing: activeLocale.languageCode == 'ms'
                        ? 'Bahasa Melayu'
                        : 'English',
                    onTap: () => _showLanguageSwitcher(context),
                  ),
                  SettingsItem(
                    icon: Icons.public,
                    title: context.l10n.country,
                    trailing: _countryLabel(activeCountry),
                    onTap: () => _showCountrySwitcher(context, activeCountry),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SettingsGroup(
                title: context.l10n.support,
                items: [
                  SettingsItem(
                    icon: Icons.help_outline,
                    title: context.l10n.helpCentre,
                  ),
                  SettingsItem(
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

  void _showMockPaymentGatewayBottomSheet(
    BuildContext pageContext,
    PaymentTransactionResponseModel payment,
  ) {
    final theme = Theme.of(pageContext);
    final cubit = pageContext.read<UserProfileCubit>();

    showModalBottomSheet(
      context: pageContext,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetBodyContext, setState) {
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payment_rounded,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            context.l10n.mockPaymentGateway,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.l10n.simulatePaymentWalletTopup,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            _buildAmountRow(
                              context.l10n.transactionIdLabel,
                              payment.id,
                              theme,
                            ),
                            const Divider(height: AppSpacing.lg),
                            _buildAmountRow(
                              context.l10n.paymentMethodLabel,
                              payment.methodCode,
                              theme,
                            ),
                            const Divider(height: AppSpacing.lg),
                            _buildAmountRow(
                              context.l10n.amountLabel,
                              payment.amount.toDisplayPrice(
                                payment.currencyCode,
                              ),
                              theme,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          LoobLoadingOverlay.show(
                            pageContext,
                            message: 'Verifying payment...',
                          );
                          try {
                            await cubit.confirmMockPayment(payment.id);
                          } catch (e) {
                            if (!mounted) return;
                            LoobErrorDialog.show(
                              context,
                              title: 'Payment Verification Failed',
                              message: e.toString().replaceAll(
                                'Exception: ',
                                '',
                              ),
                            );
                          } finally {
                            LoobLoadingOverlay.hide();
                          }
                        },
                        icon: const Icon(Icons.verified_rounded),
                        label: Text(
                          context.l10n.confirmMockPaymentBtn,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAmountRow(
    String label,
    String value,
    ThemeData theme, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    final currentLocale = context.read<LanguageCubit>().state;
    final theme = Theme.of(context);
    final isAuthenticated = context.read<AuthBloc>().state is Authenticated;
    final activeCountry = context.read<CartBloc>().state.countryCode;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.transparent,
      builder: (modalContext) {
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
                LanguageOptionRow(
                  languageName: 'English',
                  isSelected: currentLocale.languageCode == 'en',
                  onTap: () async {
                    Navigator.of(modalContext).pop();
                    LoobLoadingOverlay.show(
                      context,
                      message: 'Updating language...',
                    );
                    try {
                      context.read<LanguageCubit>().switchLanguage('en');
                      if (isAuthenticated) {
                        await context
                            .read<UserProfileCubit>()
                            .updatePreferredLanguage('en');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        LoobErrorDialog.show(
                          context,
                          title: 'Update Failed',
                          message: e.toString().replaceAll('Exception: ', ''),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        LoobLoadingOverlay.hide();
                      }
                    }
                  },
                ),
                if (activeCountry != 'TH') ...[
                  const Divider(height: 1),
                  LanguageOptionRow(
                    languageName: 'Bahasa Melayu',
                    isSelected: currentLocale.languageCode == 'ms',
                    onTap: () async {
                      Navigator.of(modalContext).pop();
                      LoobLoadingOverlay.show(
                        context,
                        message: 'Updating language...',
                      );
                      try {
                        context.read<LanguageCubit>().switchLanguage('ms');
                        if (isAuthenticated) {
                          await context
                              .read<UserProfileCubit>()
                              .updatePreferredLanguage('ms');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          LoobErrorDialog.show(
                            context,
                            title: 'Update Failed',
                            message: e.toString().replaceAll('Exception: ', ''),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          LoobLoadingOverlay.hide();
                        }
                      }
                    },
                  ),
                ],
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
      useRootNavigator: true,
      backgroundColor: AppColors.transparent,
      builder: (modalContext) {
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
                LanguageOptionRow(
                  languageName: 'Malaysia',
                  isSelected: currentCountry == 'MY',
                  onTap: () async {
                    Navigator.of(modalContext).pop();
                    LoobLoadingOverlay.show(
                      context,
                      message: 'Switching region...',
                    );
                    try {
                      if (isAuthenticated) {
                        await context
                            .read<UserProfileCubit>()
                            .updateRegisteredCountry('MY');
                      }
                      if (context.mounted) {
                        context.read<CartBloc>().add(
                          const CartSwitchCountry(
                            countryCode: 'MY',
                            currency: 'MYR',
                          ),
                        );
                      }
                      await Future.delayed(const Duration(milliseconds: 1000));
                    } catch (e) {
                      if (context.mounted) {
                        LoobErrorDialog.show(
                          context,
                          title: 'Switch Region Failed',
                          message: e.toString().replaceAll('Exception: ', ''),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        LoobLoadingOverlay.hide();
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                LanguageOptionRow(
                  languageName: 'Thailand',
                  isSelected: currentCountry == 'TH',
                  onTap: () async {
                    Navigator.of(modalContext).pop();
                    LoobLoadingOverlay.show(
                      context,
                      message: 'Switching region...',
                    );
                    try {
                      if (isAuthenticated) {
                        await context
                            .read<UserProfileCubit>()
                            .updateRegisteredCountry('TH');
                      }
                      if (context.mounted) {
                        context.read<CartBloc>().add(
                          const CartSwitchCountry(
                            countryCode: 'TH',
                            currency: 'THB',
                          ),
                        );
                      }
                      await Future.delayed(const Duration(milliseconds: 1000));
                    } catch (e) {
                      if (context.mounted) {
                        LoobErrorDialog.show(
                          context,
                          title: 'Switch Region Failed',
                          message: e.toString().replaceAll('Exception: ', ''),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        LoobLoadingOverlay.hide();
                      }
                    }
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
