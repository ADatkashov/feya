import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_ext.dart';
import 'cart_controller.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _promo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _promo.text = ref.read(checkoutProvider).promoCode ?? '';
  }

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final lines = ref.watch(cartProvider);
    final quote = ref.watch(quoteProvider);

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navCart)),
        body: EmptyView(
          icon: Icons.shopping_bag_outlined,
          title: l.cartEmpty,
          message: l.cartEmptyHint,
          actionLabel: l.goToCatalog,
          onAction: () => context.go('/catalog'),
        ),
      );
    }

    final q = quote.value;
    final byVariant = {
      for (final ql in q?.lines ?? const <QuoteLine>[]) ql.variantId: ql,
    };
    final hasIssues = q != null && !q.valid;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navCart),
        actions: [
          TextButton(
            onPressed: () => ref.read(cartProvider.notifier).clear(),
            child: Text(
              l.clear,
              style: const TextStyle(color: FeyaColors.textSecondary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          FeyaSpace.page,
          8,
          FeyaSpace.page,
          24,
        ),
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CartLineTile(
                line: line,
                quoteLine: byVariant[line.variantId],
              ),
            ),
          if (hasIssues)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: FeyaColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.cartHasIssues,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        for (final ql in q.lines.where(
                          (x) => x.issue != null,
                        )) {
                          if (ql.maxQuantity > 0 &&
                              ql.issue == 'INSUFFICIENT_STOCK') {
                            ref
                                .read(cartProvider.notifier)
                                .setQuantity(ql.variantId, ql.maxQuantity);
                          } else {
                            ref
                                .read(cartProvider.notifier)
                                .remove(ql.variantId);
                          }
                        }
                      },
                      child: Text(l.fixCart),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          _PromoField(controller: _promo, quote: q),
          const SizedBox(height: 16),
          Panel(
            child: quote.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                error: e,
                compact: true,
                onRetry: () => ref.invalidate(quoteProvider),
              ),
              data: (q) => q == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        MoneyRow(l.subtotal, q.subtotal),
                        if (q.discount > 0)
                          MoneyRow(l.discount, q.discount, negative: true),
                        MoneyRow(l.delivery, q.deliveryFee, freeLabel: l.free),
                        const Divider(height: 20),
                        MoneyRow(l.total, q.total, bold: true),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l.deliveryDependsOnAddress,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FeyaSpace.page,
            8,
            FeyaSpace.page,
            12,
          ),
          child: FeyaButton(
            label: q == null
                ? l.checkout
                : l.checkoutWithTotal(formatMoney(q.total)),
            onPressed: q != null && q.valid
                ? () => context.push('/checkout')
                : null,
          ),
        ),
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line, required this.quoteLine});
  final CartLine line;
  final QuoteLine? quoteLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final price = quoteLine?.unitPrice ?? line.unitPrice;
    final issue = quoteLine?.issue;
    final maxQty = quoteLine != null && quoteLine!.maxQuantity > 0
        ? quoteLine!.maxQuantity
        : kMaxQuantityPerLine;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 104,
            child: NetImage(
              quoteLine?.imageUrl ?? line.imageUrl,
              radius: BorderRadius.circular(FeyaRadius.sm),
              semanticLabel: quoteLine?.productName ?? line.productName,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quoteLine?.productName ?? line.productName,
                  style: t.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  quoteLine?.variantLabel ?? line.variantLabel,
                  style: t.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  formatMoney(price * line.quantity),
                  style: t.titleMedium?.copyWith(color: FeyaColors.primary),
                ),
                if (issue != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      issue == 'INSUFFICIENT_STOCK'
                          ? l.onlyLeft(quoteLine!.maxQuantity)
                          : l.unavailable,
                      style: t.bodySmall?.copyWith(
                        color: FeyaColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: QuantityStepper(
                    deleteAtMin: true,
                    value: line.quantity,
                    max: maxQty.clamp(1, kMaxQuantityPerLine),
                    onChanged: (n) => ref
                        .read(cartProvider.notifier)
                        .setQuantity(line.variantId, n),
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

class _PromoField extends ConsumerWidget {
  const _PromoField({required this.controller, required this.quote});
  final TextEditingController controller;
  final Quote? quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final promo = quote?.promo;
    String? status;
    Color? color;
    if (promo != null) {
      if (promo.applied) {
        status = l.promoApplied(formatMoney(promo.discount));
        color = FeyaColors.success;
      } else {
        status = switch (promo.error) {
          'PROMO_NOT_FOUND' => l.promoNotFound,
          'PROMO_EXPIRED' => l.promoExpired,
          'PROMO_MIN_ORDER' => l.promoMinOrder,
          _ => l.promoUsed,
        };
        color = FeyaColors.error;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: l.promoCode,
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
                onSubmitted: (v) =>
                    ref.read(checkoutProvider.notifier).setPromo(v),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 54,
              child: FeyaButton(
                label: l.apply,
                expand: false,
                kind: FeyaButtonKind.secondary,
                onPressed: () => ref
                    .read(checkoutProvider.notifier)
                    .setPromo(controller.text),
              ),
            ),
          ],
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color),
            ),
          ),
      ],
    );
  }
}
