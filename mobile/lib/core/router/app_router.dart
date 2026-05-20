import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/bloc/cart_item.dart';
import '../../features/menu/data/models/catalog_model.dart';
import '../../features/menu/data/models/store_model.dart';
import '../../features/menu/presentation/product_detail_page.dart';
import '../../features/menu/presentation/select_outlet_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/cart/presentation/checkout_page.dart';
import '../../features/cart/presentation/order_status_page.dart';
import '../../features/home/presentation/barcode_page.dart';
import '../../features/vouchers/presentation/voucher_wallet_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/menu/presentation/menu_page.dart';
import '../../features/menu/presentation/menu_search_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../shell.dart';

/// Named route constants and route generation using GoRouter.
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final ValueNotifier<String?> currentRouteNotifier =
      ValueNotifier<String?>(null);
  static final ValueNotifier<bool> isDialogOpenNotifier =
      ValueNotifier<bool>(false);
  static final NavigatorObserver routeObserver = _RouteObserver();

  // A refresh signal ValueNotifier to communicate between AppShell tab double-tap and OrdersPage.
  static final ValueNotifier<int> ordersRefreshSignal = ValueNotifier<int>(0);

  // ── Route paths/names ────────────────────────────────────────────────────────
  static const String home = '/';
  static const String menu = '/menu';
  static const String productDetail = '/menu/item';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderStatus = '/order';
  static const String vouchers = '/vouchers';
  static const String campaigns = '/campaigns';
  static const String settings = '/settings';
  static const String barcode = '/barcode';
  static const String selectOutlet = '/menu/select-outlet';
  static const String menuSearch = '/menu/search';

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: home,
    observers: [routeObserver],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: menu,
                builder: (context, state) => const MenuPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders', // Unique path for orders branch tab
                builder: (context, state) =>
                    OrdersPage(refreshSignal: ordersRefreshSignal),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings_tab', // Unique path for settings branch tab
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      // Flat root routes pushed over the bottom shell
      GoRoute(
        path: barcode,
        name: barcode,
        builder: (context, state) => const BarcodePage(),
      ),
      GoRoute(
        path: vouchers,
        name: vouchers,
        builder: (context, state) => const VoucherWalletPage(),
      ),
      GoRoute(
        path: cart,
        name: cart,
        builder: (context, state) => const CartPage(),
      ),
      GoRoute(
        path: productDetail,
        name: productDetail,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final product = extra?['product'] as ProductModel;
          final currency = extra?['currency'] as String? ?? 'MYR';
          final cartItem = extra?['cartItem'] as CartItem?;
          return ProductDetailPage(
            product: product,
            currency: currency,
            initialQuantity: cartItem?.quantity ?? 1,
            initialCustomizationOptionIds:
                cartItem?.selectedCustomizationIds ?? const [],
            isEditingCartItem: cartItem != null,
          );
        },
      ),
      GoRoute(
        path: checkout,
        name: checkout,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final buyNowItem = extra?['buyNowItem'] as CartItem?;
          return CheckoutPage(buyNowItem: buyNowItem);
        },
      ),
      GoRoute(
        path: orderStatus,
        name: orderStatus,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final trackingId =
              (extra?['trackingId'] as String?) ??
              state.uri.queryParameters['trackingId'] ??
              '';
          return OrderStatusPage(trackingId: trackingId);
        },
      ),
      GoRoute(
        path: selectOutlet,
        name: selectOutlet,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final stores = extra?['stores'] as List<StoreModel>? ?? const [];
          final selectedStoreId = extra?['selectedStoreId'] as int? ?? 0;
          return SelectOutletPage(
            stores: stores,
            selectedStoreId: selectedStoreId,
          );
        },
      ),
      GoRoute(
        path: menuSearch,
        name: menuSearch,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final catalog = extra['catalog'] as CatalogModel;
          final currency = extra['currency'] as String;
          final favouritedIds = extra['favouritedIds'] as Set<int>? ?? const {};
          final onFavouriteToggled = extra['onFavouriteToggled'] as ValueChanged<int>;
          final initialSelectedDietaryTags =
              extra['initialSelectedDietaryTags'] as Set<String>? ?? const {};
          return MenuSearchPage(
            catalog: catalog,
            currency: currency,
            initialFavouritedIds: favouritedIds,
            onFavouriteToggled: onFavouriteToggled,
            initialSelectedDietaryTags: initialSelectedDietaryTags,
          );
        },
      ),
    ],
  );
}

class _RouteObserver extends NavigatorObserver {
  static int _activeDialogCount = 0;

  void _updateRoute(String? name) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppRouter.currentRouteNotifier.value = name;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateRoute(route.settings.name);
    if (route is PopupRoute || route.runtimeType.toString().contains('DialogRoute')) {
      _activeDialogCount++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.isDialogOpenNotifier.value = _activeDialogCount > 0;
      });
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateRoute(previousRoute?.settings.name);
    if (route is PopupRoute || route.runtimeType.toString().contains('DialogRoute')) {
      _activeDialogCount = (_activeDialogCount - 1).clamp(0, 999);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.isDialogOpenNotifier.value = _activeDialogCount > 0;
      });
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute || route.runtimeType.toString().contains('DialogRoute')) {
      _activeDialogCount = (_activeDialogCount - 1).clamp(0, 999);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.isDialogOpenNotifier.value = _activeDialogCount > 0;
      });
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _updateRoute(newRoute?.settings.name);
    if (oldRoute is PopupRoute || oldRoute?.runtimeType.toString().contains('DialogRoute') == true) {
      _activeDialogCount = (_activeDialogCount - 1).clamp(0, 999);
    }
    if (newRoute is PopupRoute || newRoute?.runtimeType.toString().contains('DialogRoute') == true) {
      _activeDialogCount++;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppRouter.isDialogOpenNotifier.value = _activeDialogCount > 0;
    });
  }
}
