import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_ext.dart';
import 'order_providers.dart';
import 'orders_screen.dart' show deliveryWhen;

const orderFlow = [
  'PAID',
  'CONFIRMED',
  'PREPARING',
  'READY_FOR_PICKUP',
  'COURIER_ASSIGNED',
  'PICKED_UP',
  'ON_THE_WAY',
  'DELIVERED',
];

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final async = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(async.value?.number ?? l.order),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: l.back,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/orders'),
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        data: (o) => RefreshIndicator(
          color: FeyaColors.primary,
          backgroundColor: FeyaColors.surface,
          onRefresh: () async {
            ref.invalidate(orderDetailProvider(orderId));
            await ref
                .read(orderDetailProvider(orderId).future)
                .catchError((_) => o);
          },
          child: _Body(order: o),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final o = order;
    final tracked = const {
      'COURIER_ASSIGNED',
      'PICKED_UP',
      'ON_THE_WAY',
      'READY_FOR_PICKUP',
      'PREPARING',
      'CONFIRMED',
      'PAID',
      'DELIVERED',
    }.contains(o.status);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(FeyaSpace.page, 8, FeyaSpace.page, 32),
      children: [
        Row(
          children: [
            StatusChip(o.status),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _paymentLabel(l, o.paymentStatus),
                style: t.bodySmall,
              ),
            ),
            Text(
              formatMoney(o.total),
              style: t.titleLarge?.copyWith(color: FeyaColors.primary),
            ),
          ],
        ),
        if (o.eta != null &&
            o.status != 'DELIVERED' &&
            o.status != 'CANCELLED' &&
            o.status != 'REFUNDED')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: FeyaColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${l.estimatedDelivery}: ${formatDateTime(o.eta!, context.localeName)}',
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (o.canPay)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FeyaButton(
              label: l.payNow,
              onPressed: () => context.push('/checkout/payment/${o.id}'),
            ),
          ),
        if (tracked && o.status != 'PAID' || o.status == 'ON_THE_WAY')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FeyaButton(
              label: l.trackOrder,
              icon: Icons.location_searching_rounded,
              kind: FeyaButtonKind.secondary,
              onPressed: () => context.push('/orders/${o.id}/tracking'),
            ),
          ),
        // ---- timeline -------------------------------------------------------------------------
        Text(l.orderStatus, style: t.titleLarge),
        const SizedBox(height: 12),
        _Timeline(order: o),
        const SizedBox(height: 20),
        // ---- items ----------------------------------------------------------------------------
        Text(l.orderItems, style: t.titleLarge),
        const SizedBox(height: 10),
        for (final item in o.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.all(10),
              onTap: () => context.push('/product/${item.productId}'),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 70,
                    child: NetImage(
                      item.imageUrl,
                      radius: BorderRadius.circular(FeyaRadius.sm),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: t.titleSmall),
                        Text(
                          '${item.variantLabel} × ${item.quantity}',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(formatMoney(item.lineTotal), style: t.titleSmall),
                ],
              ),
            ),
          ),
        if (o.status == 'DELIVERED')
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(l.leaveReviewHint, style: t.bodySmall),
          ),
        const SizedBox(height: 16),
        // ---- delivery -------------------------------------------------------------------------
        Text(l.delivery, style: t.titleLarge),
        const SizedBox(height: 10),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Info(Icons.place_outlined, o.addressLine),
              _Info(
                Icons.schedule_rounded,
                deliveryWhen(
                  context,
                  asap: o.asap,
                  date: o.deliveryDate,
                  start: o.slotStart,
                  end: o.slotEnd,
                ),
              ),
              _Info(
                Icons.person_outline_rounded,
                '${o.recipientName}, ${formatPhone(o.recipientPhone)}',
              ),
              if ((o.giftMessage ?? '').isNotEmpty)
                _Info(Icons.card_giftcard_rounded, o.giftMessage!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            children: [
              MoneyRow(l.subtotal, o.subtotal),
              if (o.discount > 0)
                MoneyRow(
                  o.promoCode == null
                      ? l.discount
                      : '${l.discount} (${o.promoCode})',
                  o.discount,
                  negative: true,
                ),
              MoneyRow(l.delivery, o.deliveryFee, freeLabel: l.free),
              if (o.giftWrapFee > 0) MoneyRow(l.giftWrap, o.giftWrapFee),
              const Divider(height: 20),
              MoneyRow(l.total, o.total, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FeyaButton(
          label: l.contactSupport,
          icon: Icons.support_agent_rounded,
          kind: FeyaButtonKind.secondary,
          onPressed: () => _support(context),
        ),
        if (o.canCancel) ...[
          const SizedBox(height: 10),
          FeyaButton(
            label: l.cancelOrder,
            kind: FeyaButtonKind.danger,
            onPressed: () => _cancel(context, ref),
          ),
        ],
      ],
    );
  }

  String _paymentLabel(dynamic l, String s) => switch (s) {
    'PAID' => l.paymentPaid as String,
    'FAILED' => l.paymentFailedShort as String,
    'REFUNDED' => l.paymentRefunded as String,
    _ => l.paymentUnpaid as String,
  };

  Future<void> _support(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: AppConfig.supportPhone);
    await launchUrl(uri);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l = context.l;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cancelOrderQuestion),
        content: Text(
          order.paymentStatus == 'PAID'
              ? l.cancelPaidOrderHint
              : l.cancelOrderHint,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.yesCancel,
              style: const TextStyle(color: FeyaColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(orderRepositoryProvider).cancel(order.id);
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersProvider);
      if (context.mounted) showSnack(context, l.orderCancelled);
    } catch (e) {
      if (context.mounted)
        showSnack(context, errorText(context, e), error: true);
    }
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: FeyaColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
}

/// Shows the real history of the order, with the remaining normal steps greyed out.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final reached = {for (final e in order.timeline) e.status: e.at};
    final terminal = {
      'CANCELLED',
      'PAYMENT_FAILED',
      'REFUNDED',
    }.intersection(reached.keys.toSet());
    final steps = <String>['PENDING_PAYMENT', ...orderFlow];
    final extra = [
      for (final s in ['PAYMENT_FAILED', 'CANCELLED', 'REFUNDED'])
        if (reached.containsKey(s)) s,
    ];
    final display = terminal.isEmpty
        ? steps
        : [...steps.where(reached.containsKey), ...extra];
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < display.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: reached.containsKey(display[i])
                              ? FeyaColors.gradient
                              : null,
                          color: reached.containsKey(display[i])
                              ? null
                              : FeyaColors.surface2,
                          border: reached.containsKey(display[i])
                              ? null
                              : Border.all(color: FeyaColors.border),
                        ),
                        child: reached.containsKey(display[i])
                            ? const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      if (i < display.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: reached.containsKey(display[i + 1])
                                ? FeyaColors.primary
                                : FeyaColors.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            orderStatusLabel(context, display[i]),
                            style: t.titleSmall?.copyWith(
                              color: reached.containsKey(display[i])
                                  ? FeyaColors.text
                                  : FeyaColors.textSecondary,
                            ),
                          ),
                        ),
                        if (reached.containsKey(display[i]))
                          Text(
                            formatDateTime(
                              reached[display[i]]!,
                              context.localeName,
                            ),
                            style: t.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
