import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_guard.dart';
import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_event.dart';
import '../../cart/presentation/bloc/cart_item.dart';
import '../data/models/catalog_model.dart';
import 'widgets/dietary_tags_config.dart';
import 'widgets/product_card.dart';

class MenuSearchPage extends StatefulWidget {
  const MenuSearchPage({
    super.key,
    required this.catalog,
    required this.currency,
    required this.initialFavouritedIds,
    required this.onFavouriteToggled,
    required this.initialSelectedDietaryTags,
  });

  final CatalogModel catalog;
  final String currency;
  final Set<int> initialFavouritedIds;
  final ValueChanged<int> onFavouriteToggled;
  final Set<String> initialSelectedDietaryTags;

  @override
  State<MenuSearchPage> createState() => _MenuSearchPageState();
}

class _MenuSearchPageState extends State<MenuSearchPage> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final Set<String> _selectedDietaryTags = {};
  late final Set<int> _favouritedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _favouritedIds = Set<int>.from(widget.initialFavouritedIds);
    _selectedDietaryTags.addAll(widget.initialSelectedDietaryTags);

    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });

    // Request focus on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<ProductModel> _getFilteredProducts() {
    // Flatten all products across all categories
    final allProducts = widget.catalog.categories.expand((c) => c.products).toList();

    // Deduplicate products by id
    final seenIds = <int>{};
    final uniqueProducts = <ProductModel>[];
    for (final p in allProducts) {
      if (seenIds.add(p.id)) {
        uniqueProducts.add(p);
      }
    }

    return uniqueProducts.where((product) {
      // 1. Search Query Filter (name or description)
      if (_query.isNotEmpty) {
        final matchesName = product.name.toLowerCase().contains(_query);
        final matchesDesc = product.description.toLowerCase().contains(_query);
        if (!matchesName && !matchesDesc) {
          return false;
        }
      }

      // 2. Dietary Tags Filter
      if (_selectedDietaryTags.isNotEmpty) {
        final matchesAllTags = _selectedDietaryTags.every((tag) {
          if (tag == 'dairy_free') {
            return !product.dietaryTags.contains('contains_dairy');
          } else if (tag == 'peanut_free') {
            return !product.dietaryTags.contains('contains_peanuts');
          } else if (tag == 'caffeine_free') {
            return !product.dietaryTags.contains('caffeine');
          } else {
            return product.dietaryTags.contains(tag);
          }
        });
        if (!matchesAllTags) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  static const String _dietaryTagsPrefsKey = 'selected_dietary_tags';

  void _toggleDietaryTag(String tag) {
    setState(() {
      if (_selectedDietaryTags.contains(tag)) {
        _selectedDietaryTags.remove(tag);
      } else {
        _selectedDietaryTags.add(tag);
      }
    });
    _saveDietaryTags();
  }

  void _clearDietaryTags() {
    setState(() {
      _selectedDietaryTags.clear();
    });
    _saveDietaryTags();
  }

  void _saveDietaryTags() {
    try {
      final prefs = sl<SharedPreferences>();
      prefs.setStringList(_dietaryTagsPrefsKey, _selectedDietaryTags.toList());
    } catch (_) {}
  }

  Future<void> _showCustomization(ProductModel product, String currency) async {
    final result = await context.push(
      AppRouter.productDetail,
      extra: {'product': product, 'currency': currency},
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      final quantity = result['quantity'] as int;
      final selectionsMap =
          result['selections'] as Map<dynamic, dynamic>? ?? {};

      // Collect all selected option IDs across groups.
      final allOptionIds = <int>[];
      for (final ids in selectionsMap.values) {
        if (ids is List) {
          allOptionIds.addAll(ids.whereType<int>());
        }
      }

      // Resolve CustomizationOptionModel objects from the product definition.
      final selectedOptions = product.customizationGroups
          .expand((g) => g.options)
          .where((o) => allOptionIds.contains(o.id))
          .toList();

      final action = result['action'] as String? ?? 'add';

      if (action == 'buy_now') {
        final buyNowItem = CartItem(
          product: product,
          selectedOptions: selectedOptions,
          customizationOptionIds: allOptionIds,
          quantity: 1,
        );
        AuthGuard.run(context, () {
          context.push(AppRouter.checkout, extra: {'buyNowItem': buyNowItem});
        });
      } else {
        AuthGuard.run(context, () {
          context.read<CartBloc>().add(
            CartItemAdded(
              product: product,
              selectedOptions: selectedOptions,
              customizationOptionIds: allOptionIds,
              quantity: quantity,
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.addedToCartToast(quantity, product.name),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
    }
  }

  void _handleCartShortcut(ProductModel product, String currency) {
    if (product.customizationGroups.isNotEmpty) {
      _showCustomization(product, currency);
      return;
    }

    AuthGuard.run(context, () {
      context.read<CartBloc>().add(
        CartItemAdded(
          product: product,
          selectedOptions: const [],
          customizationOptionIds: const [],
          quantity: 1,
        ),
      );

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.addedToCartToast(1, product.name)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Widget _buildEmptyState(Color primaryColor) {
    final currentLang = context.read<LanguageCubit>().state.languageCode;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: primaryColor.withValues(alpha: 0.5),
              size: 80,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              currentLang == 'ms' ? 'Tiada Hasil Carian' : 'No Results Found',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              currentLang == 'ms'
                  ? 'Cuba selaraskan carian atau penapis diet anda.'
                  : 'Try adjusting your search query or dietary filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.grey600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedDietaryTags.isNotEmpty) ...[
                  OutlinedButton(
                    onPressed: _clearDietaryTags,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                    ),
                    child: Text(
                      currentLang == 'ms' ? 'Batal Penapis' : 'Clear Filters',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                if (_query.isNotEmpty)
                  OutlinedButton(
                    onPressed: () => _searchController.clear(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.grey400, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                    ),
                    child: Text(
                      currentLang == 'ms' ? 'Padam Carian' : 'Clear Search',
                      style: const TextStyle(
                        color: AppColors.grey700,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTealive = theme.colorScheme.primary.toARGB32() == 0xFF4C1D40;
    final isDiscover = theme.colorScheme.primary.toARGB32() == 0xFFB2C9AB;

    final primaryColor = isTealive
        ? AppColors.tealivePrimary
        : (isDiscover ? AppColors.discoverGreen : theme.colorScheme.primary);

    final currentLang = context.read<LanguageCubit>().state.languageCode;
    final filteredProducts = _getFilteredProducts();

    return Scaffold(
      backgroundColor: AppColors.softWhiteBg,
      body: SafeArea(
        child: Column(
          children: [
            // Custom premium search header bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.grey800,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.grey200,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(
                          color: AppColors.grey900,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: currentLang == 'ms'
                              ? 'Cari minuman, makanan...'
                              : 'Search for drinks, food...',
                          hintStyle: const TextStyle(
                            color: AppColors.grey400,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () => _searchController.clear(),
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    color: AppColors.grey400,
                                    size: 18,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
            ),

            // Sticky dietary tag chips row below search
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: DietaryFilterChips(
                selectedTags: _selectedDietaryTags,
                primaryColor: primaryColor,
                languageCode: currentLang,
                onTagToggled: _toggleDietaryTag,
                onClearAll: _clearDietaryTags,
              ),
            ),

            // Search results display area
            Expanded(
              child: filteredProducts.isEmpty
                  ? _buildEmptyState(primaryColor)
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final isFavourited = _favouritedIds.contains(product.id);

                        return ProductCard(
                          product: product,
                          currency: widget.currency,
                          isFavourited: isFavourited,
                          onFavouriteToggled: () {
                            widget.onFavouriteToggled(product.id);
                            setState(() {
                              if (_favouritedIds.contains(product.id)) {
                                _favouritedIds.remove(product.id);
                              } else {
                                _favouritedIds.add(product.id);
                              }
                            });
                          },
                          onTap: () => _showCustomization(
                            product,
                            widget.currency,
                          ),
                          onCartPressed: () => _handleCartShortcut(
                            product,
                            widget.currency,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
