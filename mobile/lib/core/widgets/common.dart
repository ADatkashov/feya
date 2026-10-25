import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FeyaSpace.page,
        24,
        FeyaSpace.page,
        12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              semanticsLabel: title,
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(
                actionLabel ?? context.l.seeAll,
                style: const TextStyle(color: FeyaColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.avg,
    required this.count,
    this.small = false,
  });
  final double? avg;
  final int count;
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (avg == null || count == 0) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: FeyaColors.text,
      fontWeight: FontWeight.w600,
      fontSize: small ? 12 : 13,
    );
    return Semantics(
      label: '${avg!.toStringAsFixed(1)} / 5, $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: small ? 15 : 17,
              color: FeyaColors.warning,
            ),
            const SizedBox(width: 3),
            Text(avg!.toStringAsFixed(1), style: style),
            Text(
              ' ($count)',
              style: style?.copyWith(
                color: FeyaColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
    this.deleteAtMin = false,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// In the cart the minus button turns into a trash can at the minimum quantity.
  final bool deleteAtMin;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, VoidCallback tap, String label) =>
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: InkResponse(
            onTap: enabled ? tap : null,
            radius: 24,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 20,
                color: enabled
                    ? FeyaColors.text
                    : FeyaColors.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: FeyaColors.surface2,
        borderRadius: BorderRadius.circular(FeyaRadius.pill),
        border: Border.all(color: FeyaColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            deleteAtMin && value <= min
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            deleteAtMin || value > min,
            () => onChanged(value - 1),
            context.l.decrease,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          btn(
            Icons.add_rounded,
            value < max,
            () => onChanged(value + 1),
            context.l.increase,
          ),
        ],
      ),
    );
  }
}

/// Colour + label for an order status, shared by lists and detail screens.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  static Color colorOf(String s) => switch (s) {
    'DELIVERED' => FeyaColors.success,
    'CANCELLED' || 'PAYMENT_FAILED' => FeyaColors.error,
    'REFUNDED' => FeyaColors.warning,
    'PENDING_PAYMENT' || 'CREATED' => FeyaColors.warning,
    _ => FeyaColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final c = colorOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(FeyaRadius.pill),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        orderStatusLabel(context, status),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: c, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

String orderStatusLabel(BuildContext context, String status) {
  final l = context.l;
  return switch (status) {
    'CREATED' => l.statusCreated,
    'PENDING_PAYMENT' => l.statusPendingPayment,
    'PAID' => l.statusPaid,
    'CONFIRMED' => l.statusConfirmed,
    'PREPARING' => l.statusPreparing,
    'READY_FOR_PICKUP' => l.statusReady,
    'COURIER_ASSIGNED' => l.statusCourierAssigned,
    'PICKED_UP' => l.statusPickedUp,
    'ON_THE_WAY' => l.statusOnTheWay,
    'DELIVERED' => l.statusDelivered,
    'CANCELLED' => l.statusCancelled,
    'PAYMENT_FAILED' => l.statusPaymentFailed,
    'REFUNDED' => l.statusRefunded,
    _ => status,
  };
}

/// A bordered surface used for grouped content.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.highlight = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FeyaColors.surface,
        borderRadius: FeyaRadius.card,
        border: Border.all(
          color: highlight ? FeyaColors.primary : FeyaColors.border,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: FeyaRadius.card, onTap: onTap, child: box),
    );
  }
}

class MoneyRow extends StatelessWidget {
  const MoneyRow(
    this.label,
    this.amount, {
    super.key,
    this.bold = false,
    this.accent = false,
    this.negative = false,
    this.freeLabel,
  });
  final String label;
  final double amount;
  final bool bold;
  final bool accent;
  final bool negative;
  final String? freeLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final style = (bold ? t.titleMedium : t.bodyMedium)?.copyWith(
      color: accent
          ? FeyaColors.primary
          : (bold ? FeyaColors.text : FeyaColors.textSecondary),
    );
    final valueStyle = (bold ? t.titleMedium : t.bodyMedium)?.copyWith(
      color: negative
          ? FeyaColors.success
          : (accent ? FeyaColors.primary : FeyaColors.text),
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    final text = amount == 0 && freeLabel != null
        ? freeLabel!
        : (negative ? '−${formatMoney(amount)}' : formatMoney(amount));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(text, style: valueStyle),
        ],
      ),
    );
  }
}

String itemsLabel(BuildContext context, int n) => context.l.itemsCount(n);

/// Small helper to show product availability.
class UnavailableTag extends StatelessWidget {
  const UnavailableTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(FeyaRadius.pill),
    ),
    child: Text(
      context.l.outOfStock,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: FeyaColors.text),
    ),
  );
}

typedef VariantPick = void Function(Variant v);
