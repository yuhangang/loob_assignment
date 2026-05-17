import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../cart/data/models/order_status_model.dart';
import '../data/repositories/order_repository.dart';

class OrdersPage extends StatefulWidget {
  final ValueListenable<int>? refreshSignal;

  const OrdersPage({super.key, this.refreshSignal});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final OrderRepository _repository = sl<OrderRepository>();
  late Future<List<OrderStatusModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _repository.loadOrders();
    widget.refreshSignal?.addListener(_handleRefreshSignal);
  }

  @override
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal == widget.refreshSignal) return;
    oldWidget.refreshSignal?.removeListener(_handleRefreshSignal);
    widget.refreshSignal?.addListener(_handleRefreshSignal);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefreshSignal);
    super.dispose();
  }

  void _handleRefreshSignal() {
    if (!mounted) return;
    setState(() {
      _ordersFuture = _repository.loadOrders();
    });
  }

  Future<void> _reload() async {
    setState(() {
      _ordersFuture = _repository.loadOrders();
    });
    await _ordersFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.orders)),
      body: FutureBuilder<List<OrderStatusModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _OrdersMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load orders',
              subtitle: 'Pull to refresh and try again.',
              color: theme.colorScheme.error,
            );
          }

          final orders = snapshot.data ?? const [];
          if (orders.isEmpty) {
            return _OrdersMessage(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              subtitle: 'Orders created from checkout will appear here.',
              color: theme.colorScheme.primary,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                return _OrderCard(order: orders[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderStatusModel order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = order.orderTrackingId.startsWith('TH-') ? 'THB' : 'MYR';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRouter.orderStatus,
            arguments: {'trackingId': order.orderTrackingId},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderTrackingId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${order.statusLabel} | ${order.paymentLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.totalAmount.toDisplayPrice(currency),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _OrdersMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.65,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on OrderStatusModel {
  String get statusLabel => status.isEmpty ? 'Order created' : status;
  String get paymentLabel =>
      paymentStatus.isEmpty ? 'Payment pending' : paymentStatus;
}
