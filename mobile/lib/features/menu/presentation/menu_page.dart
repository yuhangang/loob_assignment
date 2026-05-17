import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/brand.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../cart/presentation/cubit/cart_cubit.dart';
import '../data/models/catalog_model.dart';
import '../data/models/store_model.dart';
import 'menu_bloc.dart';
import 'widgets/product_card.dart';
import 'select_outlet_page.dart';

/// Category-grouped menu page for the active brand with vertical category sidebar navigation.
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late final MenuBloc _menuBloc;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _categoryKeys = {};

  int? _selectedStoreId;
  int? _selectedCategoryId;
  bool _isPickup = true;

  // Set to track user favourites dynamically in memory
  final Set<int> _favouritedIds = {};

  @override
  void initState() {
    super.initState();
    _menuBloc = MenuBloc();
    _loadMenu();
  }

  void _loadMenu({int? storeId}) {
    if (!mounted) return;
    final brand = context.read<ThemeCubit>().state;
    final brandId = brand.brandId ?? LoobBrand.tealive.brandId!;
    final lang = context.read<LanguageCubit>().state.languageCode;
    final resolvedStoreId = storeId ?? _selectedStoreId;

    _menuBloc.add(
      LoadMenu(
        countryCode: 'MY',
        language: lang,
        storeId: resolvedStoreId,
        brandId: brandId,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _menuBloc.close();
    super.dispose();
  }

  // Prepend dynamic Favourites Category to the Catalog
  List<CategoryModel> _buildEnhancedCategories(CatalogModel catalog) {
    // Build Favourites Category from backend catalog products
    final allProducts = catalog.categories.expand((c) => c.products).toList();

    final favouritedProducts = allProducts
        .where((p) => _favouritedIds.contains(p.id))
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTealive = theme.colorScheme.primary.toARGB32() == 0xFF4C1D40;
    final isDiscover = theme.colorScheme.primary.toARGB32() == 0xFFB2C9AB;

    // Core brand purple color
    final primaryColor = isTealive
        ? const Color(0xFF4C1D40)
        : (isDiscover ? const Color(0xFF2E4A1F) : theme.colorScheme.primary);

    return MultiBlocListener(
      listeners: [
        BlocListener<ThemeCubit, LoobBrand>(
          listener: (context, brand) {
            _selectedStoreId = null;
            _selectedCategoryId = null;
            _loadMenu(storeId: null);
          },
        ),
        BlocListener<LanguageCubit, Locale>(
          listener: (context, locale) => _loadMenu(),
        ),
        BlocListener<MenuBloc, MenuState>(
          bloc: _menuBloc,
          listener: (context, state) {
            if (state is MenuLoaded) {
              context.read<CartCubit>().setStore(state.selectedStore);
            }
          },
        ),
      ],
      child: SafeArea(
        child: BlocBuilder<MenuBloc, MenuState>(
          bloc: _menuBloc,
          builder: (context, state) {
            if (state is MenuLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is MenuError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              );
            }
            if (state is MenuLoaded) {
              final catalog = state.catalog;
              _selectedStoreId = state.selectedStore.id;

              // Build dynamic categories (Favourites + LTO + Backend)
              final enhancedCategories = _buildEnhancedCategories(catalog);

              // Default to the first available category if none is selected or if the selected one is no longer available
              if (_selectedCategoryId == null ||
                  !enhancedCategories.any((c) => c.id == _selectedCategoryId)) {
                _selectedCategoryId = enhancedCategories.isNotEmpty
                    ? enhancedCategories.first.id
                    : null;
              }

              for (final category in enhancedCategories) {
                _categoryKeys.putIfAbsent(category.id, GlobalKey.new);
              }

              // Selected Category
              final activeCategory = enhancedCategories.firstWhere(
                (c) => c.id == _selectedCategoryId,
                orElse: () => enhancedCategories.first,
              );

              return Column(
                children: [
                  // Full-width Header with fulfillment tabs and outlet bar
                  _MenuHeader(
                    brandName: catalog.brand,
                    isPickup: _isPickup,
                    selectedStore: state.selectedStore,
                    primaryColor: primaryColor,
                    onFulfillmentChanged: (isPickup) {
                      setState(() => _isPickup = isPickup);
                    },
                    onChangeOutlet: () => _showStoreSelector(
                      stores: state.stores,
                      selectedStoreId: state.selectedStore.id,
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFF3E7DC)),

                  // Main Split Section (Left Sidebar / Right Product Area)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Sidebar Navigation (Width 85)
                        Container(
                          width: 85,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              right: BorderSide(
                                color: Color(0xFFF3E7DC),
                                width: 1,
                              ),
                            ),
                          ),
                          child: ListView.builder(
                            itemCount: enhancedCategories.length,
                            itemBuilder: (context, index) {
                              final category = enhancedCategories[index];
                              final isSelected =
                                  category.id == _selectedCategoryId;

                              return _SidebarCategoryTab(
                                category: category,
                                isSelected: isSelected,
                                primaryColor: primaryColor,
                                favouritedCount: _favouritedIds.length,
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                  });
                                  // Wait for frame to rebuild to active category layout
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_scrollController.hasClients) {
                                      _scrollController.jumpTo(0);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),

                        // Right Product Content Grid
                        Expanded(
                          child: Container(
                            color: const Color(
                              0xFFFAF9F6,
                            ), // Cozy light-beige background matching screenshots
                            child:
                                activeCategory.id == -99 &&
                                    activeCategory.products.isEmpty
                                ? _buildFavouritesEmptyState(primaryColor)
                                : ListView(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.lg,
                                    ),
                                    children: [
                                      // Category Title Header
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              activeCategory.name,
                                              style: theme
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 22,
                                                  ),
                                            ),
                                          ),
                                          if (activeCategory.id == -99)
                                            Text(
                                              '${_favouritedIds.length} / 6',
                                              style: TextStyle(
                                                color: primaryColor.withValues(
                                                  alpha: 0.6,
                                                ),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),

                                      // Product Grid (2 columns)
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              childAspectRatio: 0.65,
                                              crossAxisSpacing: AppSpacing.md,
                                              mainAxisSpacing: AppSpacing.md,
                                            ),
                                        itemCount:
                                            activeCategory.products.length,
                                        itemBuilder: (context, index) {
                                          final product =
                                              activeCategory.products[index];
                                          final isFavourited = _favouritedIds
                                              .contains(product.id);

                                          return ProductCard(
                                            product: product,
                                            currency: catalog.currency,
                                            isFavourited: isFavourited,
                                            onFavouriteToggled: () {
                                              setState(() {
                                                if (isFavourited) {
                                                  _favouritedIds.remove(
                                                    product.id,
                                                  );
                                                } else {
                                                  _favouritedIds.add(
                                                    product.id,
                                                  );
                                                }
                                              });
                                            },
                                            onTap: () => _showCustomization(
                                              product,
                                              catalog.currency,
                                            ),
                                            onCartPressed: () =>
                                                _handleCartShortcut(
                                                  product,
                                                  catalog.currency,
                                                ),
                                          );
                                        },
                                      ),
                                      const SizedBox(
                                        height: 80,
                                      ), // Padding for the floating cart
                                    ],
                                  ),
                          ),
                        ),
                      ],
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
            Icon(Icons.favorite_rounded, color: Colors.red.shade400, size: 64),
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
                color: Colors.grey.shade600,
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
    // Push the beautiful fullscreen SelectOutletPage instead of bottom sheet
    final selected = await Navigator.push<StoreModel>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelectOutletPage(stores: stores, selectedStoreId: selectedStoreId),
      ),
    );

    if (selected == null || selected.id == selectedStoreId || !mounted) {
      return;
    }
    setState(() {
      _selectedStoreId = selected.id;
      _selectedCategoryId = null; // Reset category selection
    });
    _loadMenu(storeId: selected.id);
  }

  Future<void> _showCustomization(ProductModel product, String currency) async {
    final result = await Navigator.pushNamed(
      context,
      AppRouter.productDetail,
      arguments: {'product': product, 'currency': currency},
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

      context.read<CartCubit>().addToCart(
        product: product,
        selectedOptions: selectedOptions,
        customizationOptionIds: allOptionIds,
        quantity: quantity,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.addedToCartToast(quantity, product.name)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleCartShortcut(ProductModel product, String currency) {
    if (product.customizationGroups.isNotEmpty) {
      _showCustomization(product, currency);
      return;
    }

    context.read<CartCubit>().addToCart(
      product: product,
      selectedOptions: const [],
      customizationOptionIds: const [],
      quantity: 1,
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.addedToCartToast(1, product.name)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Left Sidebar Individual Category Tab
class _SidebarCategoryTab extends StatelessWidget {
  const _SidebarCategoryTab({
    required this.category,
    required this.isSelected,
    required this.primaryColor,
    required this.favouritedCount,
    required this.onTap,
  });

  final CategoryModel category;
  final bool isSelected;
  final Color primaryColor;
  final int favouritedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Generate beautiful custom category icons
    Widget iconWidget;
    final normalized = category.name.toLowerCase();

    if (category.id == -99) {
      // Favourites tab
      iconWidget = Icon(
        Icons.favorite_rounded,
        color: favouritedCount > 0 ? Colors.red : Colors.grey.shade400,
        size: 24,
      );
    } else {
      // Retrieve the icon URL from the backend model, with a robust client-side mapping fallback if not seeded yet
      String iconUrl = category.iconUrl;
      if (iconUrl.isEmpty) {
        if (category.id == 10 ||
            normalized.contains('boba') ||
            normalized.contains('bang bang')) {
          iconUrl = '/cdn/categories/boba.svg';
        } else if (category.id == 11 || normalized.contains('fruit tea')) {
          iconUrl = '/cdn/categories/fruit_tea.svg';
        } else if (category.id == 12 || normalized.contains('toastie')) {
          iconUrl = '/cdn/categories/toasties.svg';
        } else if (category.id == 13 || normalized.contains('coffee')) {
          iconUrl = '/cdn/categories/coffee.svg';
        } else if (category.id == 14 || normalized.contains('matcha')) {
          iconUrl = '/cdn/categories/matcha.svg';
        } else if (category.id == 15 || normalized.contains('cocoa')) {
          iconUrl = '/cdn/categories/cocoa.svg';
        } else if (category.id == 16 || normalized.contains('frappe')) {
          iconUrl = '/cdn/categories/frappe.svg';
        } else if (category.id == 17 || normalized.contains('mains')) {
          iconUrl = '/cdn/categories/mains.svg';
        } else if (category.id == 20 || normalized.contains('thai tea')) {
          iconUrl = '/cdn/categories/thai_tea.svg';
        } else if (category.id == 21 || normalized.contains('sparkling')) {
          iconUrl = '/cdn/categories/sparkling_tea.svg';
        } else if (category.id == 25 || normalized.contains('smoothie')) {
          iconUrl = '/cdn/categories/smoothie.svg';
        } else if (category.id == 26 || normalized.contains('croffle')) {
          iconUrl = '/cdn/categories/croffle.svg';
        }
      }

      if (iconUrl.isNotEmpty) {
        iconWidget = SvgPicture.network(
          'http://localhost:8080$iconUrl',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            isSelected ? primaryColor : Colors.grey.shade500,
            BlendMode.srcIn,
          ),
          placeholderBuilder: (BuildContext context) => const SizedBox(
            width: 24,
            height: 24,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      } else {
        iconWidget = Icon(
          Icons.local_drink_rounded,
          color: isSelected ? primaryColor : Colors.grey.shade500,
          size: 24,
        );
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFEF7EE)
              : Colors.transparent, // Highlight color
          border: isSelected
              ? Border(left: BorderSide(color: primaryColor, width: 4))
              : null,
        ),
        child: Column(
          children: [
            // Circular container for icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey.shade50,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        const BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(height: 6),

            // Category Name Label
            Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? primaryColor : Colors.grey.shade500,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom top Menu Header matching screenshots exactly
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.brandName,
    required this.isPickup,
    required this.selectedStore,
    required this.primaryColor,
    required this.onFulfillmentChanged,
    required this.onChangeOutlet,
  });

  final String brandName;
  final bool isPickup;
  final StoreModel selectedStore;
  final Color primaryColor;
  final ValueChanged<bool> onFulfillmentChanged;
  final VoidCallback onChangeOutlet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Sliding fulfillment selector + Business hour text
          Row(
            children: [
              // Custom Sliding Fulfillment Capsule
              Container(
                height: 38,
                width: 170,
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEF5), // Light lavender background
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Delivery Tab
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onFulfillmentChanged(false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !isPickup
                                ? primaryColor.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            context.l10n.delivery,
                            style: TextStyle(
                              color: !isPickup
                                  ? primaryColor
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Pickup Tab
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onFulfillmentChanged(true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isPickup ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            context.l10n.pickup,
                            style: TextStyle(
                              color: isPickup
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              // Business Hour Details
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.door_sliding_outlined,
                      color: primaryColor.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.businessHourHeader,
                            style: const TextStyle(
                              color: Color(
                                0xFFE28BB9,
                              ), // Soft pink-purple color matching screenshot
                              fontWeight: FontWeight.w800,
                              fontSize: 8,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '10:30AM - 09:00PM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 2: Outlet selector
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: onChangeOutlet,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.storefront_rounded, color: primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedStore.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(Icons.edit_outlined, color: primaryColor, size: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Container(
                      width: 1.5,
                      height: 16,
                      color: Colors.grey.shade300,
                    ),
                  ),

                  Icon(
                    Icons.access_time_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ASAP',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, color: primaryColor, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Row 3: Outlined Search Bar with Boba cup prefix
          TextField(
            readOnly: true,
            onTap: () {
              // Action if search was tapped
            },
            decoration: InputDecoration(
              hintText: context.l10n.searchBobaPlaceholder,
              hintStyle: TextStyle(
                color: primaryColor.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Icon(
                  Icons.local_drink_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              suffixIcon: Icon(
                Icons.search_rounded,
                color: primaryColor,
                size: 24,
              ),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
