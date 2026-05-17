/// Central registry of all API endpoint paths.
///
/// Matches the Postman collection and Go backend route registration exactly.
class ApiEndpoints {
  ApiEndpoints._();

  // ── Health ──────────────────────────────────────────────────────────────────
  static const String health = '/health';

  // ── App Config ──────────────────────────────────────────────────────────────
  static const String appConfig = '/api/v1/app/config';
  static const String appFeed = '/api/v1/app/feed';

  // ── Catalog ─────────────────────────────────────────────────────────────────
  static const String catalogCategories = '/api/v1/catalog/categories';
  static String catalogCategoryItems(int categoryId) =>
      '/api/v1/catalog/categories/$categoryId/items';
  static String catalogItem(int itemId) => '/api/v1/catalog/items/$itemId';
  static const String catalogBrands = '/api/v1/catalog/brands';
  static const String catalogStores = '/api/v1/catalog/stores';

  // ── Checkout / Orders ───────────────────────────────────────────────────────
  static const String orders = '/api/v1/orders';
  static const String ordersCheckout = '/api/v1/orders/checkout';
  static String orderStatus(String trackingId) =>
      '/api/v1/orders/$trackingId/status';

  // ── Campaigns ───────────────────────────────────────────────────────────────
  static const String campaignsHome = '/api/v1/campaigns/home';

  // ── Vouchers ────────────────────────────────────────────────────────────────
  static const String vouchersWallet = '/api/v1/vouchers/wallet';

  // ── Users ───────────────────────────────────────────────────────────────────
  static const String userProfile = '/api/v1/users/profile';

  // ── Cart ────────────────────────────────────────────────────────────────────
  static const String cart = '/api/v1/cart';
  static const String cartItems = '/api/v1/cart/items';
  static String cartItem(int id) => '/api/v1/cart/items/$id';

  // ── Payments ────────────────────────────────────────────────────────────────
  static const String paymentProviders = '/api/v1/payments/providers';
  static const String paymentMethods = '/api/v1/payments/methods';
  static String paymentTransaction(String transactionId) =>
      '/api/v1/payments/$transactionId';
  static const String paymentMockCallback =
      '/api/v1/payments/mock-gateway/callback';
}
