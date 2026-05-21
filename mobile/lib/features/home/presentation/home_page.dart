import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/bloc/auth_bloc.dart';
import '../../../core/auth/bloc/auth_state.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/brand.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/loob_spinner.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_state.dart';
import '../../settings/data/models/user_profile_model.dart';
import '../../settings/presentation/user_profile_cubit.dart';
import '../data/models/app_config_model.dart';
import 'home_cubit.dart';
import 'widgets/collapsed_home_bar.dart';
import 'widgets/feed_card.dart';
import 'widgets/hero_banner.dart';
import 'widgets/home_error_view.dart';
import 'widgets/home_header_profile_row.dart';
import 'widgets/loyalty_card.dart';
import 'widgets/order_again_section.dart';

/// Main home page with brand immersion, loyalty card, dynamic banners,
/// "Order Again" recent orders list, and personalized feed.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScrollController _scrollController;
  bool _isHeaderCollapsed = false; // Tracks whether SliverAppBar is collapsed

  // expandedHeight(210) - toolbarHeight(66) = 144 — the scroll offset at which
  // the header is fully collapsed and we swap to the compact title bar.
  static const double _collapseThreshold = 144.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reloadHome(context);
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
    super.dispose();
  }

  void _reloadHome(BuildContext context) {
    final lang = context.read<LanguageCubit>().state.languageCode;
    final brand = context.read<ThemeCubit>().state;
    final country = context.read<CartBloc>().state.countryCode;
    context.read<HomeCubit>().loadHome(
          countryCode: country,
          language: lang,
          brandId: brand.brandId,
        );
  }

  Future<void> _refreshEntireHomePage(BuildContext context) async {
    final lang = context.read<LanguageCubit>().state.languageCode;
    final brand = context.read<ThemeCubit>().state;
    final country = context.read<CartBloc>().state.countryCode;

    await Future.wait([
      context.read<HomeCubit>().loadHome(
            countryCode: country,
            language: lang,
            brandId: brand.brandId,
          ),
      context.read<UserProfileCubit>().loadProfile(),
    ]);
  }

  bool _authScopeChanged(AuthState previous, AuthState current) {
    final previousUser = previous is Authenticated ? previous.user.uid : '';
    final currentUser = current is Authenticated ? current.user.uid : '';
    final authBoundaryChanged =
        previous is Authenticated ||
        current is Authenticated ||
        current is Unauthenticated;
    return previousUser != currentUser ||
        (previous.runtimeType != current.runtimeType && authBoundaryChanged);
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
            _reloadHome(context);
          },
        ),
        BlocListener<LanguageCubit, Locale>(
          listener: (context, localeState) {
            _reloadHome(context);
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: _authScopeChanged,
          listener: (context, authState) {
            _reloadHome(context);
          },
        ),
        BlocListener<CartBloc, CartState>(
          listenWhen: (previous, current) =>
              previous.countryCode != current.countryCode,
          listener: (context, cartState) {
            _reloadHome(context);
          },
        ),
      ],
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final config = state is HomeLoaded ? state.config : null;

          return Scaffold(
            body: RefreshIndicator(
              onRefresh: () => _refreshEntireHomePage(context),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  BlocBuilder<UserProfileCubit, UserProfileState>(
                    builder: (context, profileState) {
                      final profile = profileState is UserProfileLoaded
                          ? profileState.profile
                          : null;
                      final isProfileLoading =
                          profileState is UserProfileLoading ||
                          profileState is UserProfileInitial;
                      final hasProfileError = profileState is UserProfileError;
  
                      return SliverAppBar(
                        pinned: true,
                        floating: false,
                        snap: false,
                        expandedHeight: 144,
                        toolbarHeight: 66,
                        backgroundColor: theme.scaffoldBackgroundColor,
                        surfaceTintColor: AppColors.transparent,
                        elevation: 0,
                        automaticallyImplyLeading: false,
                        titleSpacing: 0,
                        // Only show collapsed bar once the expanded header has scrolled away
                        title: _isHeaderCollapsed
                            ? CollapsedHomeBar(
                                profile: profile,
                                isLoading: isProfileLoading,
                              )
                            : null,
                        // Full expanded header content
                        flexibleSpace: _buildExpandedHeader(
                          context,
                          theme,
                          config,
                          _greeting(context),
                          profile,
                          isProfileLoading,
                          hasProfileError: hasProfileError,
                        ),
                      );
                    },
                  ),

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
                            final profileState = context
                                .watch<UserProfileCubit>()
                                .state;
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
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                        child: LoobSpinner(size: 56.0),
                      ),
                    ),
                  )
                else if (state is HomeError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: HomeErrorView(
                      message: state.message,
                      onRetry: () => _refreshEntireHomePage(context),
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
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: AppSpacing.xxl + context.cartFloatingBarPadding,
                  ),
                ),
              ],
            ),
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
    bool isProfileLoading, {
    bool hasProfileError = false,
  }) {
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
                if (hasProfileError)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_off_rounded,
                              color: theme.colorScheme.error,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.homeHeaderSyncFailed,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                context.l10n.guestLabel,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  HomeHeaderProfileRow(
                    greetingText: greetingText,
                    profile: profile,
                    isLoading: isProfileLoading,
                  ),
                const SizedBox(height: 8),
                if (hasProfileError)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.error.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.signal_wifi_off_rounded,
                            color: theme.colorScheme.error,
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
                                context.l10n.homeHeaderSyncFailed,
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
                                context.l10n.homeHeaderSyncFailedDesc,
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
                          child: FilledButton.icon(
                            onPressed: () => _refreshEntireHomePage(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: Text(
                              context.l10n.retry,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  LoyaltyCard(
                    profile: profile,
                    isLoading: isProfileLoading,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
