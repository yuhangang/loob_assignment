import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_guard.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/brand.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_event.dart';
import '../../cart/presentation/bloc/cart_item.dart';
import '../../cart/presentation/bloc/cart_state.dart';
import '../data/models/catalog_model.dart';
import '../data/models/store_model.dart';
import 'menu_bloc.dart';
import 'menu_page_cubit.dart';
import 'widgets/dietary_tags_config.dart';
import 'widgets/menu_error_view.dart';
import 'widgets/menu_header_delegate.dart';
import 'widgets/menu_loading_skeleton.dart';
import 'widgets/product_card.dart';
import 'widgets/sidebar_category_tab.dart';

/// Category-grouped menu page for the active brand with vertical category sidebar navigation.
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late final MenuBloc _menuBloc;
  late final MenuPageCubit _pageCubit;
  final GlobalKey _listViewKey = GlobalKey();
  final Map<int, GlobalKey> _categoryKeys = {};

  @override
  void initState() {
    super.initState();
    _menuBloc = MenuBloc();
    _pageCubit = MenuPageCubit();
    _loadMenu();
  }

  void _loadMenu({int? storeId}) {
    if (!mounted) return;
    final brand = context.read<ThemeCubit>().state;
    final brandId = brand.brandId ?? LoobBrand.tealive.brandId!;
    final lang = context.read<LanguageCubit>().state.languageCode;
    final resolvedStoreId = storeId ?? _pageCubit.state.selectedStoreId;
    final country = context.read<CartBloc>().state.countryCode;

    _menuBloc.add(
      LoadMenu(
        countryCode: country,
        language: lang,
        storeId: resolvedStoreId,
        brandId: brandId,
      ),
    );
  }

  @override
  void dispose() {
    _menuBloc.close();
    _pageCubit.close();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_pageCubit.state.isProgrammaticScroll) return false;

    final context = this.context;
    if (!context.mounted) return false;

    final state = _menuBloc.state;
    if (state is! MenuLoaded) return false;
    final rawEnhanced = _buildEnhancedCategories(state.catalog);
    final enhancedCategories = _filterCategories(
      rawEnhanced,
      _pageCubit.state.selectedDietaryTags,
    );

    final listViewBox =
        _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    final double viewportTop = listViewBox != null
        ? listViewBox.localToGlobal(Offset.zero).dy
        : 180.0;

    int? activeId;

    final pixels = notification.metrics.pixels;
    final maxScrollExtent = notification.metrics.maxScrollExtent;

    if (pixels >= maxScrollExtent - 40) {
      activeId = enhancedCategories.lastOrNull?.id;
    } else {
      for (final category in enhancedCategories) {
        final key = _categoryKeys[category.id];
        if (key == null) continue;
        final currentCtx = key.currentContext;
        if (currentCtx == null) continue;

        final renderBox = currentCtx.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) continue;

        final position = renderBox.localToGlobal(Offset.zero);
        final relativeY = position.dy - viewportTop;

        if (relativeY <= 50.0) {
          activeId = category.id;
        }
      }
    }

    if (activeId != null && activeId != _pageCubit.state.selectedCategoryId) {
      _pageCubit.selectCategory(activeId);
    }

    return false;
  }

  void _onCategoryTabTap(int categoryId) {
    if (_pageCubit.state.selectedCategoryId == categoryId) return;

    _pageCubit.selectCategory(categoryId);

    final key = _categoryKeys[categoryId];
    final context = key?.currentContext;
    if (context == null) return;

    _pageCubit.setProgrammaticScroll(true);

    Scrollable.ensureVisible(
      context,
      alignment: 0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageCubit.setProgrammaticScroll(false);
      });
    });
  }

  // Prepend dynamic Favourites Category to the Catalog
  List<CategoryModel> _buildEnhancedCategories(CatalogModel catalog) {
    // Build Favourites Category from backend catalog products
    final allProducts = catalog.categories.expand((c) => c.products).toList();

    final favouritedProducts = allProducts
        .where((p) => _pageCubit.state.favouritedIds.contains(p.id))
        .toList();

    final List<CategoryModel> enhanced = [];

    // Prepend Favourites Category if there is data
    if (favouritedProducts.isNotEmpty) {
      enhanced.add(
        CategoryModel(
          id: -99,
          displayOrder: -99,
          name: context.l10n.favouritesCategory,
          iconUrl: '',
          products: favouritedProducts,
        ),
      );
    }

    // Append Backend Categories
    enhanced.addAll(catalog.categories);

    return enhanced;
  }

  List<CategoryModel> _filterCategories(
    List<CategoryModel> categories,
    Set<String> selectedTags,
  ) {
    if (selectedTags.isEmpty) return categories;

    return categories
        .map((category) {
          final filteredProducts = category.products.where((product) {
            return selectedTags.every((tag) {
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
          }).toList();

          return CategoryModel(
            id: category.id,
            displayOrder: category.displayOrder,
            name: category.name,
            iconUrl: category.iconUrl,
            products: filteredProducts,
          );
        })
        .where((category) => category.products.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTealive = theme.colorScheme.primary.toARGB32() == 0xFF4C1D40;
    final isDiscover = theme.colorScheme.primary.toARGB32() == 0xFFB2C9AB;

    // Core brand purple color
    final primaryColor = isTealive
        ? AppColors.tealivePrimary
        : (isDiscover ? AppColors.discoverGreen : theme.colorScheme.primary);

    return BlocProvider<MenuPageCubit>.value(
      value: _pageCubit,
      child: BlocBuilder<MenuPageCubit, MenuPageLocalState>(
        bloc: _pageCubit,
        builder: (context, localState) {
          return MultiBlocListener(
            listeners: [
              BlocListener<ThemeCubit, LoobBrand>(
                listener: (context, brand) {
                  if (localState.isChangingStoreAcrossBrands) {
                    _pageCubit.setChangingStoreAcrossBrands(false);
                    return;
                  }
                  _pageCubit.selectStore(null);
                  _pageCubit.selectCategory(null);
                  _loadMenu(storeId: null);
                },
              ),
              BlocListener<LanguageCubit, Locale>(
                listener: (context, locale) => _loadMenu(),
              ),
              BlocListener<CartBloc, CartState>(
                listenWhen: (previous, current) =>
                    previous.countryCode != current.countryCode,
                listener: (context, cartState) {
                  _pageCubit.selectStore(null);
                  _pageCubit.selectCategory(null);
                  _loadMenu(storeId: null);
                },
              ),
              BlocListener<MenuBloc, MenuState>(
                bloc: _menuBloc,
                listener: (context, state) {
                  if (state is MenuLoaded) {
                    context.read<CartBloc>().add(
                      CartSetStore(state.selectedStore),
                    );
                  }
                },
              ),
              BlocListener<CartBloc, CartState>(
                listener: (context, state) {
                  final pendingStoreId =
                      localState.pendingStoreChangeWarningStoreId;
                  if (pendingStoreId == null ||
                      state.loadStatus != CartLoadStatus.loaded ||
                      state.storeId != pendingStoreId) {
                    return;
                  }

                  _pageCubit.setPendingStoreChange(null);
                  if (state.items.isEmpty ||
                      (!state.hasUnavailableItems &&
                          !state.hasUnavailableOptions)) {
                    return;
                  }
                  _showCartAvailabilityWarning(state);
                },
              ),
            ],
            child: SafeArea(
              child: BlocBuilder<MenuBloc, MenuState>(
                bloc: _menuBloc,
                builder: (context, state) {
                  if (state is MenuLoading) {
                    return MenuLoadingSkeleton(primaryColor: primaryColor);
                  }
                  if (state is MenuError) {
                    return MenuErrorView(
                      primaryColor: primaryColor,
                      message: state.message,
                      onRetry: _loadMenu,
                    );
                  }
                  if (state is MenuLoaded) {
                    final catalog = state.catalog;

                    // Sync selected store id with BLoC state securely
                    if (localState.selectedStoreId != state.selectedStore.id) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _pageCubit.selectStore(state.selectedStore.id);
                      });
                    }

                    // Build dynamic categories (Favourites + LTO + Backend)
                    final rawEnhanced = _buildEnhancedCategories(catalog);
                    final enhancedCategories = _filterCategories(
                      rawEnhanced,
                      localState.selectedDietaryTags,
                    );

                    // Default to the first available category if none is selected or if the selected one is no longer available
                    final selectedCatId = localState.selectedCategoryId;
                    if (selectedCatId == null ||
                        !enhancedCategories.any((c) => c.id == selectedCatId)) {
                      final defaultCatId = enhancedCategories.isNotEmpty
                          ? enhancedCategories.first.id
                          : null;
                      if (defaultCatId != selectedCatId) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _pageCubit.selectCategory(defaultCatId);
                        });
                      }
                    }

                    for (final category in enhancedCategories) {
                      _categoryKeys.putIfAbsent(category.id, GlobalKey.new);
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Sidebar Navigation (Width 85) - Completely static & fixed!
                        Container(
                          width: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            border: Border(
                              right: BorderSide(
                                color: AppColors.dividerBeige,
                                width: 1,
                              ),
                            ),
                          ),
                          child: ListView.builder(
                            itemCount: enhancedCategories.length,
                            itemBuilder: (context, index) {
                              final category = enhancedCategories[index];
                              final isSelected =
                                  category.id == localState.selectedCategoryId;

                              return SidebarCategoryTab(
                                category: category,
                                isSelected: isSelected,
                                primaryColor: primaryColor,
                                favouritedCount:
                                    localState.favouritedIds.length,
                                onTap: () => _onCategoryTabTap(category.id),
                              );
                            },
                          ),
                        ),

                        // Right side collapsible header and products
                        Expanded(
                          child: NestedScrollView(
                            headerSliverBuilder: (context, innerBoxIsScrolled) {
                              return [
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: MenuHeaderDelegate(
                                    brandName: catalog.brand,
                                    selectedStore: state.selectedStore,
                                    primaryColor: primaryColor,
                                    onChangeOutlet: () => _showStoreSelector(
                                      stores: state.stores,
                                      selectedStoreId: state.selectedStore.id,
                                    ),
                                    onSearchTap: () async {
                                      await context.push(
                                        AppRouter.menuSearch,
                                        extra: {
                                          'catalog': catalog,
                                          'currency': catalog.currency,
                                          'favouritedIds':
                                              localState.favouritedIds,
                                          'onFavouriteToggled':
                                              (int productId) {
                                                _pageCubit.toggleFavourite(
                                                  productId,
                                                );
                                              },
                                          'initialSelectedDietaryTags':
                                              localState.selectedDietaryTags,
                                        },
                                      );
                                      if (mounted) {
                                        _pageCubit.reloadDietaryTags();
                                      }
                                    },
                                  ),
                                ),
                              ];
                            },
                            body: Container(
                              color: AppColors.softWhiteBg,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.md,
                                      AppSpacing.xs,
                                      AppSpacing.md,
                                      0,
                                    ),
                                    child: DietaryFilterChips(
                                      selectedTags:
                                          localState.selectedDietaryTags,
                                      primaryColor: primaryColor,
                                      languageCode: context
                                          .read<LanguageCubit>()
                                          .state
                                          .languageCode,
                                      onTagToggled: (tag) =>
                                          _pageCubit.toggleDietaryTag(tag),
                                      onClearAll: () =>
                                          _pageCubit.clearDietaryTags(),
                                    ),
                                  ),
                                  Expanded(
                                    child: enhancedCategories.isEmpty
                                        ? _buildFiltersEmptyState(primaryColor)
                                        : NotificationListener<
                                            ScrollNotification
                                          >(
                                            onNotification: (notification) {
                                              if (notification.depth == 0) {
                                                _onScrollNotification(
                                                  notification,
                                                );
                                              }
                                              return false;
                                            },
                                            child: SingleChildScrollView(
                                              key: _listViewKey,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.md,
                                                    vertical: AppSpacing.md,
                                                  ),
                                              child: Column(
                                                children: [
                                                  for (final category
                                                      in enhancedCategories) ...[
                                                    Container(
                                                      key:
                                                          _categoryKeys[category
                                                              .id],
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: AppSpacing.md,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          // Category Title Header
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  category.name,
                                                                  style: theme
                                                                      .textTheme
                                                                      .headlineSmall
                                                                      ?.copyWith(
                                                                        color:
                                                                            primaryColor,
                                                                        fontWeight:
                                                                            FontWeight.w900,
                                                                        fontSize:
                                                                            22,
                                                                      ),
                                                                ),
                                                              ),
                                                              if (category.id ==
                                                                  -99)
                                                                Text(
                                                                  '${localState.favouritedIds.length} / 6',
                                                                  style: TextStyle(
                                                                    color: primaryColor
                                                                        .withValues(
                                                                          alpha:
                                                                              0.6,
                                                                        ),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height:
                                                                AppSpacing.md,
                                                          ),

                                                          // Product Grid (2 columns) or empty state for Favourites
                                                          category.id == -99 &&
                                                                  category
                                                                      .products
                                                                      .isEmpty
                                                              ? _buildFavouritesEmptyState(
                                                                  primaryColor,
                                                                )
                                                              : GridView.builder(
                                                                  shrinkWrap:
                                                                      true,
                                                                  physics:
                                                                      const NeverScrollableScrollPhysics(),
                                                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                                    crossAxisCount:
                                                                        2,
                                                                    childAspectRatio:
                                                                        0.65,
                                                                    crossAxisSpacing:
                                                                        AppSpacing
                                                                            .md,
                                                                    mainAxisSpacing:
                                                                        AppSpacing
                                                                            .md,
                                                                  ),
                                                                  itemCount: category
                                                                      .products
                                                                      .length,
                                                                  itemBuilder:
                                                                      (
                                                                        context,
                                                                        index,
                                                                      ) {
                                                                        final product =
                                                                            category.products[index];
                                                                        final isFavourited = localState
                                                                            .favouritedIds
                                                                            .contains(
                                                                              product.id,
                                                                            );

                                                                        return ProductCard(
                                                                          product:
                                                                              product,
                                                                          currency:
                                                                              catalog.currency,
                                                                          isFavourited:
                                                                              isFavourited,
                                                                          onFavouriteToggled: () {
                                                                            _pageCubit.toggleFavourite(
                                                                              product.id,
                                                                            );
                                                                          },
                                                                          onTap: () => _showCustomization(
                                                                            product,
                                                                            catalog.currency,
                                                                          ),
                                                                          onCartPressed: () => _handleCartShortcut(
                                                                            product,
                                                                            catalog.currency,
                                                                          ),
                                                                        );
                                                                      },
                                                                ),
                                                          const SizedBox(
                                                            height:
                                                                AppSpacing.xl,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  SizedBox(
                                                    height: context
                                                        .cartFloatingBarPadding,
                                                  ), // Dynamic padding for the floating cart
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFiltersEmptyState(Color primaryColor) {
    final currentLang = context.read<LanguageCubit>().state.languageCode;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.no_food_outlined,
              color: primaryColor.withValues(alpha: 0.5),
              size: 72,
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
                  ? 'Cuba selaraskan penapis diet anda untuk mencari produk.'
                  : 'Try adjusting your dietary filters to find products.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.grey600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 160,
              height: 44,
              child: OutlinedButton(
                onPressed: () => _pageCubit.clearDietaryTags(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
                child: Text(
                  currentLang == 'ms' ? 'Kosongkan Penapis' : 'Clear Filters',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Premium Empty State for Favourites category matching screenshot exactly
  Widget _buildFavouritesEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Big Red Heart
            Icon(Icons.favorite_rounded, color: AppColors.error, size: 64),
            const SizedBox(height: AppSpacing.lg),

            // Title: Favourites 0 / 6
            Text(
              context.l10n.favouritesCategory,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '0 / 6',
              style: TextStyle(
                color: primaryColor.withValues(alpha: 0.6),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Subtitle
            Text(
              context.l10n.favouritesEmptySub,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey600,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStoreSelector({
    required List<StoreModel> stores,
    required int selectedStoreId,
  }) async {
    // Push the beautiful fullscreen SelectOutletPage via GoRouter instead of raw Navigator
    final selected = await context.push<StoreModel>(
      AppRouter.selectOutlet,
      extra: {'stores': stores, 'selectedStoreId': selectedStoreId},
    );

    if (selected == null || selected.id == selectedStoreId || !mounted) {
      return;
    }

    final currentBrand = context.read<ThemeCubit>().state;
    final selectedBrand = selected.brandId == 1
        ? LoobBrand.tealive
        : LoobBrand.baskbear;

    if (selectedBrand != currentBrand) {
      _pageCubit.setChangingStoreAcrossBrands(true);
      context.read<ThemeCubit>().switchBrand(selectedBrand);
    }

    _pageCubit.selectStore(selected.id);
    _pageCubit.selectCategory(null);
    _pageCubit.setPendingStoreChange(selected.id);

    _loadMenu(storeId: selected.id);
  }

  Future<void> _showCartAvailabilityWarning(CartState cartState) async {
    if (!mounted) return;

    final affectedItems = cartState.items.where((item) {
      return !item.isAvailable || item.hasUnavailableOptions;
    }).toList();

    final details = affectedItems.take(4).map((item) {
      final unavailableOptions = item.unavailableOptionNames;
      if (!item.isAvailable) return item.product.name;
      if (unavailableOptions.isEmpty) return item.product.name;
      return '${item.product.name}: ${unavailableOptions.join(', ')}';
    }).toList();

    if (affectedItems.length > details.length) {
      details.add('+${affectedItems.length - details.length} more');
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.cartAvailabilityChangedTitle),
        content: Text(
          [
            context.l10n.cartAvailabilityChangedBody,
            if (details.isNotEmpty) '',
            ...details.map((detail) => '- $detail'),
          ].join('\n'),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push(AppRouter.cart);
            },
            child: Text(context.l10n.myCart),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomization(ProductModel product, String currency) async {
    final result = await context.push(
      AppRouter.productDetail,
      extra: {'product': product, 'currency': currency},
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      final resolvedProduct = result['product'] as ProductModel? ?? product;
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
      final selectedOptions = resolvedProduct.customizationGroups
          .expand((g) => g.options)
          .where((o) => allOptionIds.contains(o.id))
          .toList();

      final action = result['action'] as String? ?? 'add';

      if (action == 'buy_now') {
        final buyNowItem = CartItem(
          product: resolvedProduct,
          selectedOptions: selectedOptions,
          customizationOptionIds: allOptionIds,
          quantity: quantity,
        );
        AuthGuard.run(context, () {
          context.push(AppRouter.checkout, extra: {'buyNowItem': buyNowItem});
        });
      } else {
        AuthGuard.run(context, () {
          context.read<CartBloc>().add(
            CartItemAdded(
              product: resolvedProduct,
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
}
