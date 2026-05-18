import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../data/models/campaign_model.dart';
import '../data/models/home_feed_model.dart';
import '../domain/repositories/campaign_repository.dart';

// ── State ────────────────────────────────────────────────────────────────────

abstract class CampaignsState extends Equatable {
  const CampaignsState();
  @override
  List<Object?> get props => [];
}

class CampaignsInitial extends CampaignsState {}

class CampaignsLoading extends CampaignsState {}

class CampaignsLoaded extends CampaignsState {
  final HomeFeedModel feed;
  const CampaignsLoaded(this.feed);
  @override
  List<Object?> get props => [feed];
}

class CampaignsError extends CampaignsState {
  final String message;
  const CampaignsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class CampaignsCubit extends Cubit<CampaignsState> {
  final ICampaignRepository _repository;

  CampaignsCubit({ICampaignRepository? repository})
      : _repository = repository ?? sl<ICampaignRepository>(),
        super(CampaignsInitial());

  Future<void> loadCampaigns({
    String countryCode = 'MY',
    String language = 'en',
    int? brandId,
  }) async {
    emit(CampaignsLoading());
    try {
      final feed = await _repository.getHomeFeed(
        countryCode: countryCode,
        language: language,
        brandId: brandId,
      );
      emit(CampaignsLoaded(feed));
    } catch (e) {
      emit(CampaignsError(e.toString()));
    }
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  late final CampaignsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = CampaignsCubit();
    Future.microtask(() => _loadCampaigns());
  }

  void _loadCampaigns() {
    if (!mounted) return;
    final lang = context.read<LanguageCubit>().state.languageCode;
    _cubit.loadCampaigns(language: lang);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: BlocListener<LanguageCubit, Locale>(
        listener: (context, locale) => _loadCampaigns(),
        child: BlocBuilder<CampaignsCubit, CampaignsState>(
          bloc: _cubit,
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      AppSpacing.xl,
                      AppSpacing.pageHorizontal,
                      AppSpacing.lg,
                    ),
                    child: Text(
                      context.l10n.campaignsTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
                if (state is CampaignsLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state is CampaignsError)
                  SliverFillRemaining(
                    child: Center(child: Text(state.message)),
                  ),
                if (state is CampaignsLoaded) ...[
                  // Banners section
                  if (state.feed.banners.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                        ),
                        child: Text(context.l10n.banners,
                            style: theme.textTheme.titleLarge),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: state.feed.banners.length,
                          itemBuilder: (context, index) {
                            final banner = state.feed.banners[index];
                            return _CampaignBanner(campaign: banner);
                          },
                        ),
                      ),
                    ),
                  ],
                  // Modules section
                  if (state.feed.modules.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(context.l10n.activities,
                            style: theme.textTheme.titleLarge),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pageHorizontal,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final module = state.feed.modules[index];
                            return _ModuleCard(campaign: module);
                          },
                          childCount: state.feed.modules.length,
                        ),
                      ),
                    ),
                  ],
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


// ── Campaign Banner ──────────────────────────────────────────────────────────

class _CampaignBanner extends StatelessWidget {
  final CampaignModel campaign;

  const _CampaignBanner({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            campaign.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            campaign.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Module Card ──────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  final CampaignModel campaign;

  const _ModuleCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.cardPadding),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Icon(
            _iconForType(campaign.type),
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          campaign.title,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          campaign.subtitle,
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'DAILY_CHECKIN':
        return Icons.calendar_today_rounded;
      case 'MINI_GAME':
        return Icons.gamepad_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }
}
