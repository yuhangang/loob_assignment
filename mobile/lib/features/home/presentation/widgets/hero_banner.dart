import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';

/// Edge-to-edge premium hero banner carousel.
class HeroBanner extends StatefulWidget {
  final List<HeroBannerItem> items;

  const HeroBanner({super.key, required this.items});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final appConfig = sl<AppConfig>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final imageUrl = _resolveImageUrl(item.imageUrl, appConfig.baseUrl);

              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageHorizontal,
                  vertical: AppSpacing.sm,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner Background Image or fallback gradient
                      imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  _buildFallbackGradient(theme),
                              placeholder: (context, url) => Container(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            )
                          : _buildFallbackGradient(theme),

                      // Elegant Dark Vignette Overlay for Text Legibility
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.black.withValues(alpha: 0.8),
                                AppColors.black.withValues(alpha: 0.2),
                                AppColors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Premium Text Overlay Content
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(
                                    color: AppColors.black.withValues(alpha: 0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              item.subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: AppColors.black.withValues(alpha: 0.3),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Premium Floating 'View All' Pill Button
                      Positioned(
                        right: AppSpacing.lg,
                        bottom: AppSpacing.lg,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'View All',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Carousel Dot Indicators
        if (widget.items.length > 1) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.items.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentPage == index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFallbackGradient(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  String _resolveImageUrl(String? url, String baseUrl) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // Prepends host if it starts with '/cdn'
    if (url.startsWith('/cdn')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/cdn/$url';
  }
}

class HeroBannerItem {
  final String title;
  final String subtitle;
  final String? imageUrl;

  const HeroBannerItem({
    required this.title,
    required this.subtitle,
    this.imageUrl,
  });
}
