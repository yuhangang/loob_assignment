import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../../core/localization/app_localizations.dart';
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
  late List<StoreModel> _filteredStores;

  @override
  void initState() {
    super.initState();
    _filteredStores = widget.stores;
  }

  void _filterStores(String value) {
    setState(() {
      _query = value.trim().toLowerCase();
      if (_query.isEmpty) {
        _filteredStores = widget.stores;
      } else {
        _filteredStores = widget.stores.where((store) {
          return store.name.toLowerCase().contains(_query) ||
              store.address.toLowerCase().contains(_query) ||
              store.storeCode.toLowerCase().contains(_query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTealive = theme.colorScheme.primary.toARGB32() == 0xFF4C1D40;
    final isDiscover = theme.colorScheme.primary.toARGB32() == 0xFFB2C9AB;

    // Core brand color matching the screenshot
    final primaryColor = isTealive
        ? const Color(0xFF4C1D40)
        : (isDiscover ? const Color(0xFF2E4A1F) : theme.colorScheme.primary);

    return Scaffold(
      backgroundColor: const Color(
        0xFFFAF9F6,
      ), // Cozy warm light background matching the screenshot
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          context.l10n.selectOutletTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: primaryColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
      body: Column(
        children: [
          // Google Map Mock Container
          const SizedBox(height: 250, child: _MockMapWidget()),

          // Search & Store List Area
          Expanded(
            child: Column(
              children: [
                // In-list Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                    vertical: AppSpacing.md,
                  ),
                  child: TextField(
                    onChanged: _filterStores,
                    decoration: InputDecoration(
                      hintText: context.l10n.searchOutletPlaceholder,
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: primaryColor,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                        borderSide: BorderSide(
                          color: Colors.grey.shade200,
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

                // Outlet Card List
                Expanded(
                  child: _filteredStores.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.noOutletsMatch,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade600,
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
                                Navigator.pop(context, store);
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
  const _MockMapWidget();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Beautiful vector background map
        Positioned.fill(child: CustomPaint(painter: _MapPainter())),

        // Brand Selector Capsule (Top-Left)
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                    color: const Color(0xFF4C1D40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'tealive',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF4C1D40),
                  size: 16,
                ),
              ],
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
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Color(0xFF4C1D40),
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
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.fullscreen_rounded,
              color: Color(0xFF4C1D40),
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
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFFE5F1F6); // Soft blue water background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final landPaint = Paint()
      ..color = const Color(0xFFF2F4F3); // Warm cream land area
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

    final parkPaint = Paint()
      ..color = const Color(0xFFD5ECD4); // Green park area
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, 20, size.width * 0.35, size.height * 0.4),
        const Radius.circular(12),
      ),
      parkPaint,
    );

    // Drawing roads
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFD4DAD9)
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
      color: Color(0xFF888888),
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
      ..color = const Color(0xFF2E86DE).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final blueDotPaint = Paint()
      ..color = const Color(0xFF2E86DE)
      ..style = PaintingStyle.fill;
    final whiteRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Offset userLocation = Offset(size.width * 0.5, size.height * 0.48);
    canvas.drawCircle(userLocation, 16, bluePulsePaint);
    canvas.drawCircle(userLocation, 6, blueDotPaint);
    canvas.drawCircle(userLocation, 6, whiteRingPaint);

    // Outlet pins
    final pinPaint = Paint()
      ..color = const Color(0xFF4C1D40)
      ..style = PaintingStyle.fill;

    final List<Offset> pinLocations = [
      Offset(size.width * 0.22, size.height * 0.22),
      Offset(size.width * 0.65, size.height * 0.7),
      Offset(size.width * 0.78, size.height * 0.15),
    ];

    for (final loc in pinLocations) {
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

      // Draw boba cup symbol inside pin
      final innerCirclePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(loc.dx, loc.dy - 14), 4, innerCirclePaint);
      final teaColorPaint = Paint()..color = const Color(0xFFFFC107);
      canvas.drawCircle(Offset(loc.dx, loc.dy - 14), 2.5, teaColorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Outlet Card styled precisely like the screenshot with the tealive plus badge and ordered layout.
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

    // Check if it is a Tealive PLUS store to apply a premium outline and badge
    final isPlusStore = store.name.toUpperCase().contains('PLUS');
    final isClosed = !store.acceptsOrders;
    final statusLabel =
        store.operationalStatus.toUpperCase() == 'TEMPORARILY_CLOSED'
        ? context.l10n.storeTemporarilyClosed
        : context.l10n.storeClosed;

    // Card background is warm peach/cream
    const cardBgColor = Color(0xFFFEF7EE); // Soft cream matching the screenshot

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Outlet Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: isClosed
                  ? theme.colorScheme.error.withValues(alpha: 0.35)
                  : isPlusStore
                  ? primaryColor
                  : Colors.orange.shade100.withValues(alpha: 0.5),
              width: isPlusStore || isClosed ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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
                      color: primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isClosed
                              ? theme.colorScheme.error
                              : primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: primaryColor.withValues(alpha: 0.6),
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          distance,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
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
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(left: 32.0, top: 12, bottom: 12),
                  child: Divider(
                    height: 1,
                    color: Color(
                      0xFFF3E7DC,
                    ), // Warm divider matching the cream card
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
                      color: isClosed ? theme.colorScheme.error : primaryColor,
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
                                  : primaryColor,
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
                              color: Colors.grey.shade600,
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
                            : primaryColor,
                        foregroundColor: Colors.white,
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
                color: primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'tealive plus',
                style: TextStyle(
                  color: Colors.white,
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
