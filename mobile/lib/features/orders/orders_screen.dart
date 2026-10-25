import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_ext.dart';
import '../auth/auth_controller.dart';
import 'order_providers.dart';

const _activeStatuses = {
  'CREATED',
  'PENDING_PAYMENT',
  'PAID',
  'CONFIRMED',
  'PREPARING',
  'READY_FOR_PICKUP',
  'COURIER_ASSIGNED',
  'PICKED_UP',
  'ON_THE_WAY',
  'PAYMENT_FAILED',
};

class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.lock_outline_rounded,
    title: title,
    message: message,
    actionLabel: context.l.signIn,
    onAction: () => context.push('/login'),
  );
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navOrders)),
        body: SignInPrompt(
          title: l.signInToSeeOrders,
          message: l.signInToSeeOrdersHint,
        ),
      );
    }
    final orders = ref.watch(ordersProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.navOrders),
          bottom: TabBar(
            indicatorColor: FeyaColors.primary,
            labelColor: FeyaColors.primary,
            unselectedLabelColor: FeyaColors.textSecondary,
            dividerColor: FeyaColors.border,
            tabs: [
              Tab(text: l.activeOrders),
              Tab(text: l.orderHistory),
            ],
          ),
        ),
        body: orders.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(ordersProvider),
          ),
          data: (page) {
            final active = page.items
                .where((o) => _activeStatuses.contains(o.status))
                .toList();
            final past = page.items
                .where((o) => !_activeStatuses.contains(o.status))
                .toList();
            return TabBarView(
              children: [
                _OrderList(items: active, empty: l.noActiveOrders, ref: ref),
                _OrderList(items: past, empty: l.noPastOrders, ref: ref),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.items,
    required this.empty,
    required this.ref,
  });
  final List<OrderSummary> items;
  final String empty;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: FeyaColors.primary,
      backgroundColor: FeyaColors.surface,
      onRefresh: () async {
        ref.invalidate(ordersProvider);
        await ref
            .read(ordersProvider.future)
            .catchError(
              (_) => const PageData<OrderSummary>(
                items: [],
                page: 0,
                hasNext: false,
                total: 0,
              ),
            );
      },
      child: items.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 420,
                  child: EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: empty,
                    actionLabel: context.l.goToCatalog,
                    onAction: () => context.go('/catalog'),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(FeyaSpace.page),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _OrderCard(order: items[i]),
            ),
    );
  }
}

String deliveryWhen(
  BuildContext context, {
  required bool asap,
  required String? date,
  required String? start,
  required String? end,
}) {
  final l = context.l;
  if (asap) return l.asapDelivery;
  if (date == null) return '';
  final d = DateTime.tryParse(date);
  final day = d == null ? date : formatDate(d, context.localeName);
  return start == null ? day : '$day, $start–$end';
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    return Panel(
      onTap: () => context.push('/orders/${order.id}'),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 84,
            child: NetImage(
              order.firstItemImage,
              radius: BorderRadius.circular(FeyaRadius.sm),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(order.number, style: t.titleSmall)),
                    StatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  order.firstItemName == null
                      ? l.itemsCount(order.itemCount)
                      : (order.itemCount > 1
                            ? '${order.firstItemName} +${order.itemCount - 1}'
                            : order.firstItemName!),
                  style: t.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  deliveryWhen(
                    context,
                    asap: order.asap,
                    date: order.deliveryDate,
                    start: order.slotStart,
                    end: order.slotEnd,
                  ),
                  style: t.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  formatMoney(order.total),
                  style: t.titleSmall?.copyWith(color: FeyaColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
