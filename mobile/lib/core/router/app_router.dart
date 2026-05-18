import 'package:flutter/material.dart';
import '../../features/cart/presentation/bloc/cart_item.dart';
import '../../features/menu/data/models/catalog_model.dart';
import '../../features/menu/presentation/product_detail_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/cart/presentation/checkout_page.dart';
import '../../features/cart/presentation/order_status_page.dart';
import '../../features/home/presentation/barcode_page.dart';
import '../../features/vouchers/presentation/voucher_wallet_page.dart';

/// Named route constants and route generation.
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final ValueNotifier<String?> currentRouteNotifier =
      ValueNotifier<String?>(null);
  static final NavigatorObserver routeObserver = _RouteObserver();

  // ── Route names ─────────────────────────────────────────────────────────────
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

  /// Central route factory for [MaterialApp.onGenerateRoute].
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // Routes are handled by the shell's bottom navigation for top-level tabs.
    // This generator handles pushed sub-pages.
    switch (settings.name) {
      case barcode:
        return MaterialPageRoute(
          builder: (_) => const BarcodePage(),
          settings: settings,
        );

      case vouchers:
        return MaterialPageRoute(
          builder: (_) => const VoucherWalletPage(),
          settings: settings,
        );

      case cart:
        return MaterialPageRoute(
          builder: (_) => const CartPage(),
          settings: settings,
        );

      case productDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final product = args?['product'] as ProductModel;
        final currency = args?['currency'] as String? ?? 'MYR';
        final cartItem = args?['cartItem'] as CartItem?;
        return MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => ProductDetailPage(
            product: product,
            currency: currency,
            initialQuantity: cartItem?.quantity ?? 1,
            initialCustomizationOptionIds:
                cartItem?.selectedCustomizationIds ?? const [],
            isEditingCartItem: cartItem != null,
          ),
          settings: settings,
        );

      case checkout:
        return MaterialPageRoute(
          builder: (_) => const CheckoutPage(),
          settings: settings,
        );

      case orderStatus:
        final args = settings.arguments as Map<String, dynamic>?;
        final trackingId = args?['trackingId'] as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => OrderStatusPage(trackingId: trackingId),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
          settings: settings,
        );
    }
  }
}

class _RouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppRouter.currentRouteNotifier.value = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppRouter.currentRouteNotifier.value = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    AppRouter.currentRouteNotifier.value = newRoute?.settings.name;
  }
}
