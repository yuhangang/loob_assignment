import 'package:flutter/material.dart';

/// Access localized copywriting for Loob mobile app in both English and Malay.
///
/// With potential for more languages and OTA updates from cdn
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'home': 'Home',
      'menu': 'Menu',
      'cart': 'Cart',
      'vouchers': 'Vouchers',
      'profile': 'Profile',
      'orders': 'Orders',
      'settings': 'Settings',
      'good_morning': 'Good Morning ☀️',
      'good_afternoon': 'Good Afternoon 🍵',
      'good_evening': 'Good Evening 🌙',
      'subtitle_discover': 'Discover Tealive & Baskbear',
      'subtitle_tealive': 'Craving some boba today?',
      'subtitle_baskbear': 'Time for a coffee break!',
      'for_you': 'For You',
      'my_cart': 'My Cart',
      'cart_empty': 'Your cart is empty',
      'cart_empty_sub': 'Browse the menu and add your favorites',
      'browse_menu': 'Browse Menu',
      'my_vouchers': 'My Vouchers',
      'campaigns_title': 'Campaigns & Rewards',
      'banners': 'Banners',
      'activities': 'Activities',
      'preferences': 'Preferences',
      'language': 'Language',
      'country': 'Country',
      'support': 'Support',
      'help_centre': 'Help Centre',
      'about': 'About',
      'sign_out': 'Sign Out',
      'required': 'Required',
      'add_to_cart': 'Add to Cart',
      'update': 'Update',
      'add_to_cart_btn': 'Add to Cart — {}',
      'added_to_cart_toast': 'Added {} × {} to cart',
      'select_language': 'Select Language',
      'banner_tealive_title': 'Tealive Flash Sale!',
      'banner_tealive_subtitle': '50% off all signature drinks today',
      'banner_baskbear_title': 'Baskbear Morning Combo',
      'banner_baskbear_subtitle': 'Toast + Coffee from RM 6.90',
      'status_available': 'Available',
      'status_used': 'Used',
      'status_expired': 'Expired',
      'balance': 'Balance',
      'top_up_initiated': 'Top-Up Initiated! Open Gateway...',
      'tpoints': 'TPoints',
      'barcode_opened':
          'Barcode display opened! Present this at checkout counter.',
      'delivery': 'Delivery',
      'pickup': 'Pickup',
      'delivery_off': 'Delivery (Off)',
      'pickup_off': 'Pickup (Off)',
      'order_again': 'Order Again',
      'reorder': 'Reorder',
      'close': 'Close',
      'claim': 'Claim',
      'claim_promo': 'Claim Promo',
      'delivery_offline_warning':
          'Delivery is temporarily offline for maintenance!',
      'pickup_offline_warning':
          'Pickup is temporarily offline for maintenance!',
      'event_claimed_toast':
          'Congratulations! You have successfully registered for the Boba Fiesta event.',
      'added_to_cart_reorder_toast':
          '"{}" added to your cart for quick re-order!',
      'select_outlet_title': 'SELECT YOUR OUTLET',
      'all_brands': 'All Brands',
      'search_outlet_placeholder': 'Search outlet or area',
      'no_outlets_match': 'No outlets match your search.',
      'open_daily': 'Open daily',
      'last_order_before': 'Last order before',
      'order_now': 'Order Now',
      'store_closed': 'Closed',
      'store_temporarily_closed': 'Temporarily closed',
      'lto_rich_matcha': 'LTO - Rich Matcha',
      'lto_grass_jelly': 'LTO Grass Jelly',
      'favourites': 'For You',
      'favourites_empty_sub': 'You haven\'t selected any favourites yet',
      'business_hour_header': 'BUSINESS HOUR',
      'search_boba_placeholder': 'Looking for something refreshing?',
      'new_badge': 'NEW',
      'unavailable': 'Unavailable',
      'product_unavailable': 'This item is currently unavailable',
      'option_unavailable_tag': '{} (Unavailable)',
      'some_options_unavailable': 'Some options are unavailable',
      'cart_availability_changed_title': 'Review your cart',
      'cart_availability_changed_body':
          'Some cart items or add-ons are not available at this outlet.',
      'checkout_title': 'Checkout',
      'payment_title': 'Payment',
      'unable_load_payment_methods':
          'Unable to load payment methods. Please try again.',
      'select_payment_method_first': 'Select a payment method first.',
      'select_outlet_first': 'Select an outlet before checkout.',
      'selected_store_closed_checkout':
          'The selected outlet is closed and cannot accept checkout.',
      'checkout_failed_msg':
          'Checkout failed. Review your cart and payment method.',
      'order_summary': 'Order summary',
      'voucher_label': 'Voucher',
      'tax_and_total_confirm': 'Final tax and total are confirmed by checkout.',
      'estimated_payable': 'Estimated payable',
      'subtotal_label': 'Subtotal',
      'fulfillment_label': 'Fulfillment',
      'dine_in_option': 'Dine in',
      'takeaway_option': 'Takeaway',
      'delivery_option': 'Delivery',
      'optional_voucher_code': 'Optional voucher code',
      'browse_btn': 'Browse',
      'voucher_will_be_validated': 'Voucher "{}" will be validated at checkout',
      'voucher_applied': 'Voucher "{}" applied',
      'no_payment_methods': 'No payment methods are available for this order.',
      'placing_order': 'Placing order...',
      'place_order': 'Place order',
      'total_amount': 'Total Amount',
      'mock_payment_approved': 'Mock payment approved',
      'payment_pending': 'Payment pending',
      'payment_details': 'Payment details',
      'tax_label': 'Tax',
      'discount_label': 'Discount',
      'total_label': 'Total',
      'waived_label': 'Waived',
      'method_label': 'Method',
      'provider_label': 'Provider',
      'status_label': 'Status',
      'confirm_mock_payment': 'Confirm mock payment',
      'view_order_status': 'View order status',
      'select_voucher_title': 'Select Voucher',
      'unable_load_vouchers': 'Unable to load your vouchers',
      'no_vouchers_available': 'No vouchers available',
      'no_active_vouchers_sub':
          'You don\'t have any active vouchers in your wallet right now.',
      'spend_more_to_use': 'Spend {} more',
      'choices_btn': 'Choices',
      'configured_item': 'Configured item',
      'remove_tooltip': 'Remove',
      'no_editable_options_sub':
          'This item was loaded without editable option details. You can still adjust quantity here.',
      'choose_one': 'Choose 1',
      'choose_up_to': 'Choose up to {}',
      'quantity_label': 'Quantity',
      'update_item_btn': 'Update item {}',
      'adjust_choices': 'Adjust choices',
      'clear_cart_title': 'Clear Cart?',
      'clear_cart_content':
          'Are you sure you want to remove all items from your cart?',
      'remove_item_title': 'Remove Item?',
      'remove_item_content': 'Are you sure you want to remove this item?',
      'cancel': 'Cancel',
      'clear_all': 'Clear All',
      'order_id_copied': 'Order ID copied',
      'voucher_code_copied': 'Voucher code copied',
      'order_status_title': 'Order Status',
      'show_to_staff': 'SHOW TO STAFF FOR COLLECTION',
      'collection_pin': 'COLLECTION PIN',
      'your_collection_code': 'YOUR COLLECTION CODE',
      'order_created': 'Order created',
      'pending': 'Pending',
      'created': 'Created',
      'updated': 'Updated',
      'unable_load_order_status': 'Unable to load order status.',
      'retry': 'Retry',
      'item_unavailable_remove': 'Remove',
      'each': 'each',
      'remove_unavailable_items': 'Remove Unavailable Items',
      'selected_outlet_closed': 'Selected Outlet Closed',
      'proceed_to_checkout': 'Proceed to Checkout',
      'welcome_guest': 'Welcome, Guest!',
      'guest_desc':
          'Log in to earn loyalty points, claim discount vouchers, and order online.',
      'login_signup': 'Login / Sign Up',
      'welcome_loob': 'Welcome to Loob',
      'login_sheet_desc':
          'Log in with your phone number to earn loyalty points, claim exclusive vouchers, and place checkout orders.',
      'enter_phone_hint': 'Enter phone number',
      'continue_btn': 'Continue',
      'verify_code_title': 'Verify Code',
      'otp_sent_to': 'We have sent a 6-digit OTP code to {}',
      'phone_required_err': 'Phone number is required',
      'otp_required_err': 'Verification code is required',
      'otp_incorrect_err': 'Incorrect code. Try "123456"',
      'demo_otp_helper': 'Demo Mock Verification Code is "123456"',
      'select_country_title': 'Select Country',
      'buy_now': 'Buy Now',
      'unpaid_order': 'UNPAID ORDER',
      'uncollected_order': 'UNCOLLECTED ORDER',
      'ready_for_collection': 'Ready for Collection',
      'awaiting_payment': 'Awaiting Payment',
      'preparing_order': 'Preparing your order...',
      'pay_now': 'Pay Now',
      'track': 'Track',
      'collect_btn': 'Collect',
      'collecting_btn': 'Collecting...',
      'retry_payment_btn': 'Retry Payment',
      'processing_payment_btn': 'Processing Payment...',
      'active_order_warning_title': 'Active Order Detected',
      'active_order_warning_content': 'You already have an active order. Are you sure you want to place another separate order?',
    },
    'ms': {
      'home': 'Utama',
      'menu': 'Menu',
      'cart': 'Troli',
      'vouchers': 'Baucher',
      'profile': 'Profil',
      'orders': 'Pesanan',
      'settings': 'Tetapan',
      'good_morning': 'Selamat Pagi ☀️',
      'good_afternoon': 'Selamat Tengah Hari 🍵',
      'good_evening': 'Selamat Petang 🌙',
      'subtitle_discover': 'Terokai Tealive & Baskbear',
      'subtitle_tealive': 'Teringin boba hari ini?',
      'subtitle_baskbear': 'Masa untuk rehat kopi!',
      'for_you': 'Untuk Anda',
      'my_cart': 'Troli Saya',
      'cart_empty': 'Troli anda kosong',
      'cart_empty_sub': 'Teroka menu dan tambah kegemaran anda',
      'browse_menu': 'Teroka Menu',
      'my_vouchers': 'Baucher Saya',
      'campaigns_title': 'Kempen & Ganjaran',
      'banners': 'Sepanduk',
      'activities': 'Aktiviti',
      'preferences': 'Pilihan',
      'language': 'Bahasa',
      'country': 'Negara',
      'support': 'Sokongan',
      'help_centre': 'Pusat Bantuan',
      'about': 'Tentang',
      'sign_out': 'Log Keluar',
      'required': 'Wajib',
      'add_to_cart': 'Tambah ke Troli',
      'update': 'Kemaskini',
      'add_to_cart_btn': 'Tambah ke Troli — {}',
      'added_to_cart_toast': 'Menambah {} × {} ke troli',
      'select_language': 'Pilih Bahasa',
      'banner_tealive_title': 'Jualan Kilat Tealive!',
      'banner_tealive_subtitle':
          'Diskaun 50% untuk semua minuman utama hari ini',
      'banner_baskbear_title': 'Kombo Pagi Baskbear',
      'banner_baskbear_subtitle': 'Roti Bakar + Kopi daripada RM 6.90',
      'status_available': 'Boleh Guna',
      'status_used': 'Telah Guna',
      'status_expired': 'Tamat Tempoh',
      'balance': 'Baki',
      'top_up_initiated': 'Tambah Nilai Dimulakan! Membuka Pintu Laluan...',
      'tpoints': 'TPoints',
      'barcode_opened':
          'Paparan kod bar dibuka! Tunjukkan ini di kaunter bayaran.',
      'delivery': 'Penghantaran',
      'pickup': 'Ambil Sendiri',
      'delivery_off': 'Penghantaran (Tutup)',
      'pickup_off': 'Ambil Sendiri (Tutup)',
      'order_again': 'Pesan Lagi',
      'reorder': 'Pesan Semula',
      'close': 'Tutup',
      'claim': 'Tuntut',
      'claim_promo': 'Tuntut Promo',
      'delivery_offline_warning':
          'Penghantaran ditutup sementara untuk penyelenggaraan!',
      'pickup_offline_warning':
          'Ambil sendiri ditutup sementara untuk penyelenggaraan!',
      'event_claimed_toast':
          'Tahniah! Anda telah berjaya mendaftar untuk acara Boba Fiesta.',
      'added_to_cart_reorder_toast':
          '"{}" ditambahkan ke troli anda untuk pesanan pantas!',
      'select_outlet_title': 'PILIH CAWANGAN ANDA',
      'all_brands': 'Semua Jenama',
      'search_outlet_placeholder': 'Cari cawangan atau kawasan',
      'no_outlets_match': 'Tiada cawangan yang sepadan dengan carian anda.',
      'open_daily': 'Buka setiap hari',
      'last_order_before': 'Pesanan terakhir sebelum',
      'order_now': 'Pesan Sekarang',
      'store_closed': 'Tutup',
      'store_temporarily_closed': 'Ditutup sementara',
      'lto_rich_matcha': 'LTO - Matcha Mewah',
      'lto_grass_jelly': 'LTO Cincau',
      'favourites': 'Untuk Anda',
      'favourites_empty_sub': 'Anda belum memilih mana-mana kegemaran lagi',
      'business_hour_header': 'WAKTU PERNIAGAAN',
      'search_boba_placeholder': 'Mencari sesuatu yang menyegarkan?',
      'new_badge': 'BARU',
      'unavailable': 'Tidak Tersedia',
      'product_unavailable': 'Item ini tidak tersedia buat masa ini',
      'option_unavailable_tag': '{} (Tidak Tersedia)',
      'some_options_unavailable': 'Beberapa pilihan tidak tersedia',
      'cart_availability_changed_title': 'Semak troli anda',
      'cart_availability_changed_body':
          'Beberapa item atau tambahan dalam troli tidak tersedia di cawangan ini.',
      'checkout_title': 'Daftar Keluar',
      'payment_title': 'Pembayaran',
      'unable_load_payment_methods':
          'Tidak dapat memuatkan kaedah pembayaran. Sila cuba lagi.',
      'select_payment_method_first':
          'Sila pilih kaedah pembayaran terlebih dahulu.',
      'select_outlet_first': 'Pilih cawangan sebelum daftar keluar.',
      'selected_store_closed_checkout':
          'Cawangan yang dipilih ditutup dan tidak boleh menerima daftar keluar.',
      'checkout_failed_msg':
          'Daftar keluar gagal. Sila semak troli dan kaedah pembayaran anda.',
      'order_summary': 'Ringkasan pesanan',
      'voucher_label': 'Baucher',
      'tax_and_total_confirm':
          'Cukai dan jumlah akhir disahkan semasa daftar keluar.',
      'estimated_payable': 'Anggaran bayaran',
      'subtotal_label': 'Subjumlah',
      'fulfillment_label': 'Penyempurnaan',
      'dine_in_option': 'Makan di kedai',
      'takeaway_option': 'Bawa pulang',
      'delivery_option': 'Penghantaran',
      'optional_voucher_code': 'Kod baucher (pilihan)',
      'browse_btn': 'Semak',
      'voucher_will_be_validated':
          'Baucher "{}" akan disahkan semasa daftar keluar',
      'voucher_applied': 'Baucher "{}" digunakan',
      'no_payment_methods':
          'Tiada kaedah pembayaran tersedia untuk pesanan ini.',
      'placing_order': 'Membuat pesanan...',
      'place_order': 'Buat pesanan',
      'total_amount': 'Jumlah Keseluruhan',
      'mock_payment_approved': 'Pembayaran olok-olok diluluskan',
      'payment_pending': 'Pembayaran belum selesai',
      'payment_details': 'Butiran pembayaran',
      'tax_label': 'Cukai',
      'discount_label': 'Diskaun',
      'total_label': 'Jumlah',
      'waived_label': 'Dikecualikan',
      'method_label': 'Kaedah',
      'provider_label': 'Penyedia',
      'status_label': 'Status',
      'confirm_mock_payment': 'Sahkan pembayaran olok-olok',
      'view_order_status': 'Lihat status pesanan',
      'select_voucher_title': 'Pilih Baucher',
      'unable_load_vouchers': 'Tidak dapat memuatkan baucher anda',
      'no_vouchers_available': 'Tiada baucher tersedia',
      'no_active_vouchers_sub':
          'Anda tidak mempunyai sebarang baucher aktif dalam dompet anda sekarang.',
      'spend_more_to_use': 'Belanja {} lagi',
      'choices_btn': 'Pilihan',
      'configured_item': 'Item dikonfigurasikan',
      'remove_tooltip': 'Padam',
      'no_editable_options_sub':
          'Item ini dimuatkan tanpa butiran pilihan yang boleh diedit. Anda masih boleh melaraskan kuantiti di sini.',
      'choose_one': 'Pilih 1',
      'choose_up_to': 'Pilih sehingga {}',
      'quantity_label': 'Kuantiti',
      'update_item_btn': 'Kemaskini item {}',
      'adjust_choices': 'Laras pilihan',
      'clear_cart_title': 'Kosongkan Troli?',
      'clear_cart_content':
          'Adakah anda pasti mahu mengalih keluar semua item daripada troli anda?',
      'remove_item_title': 'Padam Item?',
      'remove_item_content': 'Adakah anda pasti mahu padam item ini?',
      'cancel': 'Batal',
      'clear_all': 'Kosongkan Semua',
      'order_id_copied': 'ID Pesanan disalin',
      'voucher_code_copied': 'Kod baucher disalin',
      'order_status_title': 'Status Pesanan',
      'show_to_staff': 'Tunjukkan ini kepada kakitangan di kaunter',
      'collection_pin': 'PIN',
      'your_collection_code': 'KOD KOLEKSI ANDA',
      'unable_load_order_status': 'Tidak dapat memuatkan status pesanan.',
      'retry': 'Cuba Semula',
      'item_unavailable_remove': 'Padam',
      'each': 'setiap satu',
      'remove_unavailable_items': 'Padam Item Tidak Tersedia',
      'selected_outlet_closed': 'Cawangan Terpilih Ditutup',
      'proceed_to_checkout': 'Teruskan ke Daftar Keluar',
      'welcome_guest': 'Selamat Datang, Pelawat!',
      'guest_desc':
          'Log masuk untuk mendapatkan mata ganjaran, menuntut baucher diskaun dan membuat pesanan atas talian.',
      'login_signup': 'Log Masuk / Daftar',
      'welcome_loob': 'Selamat Datang ke Loob',
      'login_sheet_desc':
          'Log masuk dengan nombor telefon anda untuk mendapatkan mata ganjaran, menuntut baucher eksklusif dan membuat pesanan.',
      'enter_phone_hint': 'Masukkan nombor telefon',
      'continue_btn': 'Teruskan',
      'verify_code_title': 'Sahkan Kod',
      'otp_sent_to': 'Kami telah menghantar 6-digit kod OTP ke {}',
      'phone_required_err': 'Nombor telefon diperlukan',
      'otp_required_err': 'Kod pengesahan diperlukan',
      'otp_incorrect_err': 'Kod salah. Cuba "123456"',
      'demo_otp_helper': 'Kod Pengesahan Demo adalah "123456"',
      'select_country_title': 'Pilih Negara',
      'buy_now': 'Beli Sekarang',
      'unpaid_order': 'PESANAN BELUM DIBAYAR',
      'uncollected_order': 'PESANAN BELUM DIAMBIL',
      'ready_for_collection': 'Sedia untuk Diambil',
      'awaiting_payment': 'Menunggu Pembayaran',
      'preparing_order': 'Menyediakan pesanan anda...',
      'pay_now': 'Bayar Sekarang',
      'track': 'Jejak',
      'collect_btn': 'Ambil',
      'collecting_btn': 'Mengambil...',
      'retry_payment_btn': 'Cuba Semula Pembayaran',
      'processing_payment_btn': 'Memproses Pembayaran...',
      'active_order_warning_title': 'Pesanan Aktif Dikesan',
      'active_order_warning_content': 'Anda sudah mempunyai pesanan aktif. Adakah anda pasti mahu membuat satu lagi pesanan berasingan?',
    },
  };

  String _translate(String key) {
    final languageCode = locale.languageCode;
    final map = _localizedValues[languageCode] ?? _localizedValues['en']!;
    return map[key] ?? _localizedValues['en']![key] ?? key;
  }

  // ── Getters for Localized Strings ──────────────────────────────────────────

  String get home => _translate('home');
  String get menu => _translate('menu');
  String get cart => _translate('cart');
  String get vouchers => _translate('vouchers');
  String get profile => _translate('profile');
  String get orders => _translate('orders');
  String get settings => _translate('settings');

  String get goodMorning => _translate('good_morning');
  String get goodAfternoon => _translate('good_afternoon');
  String get goodEvening => _translate('good_evening');

  String get subtitleDiscover => _translate('subtitle_discover');
  String get subtitleTealive => _translate('subtitle_tealive');
  String get subtitleBaskbear => _translate('subtitle_baskbear');

  String get forYou => _translate('for_you');

  String get myCart => _translate('my_cart');
  String get cartEmpty => _translate('cart_empty');
  String get cartEmptySub => _translate('cart_empty_sub');
  String get browseMenu => _translate('browse_menu');

  String get bannerTealiveTitle => _translate('banner_tealive_title');
  String get bannerTealiveSubtitle => _translate('banner_tealive_subtitle');
  String get bannerBaskbearTitle => _translate('banner_baskbear_title');
  String get bannerBaskbearSubtitle => _translate('banner_baskbear_subtitle');

  String get myVouchers => _translate('my_vouchers');

  String get statusAvailable => _translate('status_available');
  String get statusUsed => _translate('status_used');
  String get statusExpired => _translate('status_expired');

  String get campaignsTitle => _translate('campaigns_title');
  String get banners => _translate('banners');
  String get activities => _translate('activities');

  String get preferences => _translate('preferences');
  String get language => _translate('language');
  String get country => _translate('country');
  String get support => _translate('support');
  String get helpCentre => _translate('help_centre');
  String get about => _translate('about');
  String get signOut => _translate('sign_out'); // Note: fallbacks to 'Sign Out'

  String get requiredText => _translate('required');
  String get selectLanguage => _translate('select_language');
  String get addToCart => _translate('add_to_cart');
  String get update => _translate('update');

  String get balance => _translate('balance');
  String get topUpInitiated => _translate('top_up_initiated');
  String get tpoints => _translate('tpoints');
  String get barcodeOpened => _translate('barcode_opened');
  String get delivery => _translate('delivery');
  String get pickup => _translate('pickup');
  String get deliveryOff => _translate('delivery_off');
  String get pickupOff => _translate('pickup_off');
  String get orderAgain => _translate('order_again');
  String get reorder => _translate('reorder');
  String get close => _translate('close');
  String get claim => _translate('claim');
  String get claimPromo => _translate('claim_promo');
  String get deliveryOfflineWarning => _translate('delivery_offline_warning');
  String get pickupOfflineWarning => _translate('pickup_offline_warning');
  String get eventClaimedToast => _translate('event_claimed_toast');

  String get selectOutletTitle => _translate('select_outlet_title');
  String get allBrands => _translate('all_brands');
  String get searchOutletPlaceholder => _translate('search_outlet_placeholder');
  String get noOutletsMatch => _translate('no_outlets_match');
  String get openDaily => _translate('open_daily');
  String get lastOrderBefore => _translate('last_order_before');
  String get orderNow => _translate('order_now');
  String get storeClosed => _translate('store_closed');
  String get storeTemporarilyClosed => _translate('store_temporarily_closed');
  String get ltoRichMatcha => _translate('lto_rich_matcha');
  String get ltoGrassJelly => _translate('lto_grass_jelly');
  String get favouritesCategory => _translate('favourites');
  String get favouritesEmptySub => _translate('favourites_empty_sub');
  String get businessHourHeader => _translate('business_hour_header');
  String get searchBobaPlaceholder => _translate('search_boba_placeholder');
  String get newBadge => _translate('new_badge');
  String get unavailableText => _translate('unavailable');

  String get checkoutTitle => _translate('checkout_title');
  String get paymentTitle => _translate('payment_title');
  String get unableLoadPaymentMethods =>
      _translate('unable_load_payment_methods');
  String get selectPaymentMethodFirst =>
      _translate('select_payment_method_first');
  String get selectOutletFirst => _translate('select_outlet_first');
  String get selectedStoreClosedCheckout =>
      _translate('selected_store_closed_checkout');
  String get checkoutFailedMsg => _translate('checkout_failed_msg');
  String get orderSummary => _translate('order_summary');
  String get voucherLabel => _translate('voucher_label');
  String get taxAndTotalConfirm => _translate('tax_and_total_confirm');
  String get estimatedPayable => _translate('estimated_payable');
  String get subtotalLabel => _translate('subtotal_label');
  String get fulfillmentLabel => _translate('fulfillment_label');
  String get dineInOption => _translate('dine_in_option');
  String get takeawayOption => _translate('takeaway_option');
  String get deliveryOption => _translate('delivery_option');
  String get optionalVoucherCode => _translate('optional_voucher_code');
  String get browseBtn => _translate('browse_btn');
  String get noPaymentMethods => _translate('no_payment_methods');
  String get placingOrder => _translate('placing_order');
  String get placeOrder => _translate('place_order');
  String get totalAmount => _translate('total_amount');
  String get mockPaymentApproved => _translate('mock_payment_approved');
  String get paymentPending => _translate('payment_pending');
  String get paymentDetails => _translate('payment_details');
  String get taxLabel => _translate('tax_label');
  String get discountLabel => _translate('discount_label');
  String get totalLabel => _translate('total_label');
  String get waivedLabel => _translate('waived_label');
  String get methodLabel => _translate('method_label');
  String get providerLabel => _translate('provider_label');
  String get statusLabel => _translate('status_label');
  String get confirmMockPayment => _translate('confirm_mock_payment');
  String get viewOrderStatus => _translate('view_order_status');
  String get selectVoucherTitle => _translate('select_voucher_title');
  String get unableLoadVouchers => _translate('unable_load_vouchers');
  String get noVouchersAvailable => _translate('no_vouchers_available');
  String get noActiveVouchersSub => _translate('no_active_vouchers_sub');
  String get choicesBtn => _translate('choices_btn');
  String get configuredItem => _translate('configured_item');
  String get removeTooltip => _translate('remove_tooltip');
  String get noEditableOptionsSub => _translate('no_editable_options_sub');
  String get chooseOne => _translate('choose_one');
  String get quantityLabel => _translate('quantity_label');
  String get itemUnavailableRemove => _translate('item_unavailable_remove');
  String get eachLabel => _translate('each');
  String get removeUnavailableItems => _translate('remove_unavailable_items');
  String get selectedOutletClosed => _translate('selected_outlet_closed');
  String get proceedToCheckout => _translate('proceed_to_checkout');
  String get adjustChoices => _translate('adjust_choices');
  String get productUnavailable => _translate('product_unavailable');
  String get someOptionsUnavailable => _translate('some_options_unavailable');
  String get cartAvailabilityChangedTitle =>
      _translate('cart_availability_changed_title');
  String get cartAvailabilityChangedBody =>
      _translate('cart_availability_changed_body');
  String optionUnavailableTag(String name) {
    return _translate('option_unavailable_tag').replaceAll('{}', name);
  }

  String get clearCartTitle => _translate('clear_cart_title');
  String get clearCartContent => _translate('clear_cart_content');
  String get removeItemTitle => _translate('remove_item_title');
  String get removeItemContent => _translate('remove_item_content');
  String get cancel => _translate('cancel');
  String get clearAll => _translate('clear_all');
  String get orderIdCopied => _translate('order_id_copied');
  String get voucherCodeCopied => _translate('voucher_code_copied');
  String get orderStatusTitle => _translate('order_status_title');
  String get showToStaff => _translate('show_to_staff');
  String get collectionPin => _translate('collection_pin');
  String get yourCollectionCode => _translate('your_collection_code');
  String get orderCreated => _translate('order_created');
  String get pending => _translate('pending');
  String get createdLabel => _translate('created');
  String get updatedLabel => _translate('updated');
  String get unableLoadOrderStatus => _translate('unable_load_order_status');
  String get retry => _translate('retry');

  String get welcomeGuest => _translate('welcome_guest');
  String get guestDesc => _translate('guest_desc');
  String get loginSignup => _translate('login_signup');
  String get welcomeLoob => _translate('welcome_loob');
  String get loginSheetDesc => _translate('login_sheet_desc');
  String get enterPhoneHint => _translate('enter_phone_hint');
  String get continueBtn => _translate('continue_btn');
  String get verifyCodeTitle => _translate('verify_code_title');
  String get phoneRequiredErr => _translate('phone_required_err');
  String get otpRequiredErr => _translate('otp_required_err');
  String get otpIncorrectErr => _translate('otp_incorrect_err');
  String get demoOtpHelper => _translate('demo_otp_helper');
  String get selectCountryTitle => _translate('select_country_title');
  String get buyNow => _translate('buy_now');
  String get unpaidOrder => _translate('unpaid_order');
  String get uncollectedOrder => _translate('uncollected_order');
  String get readyForCollection => _translate('ready_for_collection');
  String get awaitingPayment => _translate('awaiting_payment');
  String get preparingOrder => _translate('preparing_order');
  String get payNow => _translate('pay_now');
  String get track => _translate('track');
  String get collectBtn => _translate('collect_btn');
  String get collectingBtn => _translate('collecting_btn');
  String get retryPaymentBtn => _translate('retry_payment_btn');
  String get processingPaymentBtn => _translate('processing_payment_btn');
  String get activeOrderWarningTitle => _translate('active_order_warning_title');
  String get activeOrderWarningContent => _translate('active_order_warning_content');

  String otpSentTo(String phone) {
    return _translate('otp_sent_to').replaceAll('{}', phone);
  }

  String voucherWillBeValidated(String code) {
    return _translate('voucher_will_be_validated').replaceAll('{}', code);
  }

  String voucherApplied(String code) {
    return _translate('voucher_applied').replaceAll('{}', code);
  }

  String spendMoreToUse(String amount) {
    return _translate('spend_more_to_use').replaceAll('{}', amount);
  }

  String chooseUpTo(int count) {
    return _translate('choose_up_to').replaceAll('{}', '$count');
  }

  String updateItemBtn(String amount) {
    return _translate('update_item_btn').replaceAll('{}', amount);
  }

  String addedToCartReorderToast(String name) {
    return _translate('added_to_cart_reorder_toast').replaceAll('{}', name);
  }

  // ── Parametrized Formatting Helper Methods ─────────────────────────────────

  String addToCartBtn(String price) {
    return _translate('add_to_cart_btn').replaceAll('{}', price);
  }

  String addedToCartToast(int quantity, String productName) {
    return _translate(
      'added_to_cart_toast',
    ).replaceFirst('{}', '$quantity').replaceFirst('{}', productName);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ms'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Clean extension on BuildContext to fetch localization with [context.l10n].
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n {
    return AppLocalizations.of(this) ?? AppLocalizations(const Locale('en'));
  }
}
