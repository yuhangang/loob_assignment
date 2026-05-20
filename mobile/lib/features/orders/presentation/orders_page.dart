import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/status_message.dart';
import '../../cart/data/models/order_status_model.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/presentation/bloc/cart_state.dart';
import 'bloc/orders_page_cubit.dart';

class OrdersPage extends StatefulWidget {
  final ValueListenable<int>? refreshSignal;

  const OrdersPage({super.key, this.refreshSignal});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ScrollController _scrollController = ScrollController();
  late final OrdersPageCubit _ordersCubit;

  @override
  void initState() {
    super.initState();
    _ordersCubit = OrdersPageCubit();
    _scrollController.addListener(_handleScroll);
    widget.refreshSignal?.addListener(_handleRefreshSignal);
    _loadFirstPage();
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
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _ordersCubit.close();
    super.dispose();
  }

  void _handleRefreshSignal() {
    if (!mounted) return;
    _loadFirstPage();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    final country = context.read<CartBloc>().state.countryCode;
    await _ordersCubit.loadFirstPage(countryCode: country);
  }

  Future<void> _reload() async {
    await _loadFirstPage();
  }

  Future<void> _loadMore() async {
    final country = context.read<CartBloc>().state.countryCode;
    await _ordersCubit.loadMore(countryCode: country);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider.value(
      value: _ordersCubit,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.orders)),
        body: BlocListener<CartBloc, CartState>(
          listenWhen: (previous, current) =>
              previous.countryCode != current.countryCode,
          listener: (context, cartState) {
            _ordersCubit.loadFirstPage(countryCode: cartState.countryCode);
          },
          child: BlocBuilder<OrdersPageCubit, OrdersPageState>(
            builder: (context, state) => _buildBody(theme, state),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, OrdersPageState state) {
    if (state.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            StatusMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load orders',
              subtitle: 'Pull to refresh and try again.',
              iconColor: theme.colorScheme.error,
            ),
          ],
        ),
      );
    }
    if (state.orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            StatusMessage(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              subtitle: 'Orders created from checkout will appear here.',
              iconColor: theme.colorScheme.primary,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: AppSpacing.pageHorizontal,
          right: AppSpacing.pageHorizontal,
          top: AppSpacing.pageHorizontal,
          bottom: AppSpacing.pageHorizontal + context.cartFloatingBarPadding,
        ),
        itemCount: state.orders.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index >= state.orders.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _OrderCard(order: state.orders[index]);
        },
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
