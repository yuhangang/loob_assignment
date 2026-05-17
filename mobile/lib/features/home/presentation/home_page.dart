import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/brand.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../settings/data/models/user_profile_model.dart';
import '../../settings/presentation/user_profile_cubit.dart';
import '../data/models/app_config_model.dart';
import 'home_cubit.dart';
import 'widgets/collapsed_home_bar.dart';
import 'widgets/feed_card.dart';
import 'widgets/fulfillment_toggle.dart';
import 'widgets/hero_banner.dart';
import 'widgets/home_header_profile_row.dart';
import 'widgets/loyalty_card.dart';
import 'widgets/marketing_popup_dialog.dart';
import 'widgets/order_again_section.dart';

/// Main home page with brand immersion, loyalty card, fulfillment quick actions,
/// dynamic banners, "Order Again" recent orders list, and personalized feed.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeCubit _homeCubit;
  late final ScrollController _scrollController;
  bool _isDeliverySelected = true; // Fulfillment state toggle
  bool _isHeaderCollapsed = false; // Tracks whether SliverAppBar is collapsed

  // expandedHeight(210) - toolbarHeight(66) = 144 — the scroll offset at which
  // the header is fully collapsed and we swap to the compact title bar.
  static const double _collapseThreshold = 144.0;

  @override
  void initState() {
    super.initState();
    _homeCubit = HomeCubit();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lang = context.read<LanguageCubit>().state.languageCode;
      final brand = context.read<ThemeCubit>().state;
      _homeCubit.loadHome(language: lang, brandId: brand.brandId);
    });
  }

  void _onScroll() {
    final collapsed = _scrollController.offset > _collapseThreshold;
    if (collapsed != _isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _homeCubit.close();
    super.dispose();
  }

  void _showMarketingPopup(BuildContext context, MarketingPopupModel popup) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MarketingPopupDialog(popup: popup),
    );
  }

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.l10n.goodMorning;
    if (hour < 17) return context.l10n.goodAfternoon;
    return context.l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<ThemeCubit, LoobBrand>(
          listener: (context, brandState) {
            final lang = context.read<LanguageCubit>().state.languageCode;
            _homeCubit.loadHome(language: lang, brandId: brandState.brandId);
          },
        ),
        BlocListener<LanguageCubit, Locale>(
          listener: (context, localeState) {
            final brandState = context.read<ThemeCubit>().state;
            _homeCubit.loadHome(
              language: localeState.languageCode,
              brandId: brandState.brandId,
            );
          },
        ),
      ],
      child: BlocBuilder<HomeCubit, HomeState>(
        bloc: _homeCubit,
        builder: (context, state) {
          final config = state is HomeLoaded ? state.config : null;

          return Scaffold(
            floatingActionButton: config != null && config.marketingPopup.active
                ? FloatingActionButton.extended(
                    onPressed: () =>
                        _showMarketingPopup(context, config.marketingPopup),
                    label: Text(
                      config.marketingPopup.buttonText.isNotEmpty
                          ? config.marketingPopup.buttonText
                          : context.l10n.claimPromo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.celebration_rounded),
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  )
                : null,
            body: CustomScrollView(
              controller: _scrollController,
              slivers: [
                BlocBuilder<UserProfileCubit, UserProfileState>(
                  builder: (context, profileState) {
                    final profile = profileState is UserProfileLoaded
                        ? profileState.profile
                        : null;
                    return SliverAppBar(
                      pinned: true,
                      floating: false,
                      snap: false,
                      expandedHeight: 210,
                      toolbarHeight: 66,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      titleSpacing: 0,
                      // Only show collapsed bar once the expanded header has scrolled away
                      title: _isHeaderCollapsed
                          ? CollapsedHomeBar(profile: profile)
                          : null,
                      // Full expanded header content
                      flexibleSpace: _buildExpandedHeader(
                        context,
                        theme,
                        config,
                        _greeting(context),
                        profile,
                      ),
                    );
                  },
                ),

                // Spacing to account for the overlapping fulfillment toggle
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ── Brand Tab Bar (Hidden to match premium reference layout) ──
                const SliverToBoxAdapter(child: SizedBox.shrink()),

                // ── Hero Banner Carousel ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: HeroBanner(
                    items: state is HomeLoaded
                        ? state.banners
                              .map(
                                (c) => HeroBannerItem(
                                  title: c.title,
                                  subtitle: c.subtitle,
                                  imageUrl: c.imageUrl,
                                ),
                              )
                              .toList()
                        : [],
                  ),
                ),

                // ── "Order Again" / Recent Orders Section ────────────────────────
                SliverToBoxAdapter(
                  child: state is HomeLoaded && state.recentOrders.isNotEmpty
                      ? Builder(
                          builder: (context) {
                            final profileState =
                                context.watch<UserProfileCubit>().state;
                            final currency = profileState is UserProfileLoaded
                                ? profileState.profile.currencyCode
                                : 'MYR';
                            return OrderAgainSection(
                              products: state.recentOrders,
                              currency: currency.isEmpty ? 'MYR' : currency,
                            );
                          },
                        )
                      : const SizedBox.shrink(),
                ),

                // ── Personalized Feed Header ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      AppSpacing.lg,
                      AppSpacing.pageHorizontal,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          context.l10n.forYou,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Personalized Feed Items List ──────────────────────────────────
                if (state is HomeLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                else if (state is HomeError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(state.message),
                      ),
                    ),
                  )
                else if (state is HomeLoaded)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = state.feedItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: FeedCard(item: item),
                        );
                      }, childCount: state.feedItems.length),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox.shrink()),

                // Bottom space for comfortable navigation overlay
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandedHeader(
    BuildContext context,
    ThemeData theme,
    AppConfigModel? config,
    String greetingText,
    UserProfileModel? profile,
  ) {
    return FlexibleSpaceBar(
      collapseMode: CollapseMode.pin,
      background: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              8,
              AppSpacing.pageHorizontal,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeHeaderProfileRow(
                  greetingText: greetingText,
                  profile: profile,
                ),
                const SizedBox(height: 8),
                LoyaltyCard(profile: profile),
                const SizedBox(height: 8),
                FulfillmentToggle(
                  config: config,
                  isDeliverySelected: _isDeliverySelected,
                  onToggle: (val) {
                    setState(() => _isDeliverySelected = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
