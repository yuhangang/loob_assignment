import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loob_app/core/localization/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../data/models/order_status_model.dart';
import '../domain/repositories/cart_repository.dart';

class OrderStatusPage extends StatefulWidget {
  final String trackingId;

  const OrderStatusPage({super.key, required this.trackingId});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage>
    with SingleTickerProviderStateMixin {
  final ICartRepository _repository = sl<ICartRepository>();
  late Future<OrderStatusModel> _statusFuture;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _statusFuture = _repository.getOrderStatus(widget.trackingId);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.orderStatusTitle)),
      body: FutureBuilder<OrderStatusModel>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.l10n.unableLoadOrderStatus,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final status = snapshot.data!;
          return _OrderStatusContent(
            status: status,
            pulseAnimation: _pulseAnimation,
          );
        },
      ),
    );
  }
}

class _OrderStatusContent extends StatelessWidget {
  final OrderStatusModel status;
  final Animation<double> pulseAnimation;

  const _OrderStatusContent({
    required this.status,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final currency = status.trackingIdCurrency;
    final pin = status.orderTrackingId.collectionPin;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        const SizedBox(height: AppSpacing.sm),

        // ── Collection Card ──────────────────────────────────────────────
        _CollectionCard(
          trackingId: status.orderTrackingId,
          pin: pin,
          pulseAnimation: pulseAnimation,
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Status Details ───────────────────────────────────────────────
        _DetailCard(
          children: [
            _DetailRow(
              icon: Icons.circle_rounded,
              label: context.l10n.statusLabel,
              value: status.status.isEmpty
                  ? context.l10n.orderCreated
                  : status.status,
              valueColor: _statusColor(context, status.status),
            ),
            const Divider(height: 1, indent: 36),
            _DetailRow(
              icon: Icons.payment_rounded,
              label: context.l10n.paymentTitle,
              value: status.paymentStatus.isEmpty
                  ? context.l10n.pending
                  : status.paymentStatus,
            ),
            const Divider(height: 1, indent: 36),
            _DetailRow(
              icon: Icons.receipt_rounded,
              label: context.l10n.subtotalLabel,
              value: status.subtotal.toDisplayPrice(currency),
            ),
            for (final charge in status.charges.where(
              (charge) => !charge.waived,
            )) ...[
              const Divider(height: 1, indent: 36),
              _DetailRow(
                icon: Icons.shopping_bag_rounded,
                label: charge.name.isEmpty ? charge.code : charge.name,
                value: charge.amount.toDisplayPrice(currency),
              ),
            ],
            for (final charge in status.charges.where(
              (charge) => charge.waived,
            )) ...[
              const Divider(height: 1, indent: 36),
              _DetailRow(
                icon: Icons.shopping_bag_rounded,
                label: charge.name.isEmpty ? charge.code : charge.name,
                value: context.l10n.waivedLabel,
                valueColor: Colors.green,
              ),
            ],
            const Divider(height: 1, indent: 36),
            _DetailRow(
              icon: Icons.percent_rounded,
              label: context.l10n.taxLabel,
              value: status.taxAmount.toDisplayPrice(currency),
            ),
            if (status.discountAmount > 0) ...[
              const Divider(height: 1, indent: 36),
              _DetailRow(
                icon: Icons.local_offer_rounded,
                label: context.l10n.discountLabel,
                value: '-${status.discountAmount.toDisplayPrice(currency)}',
                valueColor: Colors.green,
              ),
            ],
            const Divider(height: 1, indent: 36),
            _DetailRow(
              icon: Icons.attach_money_rounded,
              label: context.l10n.totalLabel,
              value: status.totalAmount.toDisplayPrice(currency),
              isBold: true,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        _DetailCard(
          children: [
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: context.l10n.createdLabel,
              value: status.createdAt.toLocalTime,
            ),
            const Divider(height: 1, indent: 36),
            _DetailRow(
              icon: Icons.update_rounded,
              label: context.l10n.updatedLabel,
              value: status.updatedAt.toLocalTime,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Color? _statusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'FAILED':
      case 'PAYMENT_FAILED':
        return theme.colorScheme.error;
      case 'PROCESSING':
        return Colors.orange;
      default:
        return null;
    }
  }
}

// ── Collection Card ──────────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  final String trackingId;
  final String pin;
  final Animation<double> pulseAnimation;

  const _CollectionCard({
    required this.trackingId,
    required this.pin,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.primary.withValues(alpha: 0.25),
                  theme.colorScheme.secondary.withValues(alpha: 0.15),
                ]
              : [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                ],
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            // Label
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  context.l10n.showToStaff,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // QR Code
            ScaleTransition(
              scale: pulseAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: QrImageView(
                  data: trackingId,
                  version: QrVersions.auto,
                  size: 180,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1A1A2E),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // PIN label
            Text(
              context.l10n.collectionPin,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // PIN digits
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: pin
                  .split('')
                  .map((digit) => _PinDigit(digit: digit))
                  .toList(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Tracking ID with copy
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: trackingId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.orderIdCopied),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trackingId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinDigit extends StatelessWidget {
  final String digit;

  const _PinDigit({required this.digit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      width: 56,
      height: 68,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.primary,
          height: 1,
        ),
      ),
    );
  }
}

// ── Detail Card / Row ────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Extensions ───────────────────────────────────────────────────────────────

extension on OrderStatusModel {
  String get trackingIdCurrency {
    if (orderTrackingId.startsWith('TH-')) return 'THB';
    return 'MYR';
  }
}

extension on String {
  /// Extracts the last 4 numeric digits from the tracking ID as the PIN.
  /// e.g. "MY-20250518-4823" → "4823"
  String get collectionPin {
    final digits = replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) return digits.substring(digits.length - 4);
    return digits.padLeft(4, '0');
  }

  /// Parses ISO-8601 datetime and returns a short local representation.
  String get toLocalTime {
    if (isEmpty) return '-';
    try {
      final dt = DateTime.parse(this).toLocal();
      String pad(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
          '${pad(dt.hour)}:${pad(dt.minute)}';
    } catch (_) {
      return this;
    }
  }
}
