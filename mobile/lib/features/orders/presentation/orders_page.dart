import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/status_message.dart';
import '../../cart/data/models/order_status_model.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_state.dart';
import '../domain/repositories/order_repository.dart';

class OrdersPage extends StatefulWidget {
  final ValueListenable<int>? refreshSignal;

  const OrdersPage({super.key, this.refreshSignal});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final IOrderRepository _repository = sl<IOrderRepository>();
  late Future<List<OrderStatusModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    final country = context.read<CartBloc>().state.countryCode;
    _ordersFuture = _repository.loadOrders(countryCode: country);
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
      final country = context.read<CartBloc>().state.countryCode;
      _ordersFuture = _repository.loadOrders(countryCode: country);
    });
  }

  Future<void> _reload() async {
    setState(() {
      final country = context.read<CartBloc>().state.countryCode;
      _ordersFuture = _repository.loadOrders(countryCode: country);
    });
    await _ordersFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.orders)),
      body: BlocListener<CartBloc, CartState>(
        listenWhen: (previous, current) =>
            previous.countryCode != current.countryCode,
        listener: (context, cartState) {
          setState(() {
            _ordersFuture = _repository.loadOrders(
              countryCode: cartState.countryCode,
            );
          });
        },
        child: FutureBuilder<List<OrderStatusModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return StatusMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Unable to load orders',
                subtitle: 'Pull to refresh and try again.',
                iconColor: theme.colorScheme.error,
              );
            }

            final orders = snapshot.data ?? const [];
            if (orders.isEmpty) {
              return StatusMessage(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                subtitle: 'Orders created from checkout will appear here.',
                iconColor: theme.colorScheme.primary,
              );
            }

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                itemCount: orders.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  return _OrderCard(order: orders[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderStatusModel order;

  const _OrderCard({required this.order});

  String _formatTimestamp(String rawTimestamp) {
    if (rawTimestamp.isEmpty) return '';
    final parsed = DateTime.tryParse(rawTimestamp);
    if (parsed == null) return rawTimestamp;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = order.orderTrackingId.startsWith('TH-') ? 'THB' : 'MYR';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(
            AppRouter.orderStatus,
            extra: {'trackingId': order.orderTrackingId},
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
                    if (order.createdAt.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _formatTimestamp(order.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.45,
                          ),
                          fontSize: 10,
                        ),
                      ),
                    ],
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

extension on OrderStatusModel {
  String get statusLabel => status.isEmpty ? 'Order created' : status;
  String get paymentLabel =>
      paymentStatus.isEmpty ? 'Payment pending' : paymentStatus;
}
