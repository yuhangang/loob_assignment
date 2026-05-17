import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../data/models/order_status_model.dart';
import '../data/repositories/cart_repository.dart';

class OrderStatusPage extends StatefulWidget {
  final String trackingId;

  const OrderStatusPage({super.key, required this.trackingId});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  final CartRepository _repository = sl<CartRepository>();
  late Future<OrderStatusModel> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _repository.getOrderStatus(widget.trackingId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Order Status')),
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
                child: Text(
                  'Unable to load order status.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }
          final status = snapshot.data!;
          final currency = status.trackingIdCurrency;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                status.status,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                status.orderTrackingId,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _StatusRow(label: 'Payment', value: status.paymentStatus),
              _StatusRow(
                label: 'Total',
                value: status.totalAmount.toDisplayPrice(currency),
              ),
              _StatusRow(label: 'Created', value: status.createdAt),
              _StatusRow(label: 'Updated', value: status.updatedAt),
            ],
          );
        },
      ),
    );
  }
}

extension on OrderStatusModel {
  String get trackingIdCurrency {
    if (orderTrackingId.startsWith('TH-')) return 'THB';
    return 'MYR';
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
