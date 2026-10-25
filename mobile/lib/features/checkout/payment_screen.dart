import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_ext.dart';
import '../orders/order_providers.dart';
import 'checkout_providers.dart';

enum _Phase { choose, processing, waiting, success, failed }

/// Payment step. The order is only shown as paid after the backend (not this client) reports the payment succeeded.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  _Phase _phase = _Phase.choose;
  String? _method;
  String? _error;
  PaymentInfo? _payment;
  Timer? _poll;
  int _polls = 0;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pay({required bool sandboxSuccess}) async {
    final methods = ref.read(paymentMethodsProvider).value;
    final method =
        _method ??
        (methods?.methods.isNotEmpty == true ? methods!.methods.first : null);
    if (method == null) return;
    setState(() {
      _phase = _Phase.processing;
      _error = null;
    });
    try {
      final repo = ref.read(paymentRepositoryProvider);
      var payment = await repo.start(widget.orderId, method);
      if (payment.sandbox) {
        payment = await repo.sandboxComplete(
          payment.id,
          success: sandboxSuccess,
        );
        _finish(payment);
      } else if (payment.checkoutUrl != null) {
        _payment = payment;
        await launchUrl(
          Uri.parse(payment.checkoutUrl!),
          mode: LaunchMode.externalApplication,
        );
        setState(() => _phase = _Phase.waiting);
        _startPolling(payment.id);
      } else {
        _payment = payment;
        setState(() => _phase = _Phase.waiting);
        _startPolling(payment.id);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.choose;
        _error = errorText(context, e);
      });
    }
  }

  void _startPolling(String paymentId) {
    _poll?.cancel();
    _polls = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      _polls++;
      try {
        final p = await ref.read(paymentRepositoryProvider).get(paymentId);
        if (p.status != 'PENDING') {
          t.cancel();
          if (mounted) _finish(p);
        }
      } catch (_) {
        // keep polling; transient network errors are expected on mobile
      }
      if (_polls > 100) t.cancel();
    });
  }

  void _finish(PaymentInfo p) {
    ref.invalidate(ordersProvider);
    ref.invalidate(orderDetailProvider(widget.orderId));
    setState(() {
      _payment = p;
      _phase = p.status == 'SUCCEEDED' ? _Phase.success : _Phase.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final order = ref.watch(orderDetailProvider(widget.orderId));
    final methods = ref.watch(paymentMethodsProvider);

    return PopScope(
      canPop: _phase != _Phase.processing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.payment),
          automaticallyImplyLeading: false,
          leading: _phase == _Phase.choose
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l.close,
                  onPressed: () => context.go('/orders/${widget.orderId}'),
                )
              : null,
        ),
        body: order.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
          ),
          data: (o) {
            if (_phase == _Phase.success ||
                (_phase == _Phase.choose && _alreadyPaid(o)))
              return _success(context, o);
            if (_phase == _Phase.failed) return _failed(context, o);
            if (_phase == _Phase.processing || _phase == _Phase.waiting)
              return _processing(context, o);
            return methods.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(paymentMethodsProvider),
              ),
              data: (m) => _choose(context, o, m),
            );
          },
        ),
      ),
    );
  }

  bool _alreadyPaid(OrderDetail o) => !o.canPay && o.paymentStatus == 'PAID';

  Widget _choose(BuildContext context, OrderDetail o, PaymentMethods m) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    if (!m.configured || m.methods.isEmpty) {
      return EmptyView(
        icon: Icons.payments_outlined,
        title: l.paymentsUnavailable,
        message: l.paymentsUnavailableHint,
        actionLabel: l.viewOrder,
        onAction: () => context.go('/orders/${o.id}'),
      );
    }
    final selected = _method ?? m.methods.first;
    return ListView(
      padding: const EdgeInsets.all(FeyaSpace.page),
      children: [
        Panel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.orderNumber(o.number), style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(l.orderAwaitsPayment, style: t.bodySmall),
                  ],
                ),
              ),
              Text(
                formatMoney(o.total),
                style: t.headlineSmall?.copyWith(color: FeyaColors.primary),
              ),
            ],
          ),
        ),
        if (m.sandbox)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FeyaColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(FeyaRadius.sm),
                border: Border.all(
                  color: FeyaColors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, color: FeyaColors.warning),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.sandboxBanner, style: t.bodyMedium)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(l.paymentMethod, style: t.titleMedium),
        const SizedBox(height: 10),
        for (final method in m.methods)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              highlight: selected == method,
              onTap: () => setState(() => _method = method),
              child: Row(
                children: [
                  Icon(_methodIcon(method), color: FeyaColors.text),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(_methodLabel(l, method), style: t.titleSmall),
                  ),
                  Icon(
                    selected == method
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: FeyaColors.primary,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: FeyaColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l.securePaymentNote, style: t.bodySmall)),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: t.bodyMedium?.copyWith(color: FeyaColors.error),
            ),
          ),
        const SizedBox(height: 20),
        FeyaButton(
          label: l.payAmount(formatMoney(o.total)),
          onPressed: () => _pay(sandboxSuccess: true),
        ),
        if (m.sandbox) ...[
          const SizedBox(height: 10),
          FeyaButton(
            label: l.simulateDecline,
            kind: FeyaButtonKind.danger,
            onPressed: () => _pay(sandboxSuccess: false),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go('/orders/${o.id}'),
          child: Text(l.payLater),
        ),
      ],
    );
  }

  Widget _processing(BuildContext context, OrderDetail o) {
    final l = context.l;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _phase == _Phase.waiting
                  ? l.waitingForPayment
                  : l.processingPayment,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (_phase == _Phase.waiting) ...[
              const SizedBox(height: 8),
              Text(
                l.waitingForPaymentHint,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FeyaButton(
                label: l.checkStatus,
                expand: false,
                kind: FeyaButtonKind.secondary,
                onPressed: () async {
                  final p = _payment;
                  if (p == null) return;
                  final fresh = await ref
                      .read(paymentRepositoryProvider)
                      .get(p.id);
                  if (fresh.status != 'PENDING' && mounted) _finish(fresh);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _success(BuildContext context, OrderDetail o) {
    final l = context.l;
    return EmptyView(
      icon: Icons.check_circle_rounded,
      title: l.paymentSuccessTitle,
      message: l.paymentSuccessMessage(o.number),
      actionLabel: l.trackOrder,
      onAction: () => context.go('/orders/${o.id}'),
    );
  }

  Widget _failed(BuildContext context, OrderDetail o) {
    final l = context.l;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_rounded, size: 72, color: FeyaColors.error),
            const SizedBox(height: 16),
            Text(
              l.paymentFailedTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l.paymentFailedMessage,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: FeyaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FeyaButton(
              label: l.tryAgain,
              onPressed: () => setState(() => _phase = _Phase.choose),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/orders/${o.id}'),
              child: Text(l.viewOrder),
            ),
          ],
        ),
      ),
    );
  }

  IconData _methodIcon(String m) => switch (m) {
    'APPLE_PAY' => Icons.apple,
    'GOOGLE_PAY' => Icons.account_balance_wallet_outlined,
    _ => Icons.credit_card_rounded,
  };

  String _methodLabel(dynamic l, String m) => switch (m) {
    'APPLE_PAY' => 'Apple Pay',
    'GOOGLE_PAY' => 'Google Pay',
    'CARD' => l.methodCard as String,
    _ => m,
  };
}
