import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_state.dart';
import '../data/models/store_model.dart';

/// Full-screen outlet selector featuring an interactive mock map and detailed store cards.
class SelectOutletPage extends StatefulWidget {
  const SelectOutletPage({
    super.key,
    required this.stores,
    required this.selectedStoreId,
  });

  final List<StoreModel> stores;
  final int selectedStoreId;

  @override
  State<SelectOutletPage> createState() => _SelectOutletPageState();
}

class _SelectOutletPageState extends State<SelectOutletPage> {
  String _query = '';
  int? _selectedBrandFilter;
  late List<StoreModel> _filteredStores;

  @override
  void initState() {
    super.initState();
    _filteredStores = widget.stores;
  }

  void _filterStores(String value) {
    setState(() {
      _query = value.trim().toLowerCase();
      _applyFilters();
    });
  }

  void _setBrandFilter(int? brandId) {
    setState(() {
      _selectedBrandFilter = brandId;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<StoreModel> result = widget.stores;
    if (_query.isNotEmpty) {
      result = result.where((store) {
        return store.name.toLowerCase().contains(_query) ||
            store.address.toLowerCase().contains(_query) ||
            store.storeCode.toLowerCase().contains(_query);
      }).toList();
    }
    if (_selectedBrandFilter != null) {
      result = result
          .where((store) => store.brandId == _selectedBrandFilter)
          .toList();
    }
    _filteredStores = result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTealive = theme.colorScheme.primary == AppColors.tealivePrimary;
    final isDiscover = theme.colorScheme.primary == AppColors.discoverPrimary;

    // Core brand color matching the screenshot
    final primaryColor = isTealive
        ? AppColors.tealivePrimary
        : (isDiscover ? AppColors.discoverGreen : theme.colorScheme.primary);

    return Scaffold(
      backgroundColor: AppColors
          .softWhiteBg, // Cozy warm light background matching the screenshot
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTealive ? Icons.local_drink_rounded : Icons.coffee_rounded,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.selectOutletTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          // Dynamic Cart Button with Badge
          BlocBuilder<CartBloc, CartState>(
            builder: (context, cartState) {
              final count = cartState.totalQuantity;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shopping_bag_outlined,
                      color: primaryColor,
                      size: 24,
                    ),
                    onPressed: () => context.push(AppRouter.cart),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 250,
            child: _MockMapWidget(
              filteredStores: _filteredStores,
              selectedBrandFilter: _selectedBrandFilter,
              onBrandFilterChanged: _setBrandFilter,
            ),
          ),

          // Search & Store List Area
          Expanded(
            child: Column(
              children: [
                // In-list Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.md,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xs,
                  ),
                  child: TextField(
                    onChanged: _filterStores,
                    decoration: InputDecoration(
                      hintText: context.l10n.searchOutletPlaceholder,
                      hintStyle: const TextStyle(color: AppColors.grey400),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: primaryColor,
                      ),
                      fillColor: AppColors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.grey200,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                        borderSide: BorderSide(
                          color: primaryColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // Brand Filter Chips Row
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _BrandFilterChip(
                          label: context.l10n.allBrands,
                          isSelected: _selectedBrandFilter == null,
                          icon: Icons.storefront_rounded,
                          selectedColor: primaryColor,
                          onTap: () => _setBrandFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _BrandFilterChip(
                          label: 'Tealive',
                          isSelected: _selectedBrandFilter == 1,
                          icon: Icons.local_drink_rounded,
                          selectedColor: AppColors.tealivePrimary,
                          onTap: () => _setBrandFilter(1),
                        ),
                        const SizedBox(width: 8),
                        _BrandFilterChip(
                          label: 'Bask Bear',
                          isSelected: _selectedBrandFilter == 2,
                          icon: Icons.coffee_rounded,
                          selectedColor: AppColors.tealivePrimary,
                          onTap: () => _setBrandFilter(2),
                        ),
                      ],
                    ),
                  ),
                ),

                // Outlet Card List
                Expanded(
                  child: _filteredStores.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.noOutletsMatch,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.grey600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageHorizontal,
                            0,
                            AppSpacing.pageHorizontal,
                            AppSpacing.xl,
                          ),
                          itemCount: _filteredStores.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final store = _filteredStores[index];
                            final isSelected =
                                store.id == widget.selectedStoreId;

                            // Generate high-fidelity distance and operating hours mock
                            final simulatedDistance =
                                '${(index + 1) * 0.7 + 0.3}KM';

                            final openDailyText = context.l10n.openDaily;
                            final lastOrderBefore =
                                context.l10n.lastOrderBefore;

                            String hours = '$openDailyText 10:30AM - 09:00PM';
                            String lastOrder = '$lastOrderBefore 08:30pm';

                            if (index == 1) {
                              hours = '$openDailyText 10:00AM - 10:00PM';
                              lastOrder = '$lastOrderBefore 09:30pm';
                            } else if (index == 2) {
                              hours = '$openDailyText 11:00AM - 10:30PM';
                              lastOrder = '$lastOrderBefore 10:00pm';
                            } else if (index == 3) {
                              hours = '$openDailyText 10:00AM - 10:00PM';
                              lastOrder = '$lastOrderBefore 09:30pm';
                            }

                            return _OutletCard(
                              store: store,
                              isSelected: isSelected,
                              distance: simulatedDistance,
                              hours: hours,
                              lastOrder: lastOrder,
                              primaryColor: primaryColor,
                              onTap: () {
                                if (!store.acceptsOrders) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        store.statusMessage.isEmpty
                                            ? context
                                                  .l10n
                                                  .selectedStoreClosedCheckout
                                            : store.statusMessage,
                                      ),
                                    ),
                                  );
                                }
                                context.pop(store);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A highly polished, beautiful custom-painted Google Map mock.
class _MockMapWidget extends StatelessWidget {
  const _MockMapWidget({
    required this.filteredStores,
    required this.selectedBrandFilter,
    required this.onBrandFilterChanged,
  });

  final List<StoreModel> filteredStores;
  final int? selectedBrandFilter;
  final ValueChanged<int?> onBrandFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Beautiful vector background map
        Positioned.fill(
          child: CustomPaint(painter: _MapPainter(stores: filteredStores)),
        ),

        // Brand Selector Capsule (Top-Left)
        Positioned(
          top: 16,
          left: 16,
          child: Theme(
            data: Theme.of(context).copyWith(cardColor: AppColors.white),
            child: PopupMenuButton<int>(
              initialValue: selectedBrandFilter ?? 0,
              onSelected: (val) {
                onBrandFilterChanged(val == 0 ? null : val);
              },
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem<int>(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(
                        Icons.storefront_rounded,
                        color: AppColors.grey500,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'All Brands',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<int>(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_drink_rounded,
                        color: AppColors.tealivePrimary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tealive',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<int>(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(
                        Icons.coffee_rounded,
                        color: AppColors.tealivePrimary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Baskbear',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selectedBrandFilter == null
                            ? AppColors.grey700
                            : AppColors.tealivePrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        selectedBrandFilter == null
                            ? 'all brands'
                            : (selectedBrandFilter == 1
                                  ? 'tealive'
                                  : 'baskbear'),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: selectedBrandFilter == null
                          ? AppColors.grey700
                          : AppColors.tealivePrimary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Search Button (Top-Right)
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.search_rounded,
              color: selectedBrandFilter == null
                  ? AppColors.grey700
                  : AppColors.tealivePrimary,
              size: 20,
            ),
          ),
        ),

        // Fullscreen Toggle Button (Bottom-Right)
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.fullscreen_rounded,
              color: selectedBrandFilter == null
                  ? AppColors.grey700
                  : AppColors.tealivePrimary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter to draw a highly stylized map layout with roads, parks, rivers, and location markers.
class _MapPainter extends CustomPainter {
  final List<StoreModel> stores;

  _MapPainter({required this.stores});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = AppColors.waterBlue; // Soft blue water background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final landPaint = Paint()
      ..color = AppColors.warmCream; // Warm cream land area
    final landPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.8, 0)
      ..cubicTo(
        size.width * 0.7,
        size.height * 0.3,
        size.width * 0.4,
        size.height * 0.2,
        size.width * 0.3,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(landPath, landPaint);

    final parkPaint = Paint()..color = AppColors.parkGreen; // Green park area
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, 20, size.width * 0.35, size.height * 0.4),
        const Radius.circular(12),
      ),
      parkPaint,
    );

    // Drawing roads
    final roadPaint = Paint()
      ..color = AppColors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadBorderPaint = Paint()
      ..color = AppColors.roadGrey
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final List<Path> roads = [
      Path()
        ..moveTo(-20, size.height * 0.4)
        ..lineTo(size.width * 0.5, size.height * 0.3)
        ..cubicTo(
          size.width * 0.7,
          size.height * 0.25,
          size.width * 0.8,
          size.height * 0.6,
          size.width + 20,
          size.height * 0.8,
        ),
      Path()
        ..moveTo(size.width * 0.2, -20)
        ..lineTo(size.width * 0.2, size.height + 20),
      Path()
        ..moveTo(size.width * 0.7, -20)
        ..lineTo(size.width * 0.5, size.height + 20),
    ];

    for (final path in roads) {
      canvas.drawPath(path, roadBorderPaint);
      canvas.drawPath(path, roadPaint);
    }

    // Road Label (Text)
    const textStyle = TextStyle(
      color: AppColors.grey500,
      fontSize: 8,
      fontWeight: FontWeight.bold,
    );
    final textSpan = TextSpan(text: 'Jalan Medang Tanduk', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(size.width * 0.34, size.height * 0.22);
    canvas.rotate(-0.1);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();

    final textSpan2 = TextSpan(text: 'Jalan Kapas', style: textStyle);
    final textPainter2 = TextPainter(
      text: textSpan2,
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(size.width * 0.75, size.height * 0.45);
    canvas.rotate(0.9);
    textPainter2.paint(canvas, Offset.zero);
    canvas.restore();

    // User Current Location Blue Dot
    final bluePulsePaint = Paint()
      ..color = AppColors.signalBlue.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final blueDotPaint = Paint()
      ..color = AppColors.signalBlue
      ..style = PaintingStyle.fill;
    final whiteRingPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Offset userLocation = Offset(size.width * 0.5, size.height * 0.48);
    canvas.drawCircle(userLocation, 16, bluePulsePaint);
    canvas.drawCircle(userLocation, 6, blueDotPaint);
    canvas.drawCircle(userLocation, 6, whiteRingPaint);

    // Dynamic Outlet pins
    for (int i = 0; i < stores.length; i++) {
      final store = stores[i];
      // Generate deterministic offset based on store ID
      final double dx = (0.15 + ((store.id * 37) % 70) / 100.0) * size.width;
      final double dy = (0.15 + ((store.id * 53) % 70) / 100.0) * size.height;
      final loc = Offset(dx, dy);

      final pinPaint = Paint()
        ..color = AppColors.tealivePrimary
        ..style = PaintingStyle.fill;

      // Draw a teardrop marker shape
      final path = Path()
        ..moveTo(loc.dx, loc.dy)
        ..cubicTo(
          loc.dx - 8,
          loc.dy - 12,
          loc.dx - 8,
          loc.dy - 22,
          loc.dx,
          loc.dy - 22,
        )
        ..cubicTo(
          loc.dx + 8,
          loc.dy - 22,
          loc.dx + 8,
          loc.dy - 12,
          loc.dx,
          loc.dy,
        )
        ..close();
      canvas.drawPath(path, pinPaint);

      // Draw dynamic symbol inside pin based on brand
      final innerCirclePaint = Paint()..color = AppColors.white;
      canvas.drawCircle(Offset(loc.dx, loc.dy - 14), 4, innerCirclePaint);

      final symbolColorPaint = Paint()..color = AppColors.warning;

      canvas.drawCircle(Offset(loc.dx, loc.dy - 14), 2.5, symbolColorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.stores != stores;
}

/// Outlet Card styled precisely like the screenshot with the brand badge and ordered layout.
class _OutletCard extends StatelessWidget {
  const _OutletCard({
    required this.store,
    required this.isSelected,
    required this.distance,
    required this.hours,
    required this.lastOrder,
    required this.primaryColor,
    required this.onTap,
  });

  final StoreModel store;
  final bool isSelected;
  final String distance;
  final String hours;
  final String lastOrder;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final storeBrandColor = AppColors.tealivePrimary;

    final storeBrandBg = AppColors.tealiveWarmCream;

    // Check if it is a Tealive PLUS store to apply a premium outline and badge
    final isPlusStore = store.name.toUpperCase().contains('PLUS');
    final isClosed = !store.acceptsOrders;
    final statusLabel =
        store.operationalStatus.toUpperCase() == 'TEMPORARILY_CLOSED'
        ? context.l10n.storeTemporarilyClosed
        : context.l10n.storeClosed;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Outlet Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: storeBrandBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: isClosed
                  ? theme.colorScheme.error.withValues(alpha: 0.35)
                  : isPlusStore
                  ? storeBrandColor
                  : AppColors.warmFulfillmentOrangeBg.withValues(alpha: 0.5),
              width: isPlusStore || isClosed ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Name & Distance Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      color: storeBrandColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              store.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isClosed
                                    ? theme.colorScheme.error
                                    : storeBrandColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: store.brandId == 1
                                  ? AppColors.tealivePrimary
                                  : AppColors.baskbearAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              store.brandId == 1 ? 'Tealive' : 'Bask Bear',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: storeBrandColor.withValues(alpha: 0.6),
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          distance,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.grey700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Address
                Padding(
                  padding: const EdgeInsets.only(left: 32.0),
                  child: Text(
                    store.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey600,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(left: 32.0, top: 12, bottom: 12),
                  child: Divider(
                    height: 1,
                    color: AppColors
                        .dividerBeige, // Warm divider matching the cream card
                  ),
                ),

                // Hours & "Order Now" Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 32),
                    Icon(
                      isClosed
                          ? Icons.warning_amber_rounded
                          : Icons.access_time_rounded,
                      color: isClosed
                          ? theme.colorScheme.error
                          : storeBrandColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isClosed ? statusLabel : hours,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isClosed
                                  ? theme.colorScheme.error
                                  : storeBrandColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            isClosed
                                ? (store.statusMessage.isEmpty
                                      ? context.l10n.selectedStoreClosedCheckout
                                      : store.statusMessage)
                                : '($lastOrder)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.grey600,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Order Now Button
                    ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isClosed
                            ? theme.colorScheme.error.withValues(alpha: 0.75)
                            : storeBrandColor,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        isClosed ? statusLabel : context.l10n.orderNow,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // tealive plus badge overlapping top-left (only for PLUS stores)
        if (isPlusStore)
          Positioned(
            top: -10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: storeBrandColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'tealive plus',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BrandFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData icon;
  final Color selectedColor;
  final VoidCallback onTap;

  const _BrandFilterChip({
    required this.label,
    required this.isSelected,
    required this.icon,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.grey200,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.white : AppColors.grey600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.grey800,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
