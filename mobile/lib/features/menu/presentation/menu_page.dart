import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_guard.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/brand.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_event.dart';
import '../../cart/presentation/bloc/cart_state.dart';
import '../../cart/presentation/bloc/cart_item.dart';
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
  final GlobalKey _listViewKey = GlobalKey();
  final Map<int, GlobalKey> _categoryKeys = {};

  int? _selectedStoreId;
  int? _selectedCategoryId;
  int? _pendingStoreChangeWarningStoreId;
  bool _isPickup = true;
  bool _isProgrammaticScroll = false;

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
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isProgrammaticScroll) return false;

    final context = this.context;
    if (!context.mounted) return false;

    final state = _menuBloc.state;
    if (state is! MenuLoaded) return false;
    final enhancedCategories = _buildEnhancedCategories(state.catalog);

    final listViewBox = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
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

    if (activeId != null && activeId != _selectedCategoryId) {
      setState(() {
        _selectedCategoryId = activeId;
      });
    }

    return false;
  }

  void _onCategoryTabTap(int categoryId) {
    if (_selectedCategoryId == categoryId) return;

    setState(() {
      _selectedCategoryId = categoryId;
    });

    final key = _categoryKeys[categoryId];
    final context = key?.currentContext;
    if (context == null) return;

    _isProgrammaticScroll = true;

    Scrollable.ensureVisible(
      context,
      alignment: 0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isProgrammaticScroll = false;
      });
    });
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
        BlocListener<CartBloc, CartState>(
          listenWhen: (previous, current) =>
              previous.countryCode != current.countryCode,
          listener: (context, cartState) {
            _selectedStoreId = null;
            _selectedCategoryId = null;
            _loadMenu(storeId: null);
          },
        ),
        BlocListener<MenuBloc, MenuState>(
          bloc: _menuBloc,
          listener: (context, state) {
            if (state is MenuLoaded) {
              context.read<CartBloc>().add(CartSetStore(state.selectedStore));
            }
          },
        ),
        BlocListener<CartBloc, CartState>(
          listener: (context, state) {
            final pendingStoreId = _pendingStoreChangeWarningStoreId;
            if (pendingStoreId == null ||
                state.loadStatus != CartLoadStatus.loaded ||
                state.storeId != pendingStoreId) {
              return;
            }

            _pendingStoreChangeWarningStoreId = null;
            if (state.items.isEmpty ||
                (!state.hasUnavailableItems && !state.hasUnavailableOptions)) {
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

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Sidebar Navigation (Width 85) - Completely static & fixed!
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
                            delegate: _MenuHeaderDelegate(
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
                          ),
                        ];
                      },
                      body: Container(
                        color: const Color(0xFFFAF9F6),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.depth == 0) {
                              _onScrollNotification(notification);
                            }
                            return false;
                          },
                          child: SingleChildScrollView(
                            key: _listViewKey,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.lg,
                            ),
                            child: Column(
                              children: [
                                for (final category in enhancedCategories) ...[
                                  Container(
                                    key: _categoryKeys[category.id],
                                    padding: const EdgeInsets.only(top: AppSpacing.md),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Category Title Header
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                category.name,
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
                                            if (category.id == -99)
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

                                        // Product Grid (2 columns) or empty state for Favourites
                                        category.id == -99 && category.products.isEmpty
                                            ? _buildFavouritesEmptyState(primaryColor)
                                            : GridView.builder(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  childAspectRatio: 0.65,
                                                  crossAxisSpacing: AppSpacing.md,
                                                  mainAxisSpacing: AppSpacing.md,
                                                ),
                                                itemCount: category.products.length,
                                                itemBuilder: (context, index) {
                                                  final product = category.products[index];
                                                  final isFavourited = _favouritedIds.contains(product.id);

                                                  return ProductCard(
                                                    product: product,
                                                    currency: catalog.currency,
                                                    isFavourited: isFavourited,
                                                    onFavouriteToggled: () {
                                                      setState(() {
                                                        if (isFavourited) {
                                                          _favouritedIds.remove(product.id);
                                                        } else {
                                                          _favouritedIds.add(product.id);
                                                        }
                                                      });
                                                    },
                                                    onTap: () => _showCustomization(product, catalog.currency),
                                                    onCartPressed: () => _handleCartShortcut(product, catalog.currency),
                                                  );
                                                },
                                              ),
                                        const SizedBox(height: AppSpacing.xl),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 120), // Padding for the floating cart
                              ],
                            ),
                          ),
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
      _pendingStoreChangeWarningStoreId = selected.id;
    });
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
          context.push(
            AppRouter.checkout,
            extra: {'buyNowItem': buyNowItem},
          );
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
              content: Text(context.l10n.addedToCartToast(quantity, product.name)),
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
        final resolvedIconUrl = iconUrl.startsWith('http') ? iconUrl : '${sl<AppConfig>().baseUrl}$iconUrl';
        iconWidget = SvgPicture.network(
          resolvedIconUrl,
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
          border: Border(
            left: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 4,
            ),
          ),
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

/// Custom delegate for collapsible premium sticky Menu Header
class _MenuHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MenuHeaderDelegate({
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
  double get minExtent => 82.0;

  @override
  double get maxExtent => 195.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final limit = maxExtent - minExtent;
    final percent = limit > 0 ? (shrinkOffset / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Expanded Header Content
          Opacity(
            opacity: (1.0 - percent * 1.5).clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: _MenuHeader(
                  brandName: brandName,
                  isPickup: isPickup,
                  selectedStore: selectedStore,
                  primaryColor: primaryColor,
                  onFulfillmentChanged: onFulfillmentChanged,
                  onChangeOutlet: onChangeOutlet,
                ),
              ),
            ),
          ),

          // Collapsed Sticky Header Content
          Opacity(
            opacity: (percent - 0.4).clamp(0.0, 1.0) * (1.0 / 0.6),
            child: Align(
              alignment: Alignment.center,
              child: _CollapsedMenuHeader(
                selectedStore: selectedStore,
                primaryColor: primaryColor,
                onChangeOutlet: onChangeOutlet,
              ),
            ),
          ),

          // Top/Bottom border/divider
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(height: 1, color: Color(0xFFF3E7DC)),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MenuHeaderDelegate oldDelegate) {
    return oldDelegate.brandName != brandName ||
        oldDelegate.isPickup != isPickup ||
        oldDelegate.selectedStore != selectedStore ||
        oldDelegate.primaryColor != primaryColor;
  }
}

/// Compact collapsed header for sticky behavior when scrolling products
class _CollapsedMenuHeader extends StatelessWidget {
  const _CollapsedMenuHeader({
    required this.selectedStore,
    required this.primaryColor,
    required this.onChangeOutlet,
  });

  final StoreModel selectedStore;
  final Color primaryColor;
  final VoidCallback onChangeOutlet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_rounded, color: primaryColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              onTap: onChangeOutlet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
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
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, color: primaryColor, size: 14),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: primaryColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'ASAP',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // Action for search if needed
            },
            icon: Icon(Icons.search_rounded, color: primaryColor, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
