import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/l10n_ext.dart';
import '../auth/auth_controller.dart';
import '../cart/cart_controller.dart';
import '../orders/order_providers.dart';
import 'checkout_providers.dart';

String _newKey() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final String _idempotencyKey = _newKey();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _gift = TextEditingController();
  final _notes = TextEditingController();
  bool _otherRecipient = false;
  bool _submitting = false;
  bool _showErrors = false;
  String? _date;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _name.text = user?.name ?? '';
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _gift.dispose();
    _notes.dispose();
    super.dispose();
  }

  CheckoutController get _ctl => ref.read(checkoutProvider.notifier);

  /// Chooses the default saved address once and resolves its delivery zone.
  void _syncAddress(List<SavedAddress> addresses, CheckoutState c) {
    if (addresses.isEmpty) return;
    SavedAddress? chosen;
    for (final a in addresses) {
      if (a.id == c.addressId) chosen = a;
    }
    if (chosen == null) {
      chosen = addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => addresses.first,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctl.update((s) => s.copyWith(addressId: chosen!.id));
      });
    }
    final zone = ref.watch(zoneForCityProvider(chosen.city));
    zone.whenData((z) {
      if (z.id != c.zoneId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            _ctl.setAddress(addressId: chosen!.id, address: null, zoneId: z.id);
        });
      }
    });
  }

  Future<void> _submit(Quote? quote) async {
    final l = context.l;
    final c = ref.read(checkoutProvider);
    setState(() {
      _showErrors = true;
      _submitError = null;
    });
    final phoneDigits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    final recipientOk =
        _name.text.trim().isNotEmpty && phoneDigits.length >= 10;
    if (!c.hasAddress || !c.hasDeliveryTime || !recipientOk || !c.acceptTerms) {
      showSnack(context, l.checkoutFillRequired, error: true);
      return;
    }
    if (quote == null || !quote.valid) {
      showSnack(context, l.errItemsUnavailable, error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .create(
            CreateOrderInput(
              lines: ref.read(cartProvider),
              promoCode: c.promoCode,
              addressId: c.addressId,
              recipientName: _name.text.trim(),
              recipientPhone: _phone.text.trim(),
              slot: c.slot,
              asap: c.asap,
              giftMessage: _gift.text,
              anonymousSender: _otherRecipient && c.anonymousSender,
              giftWrap: c.giftWrap,
              instructions: _notes.text,
            ),
            _idempotencyKey,
          );
      ref.read(cartProvider.notifier).clear();
      ref.read(checkoutProvider.notifier).reset();
      ref.invalidate(ordersProvider);
      if (mounted) context.go('/checkout/payment/${order.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code.startsWith('SLOT_') || e.code == 'ASAP_UNAVAILABLE') {
        final zone = ref.read(checkoutProvider).zoneId;
        if (zone != null) ref.invalidate(slotsProvider(zone));
        _ctl.update((s) => s.copyWith(slot: null, asap: false));
      }
      if (e.code == 'ITEMS_UNAVAILABLE' || e.code == 'OUT_OF_STOCK')
        ref.invalidate(quoteProvider);
      setState(() => _submitError = errorText(context, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final c = ref.watch(checkoutProvider);
    final lines = ref.watch(cartProvider);
    final addresses = ref.watch(addressesProvider);
    final quote = ref.watch(quoteProvider);

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.checkout)),
        body: EmptyView(
          icon: Icons.shopping_bag_outlined,
          title: l.cartEmpty,
          actionLabel: l.goToCatalog,
          onAction: () => context.go('/catalog'),
        ),
      );
    }
    addresses.whenData((list) => _syncAddress(list, c));

    return Scaffold(
      appBar: AppBar(title: Text(l.checkout)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          FeyaSpace.page,
          4,
          FeyaSpace.page,
          32,
        ),
        children: [
          // ---- 1. Address -------------------------------------------------------------------
          _StepTitle(index: 1, title: l.deliveryAddress),
          addresses.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: LoadingView(),
            ),
            error: (e, _) => ErrorView(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(addressesProvider),
            ),
            data: (list) => Column(
              children: [
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      highlight: a.id == c.addressId,
                      onTap: () => _ctl.update(
                        (s) => s.copyWith(addressId: a.id, address: null),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            a.id == c.addressId
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: FeyaColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.label ?? a.street, style: t.titleSmall),
                                Text(
                                  '${a.city}, ${a.oneLine}',
                                  style: t.bodySmall,
                                ),
                                if (!a.deliverable)
                                  Text(
                                    l.errNotDeliverable,
                                    style: t.bodySmall?.copyWith(
                                      color: FeyaColors.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l.editAddress,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () =>
                                context.push('/checkout/address?id=${a.id}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                FeyaButton(
                  label: l.addAddress,
                  icon: Icons.add_location_alt_outlined,
                  kind: FeyaButtonKind.secondary,
                  onPressed: () => context.push('/checkout/address'),
                ),
                if (_showErrors && !c.hasAddress)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.chooseAddress,
                      style: t.bodySmall?.copyWith(color: FeyaColors.error),
                    ),
                  ),
              ],
            ),
          ),

          // ---- 2. Delivery time -------------------------------------------------------------
          _StepTitle(index: 2, title: l.deliveryTime),
          if (c.zoneId == null)
            Panel(
              child: Text(
                l.chooseAddressFirst,
                style: t.bodyMedium?.copyWith(color: FeyaColors.textSecondary),
              ),
            )
          else
            _DeliveryTimePicker(
              zoneId: c.zoneId!,
              date: _date,
              onDate: (d) => setState(() => _date = d),
              showError: _showErrors && !c.hasDeliveryTime,
            ),

          // ---- 3. Recipient and gift --------------------------------------------------------
          _StepTitle(index: 3, title: l.recipientAndGift),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.deliverToSomeoneElse),
            value: _otherRecipient,
            onChanged: (v) => setState(() {
              _otherRecipient = v;
              final user = ref.read(authProvider).user;
              if (!v) {
                _name.text = user?.name ?? '';
                _phone.text = user?.phone ?? '';
                _ctl.update((s) => s.copyWith(anonymousSender: false));
              } else {
                _name.clear();
                _phone.clear();
              }
            }),
          ),
          TextField(
            controller: _name,
            enabled:
                _otherRecipient ||
                (ref.read(authProvider).user?.name ?? '').isEmpty,
            decoration: InputDecoration(
              labelText: l.recipientName,
              errorText: _showErrors && _name.text.trim().isEmpty
                  ? l.fieldRequired
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            enabled: _otherRecipient,
            decoration: InputDecoration(
              labelText: l.recipientPhone,
              errorText:
                  _showErrors &&
                      _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 10
                  ? l.errInvalidPhone
                  : null,
              helperText: _otherRecipient ? l.recipientPrivacy : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _gift,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: l.giftMessage,
              hintText: l.giftMessageHint,
            ),
          ),
          if (_otherRecipient)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.anonymousSender),
              subtitle: Text(l.anonymousSenderHint, style: t.bodySmall),
              value: c.anonymousSender,
              onChanged: (v) =>
                  _ctl.update((s) => s.copyWith(anonymousSender: v)),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.giftWrap),
            subtitle: Text(
              l.giftWrapHint(formatMoney(1500)),
              style: t.bodySmall,
            ),
            value: c.giftWrap,
            onChanged: (v) => _ctl.update((s) => s.copyWith(giftWrap: v)),
          ),
          TextField(
            controller: _notes,
            maxLines: 2,
            maxLength: 500,
            decoration: InputDecoration(labelText: l.deliveryInstructions),
          ),

          // ---- 4. Summary -------------------------------------------------------------------
          _StepTitle(index: 4, title: l.orderSummary),
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
                        for (final line in q.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${line.productName} · ${line.variantLabel} × ${line.quantity}',
                                    style: t.bodyMedium,
                                  ),
                                ),
                                Text(
                                  formatMoney(line.lineTotal),
                                  style: t.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 20),
                        MoneyRow(l.subtotal, q.subtotal),
                        if (q.discount > 0)
                          MoneyRow(l.discount, q.discount, negative: true),
                        MoneyRow(l.delivery, q.deliveryFee, freeLabel: l.free),
                        if (q.giftWrapFee > 0)
                          MoneyRow(l.giftWrap, q.giftWrapFee),
                        const Divider(height: 20),
                        MoneyRow(l.total, q.total, bold: true),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: c.acceptTerms,
            onChanged: (v) =>
                _ctl.update((s) => s.copyWith(acceptTerms: v ?? false)),
            title: Text.rich(
              TextSpan(
                style: t.bodyMedium,
                children: [
                  TextSpan(text: '${l.acceptTermsPrefix} '),
                  TextSpan(
                    text: l.termsOfService,
                    style: const TextStyle(
                      color: FeyaColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: ' ${l.and} '),
                  TextSpan(
                    text: l.privacyPolicy,
                    style: const TextStyle(
                      color: FeyaColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: () => context.push('/legal/terms'),
                child: Text(l.termsOfService),
              ),
              TextButton(
                onPressed: () => context.push('/legal/privacy'),
                child: Text(l.privacyPolicy),
              ),
            ],
          ),
          if (_showErrors && !c.acceptTerms)
            Text(
              l.acceptTermsRequired,
              style: t.bodySmall?.copyWith(color: FeyaColors.error),
            ),
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Panel(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: FeyaColors.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_submitError!, style: t.bodyMedium)),
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
            label: quote.value == null
                ? l.proceedToPayment
                : l.proceedToPaymentWithTotal(formatMoney(quote.value!.total)),
            loading: _submitting,
            onPressed: () => _submit(quote.value),
          ),
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.index, required this.title});
  final int index;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: FeyaColors.gradient,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    ),
  );
}

class _DeliveryTimePicker extends ConsumerWidget {
  const _DeliveryTimePicker({
    required this.zoneId,
    required this.date,
    required this.onDate,
    required this.showError,
  });
  final String zoneId;
  final String? date;
  final ValueChanged<String> onDate;
  final bool showError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final async = ref.watch(slotsProvider(zoneId));
    final c = ref.watch(checkoutProvider);
    return async.when(
      loading: () =>
          const Padding(padding: EdgeInsets.all(24), child: LoadingView()),
      error: (e, _) => ErrorView(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(slotsProvider(zoneId)),
      ),
      data: (s) {
        final dates = s.days.keys.toList();
        final selectedDate = date != null && s.days.containsKey(date)
            ? date!
            : (c.slot?.date ??
                  dates.firstWhere(
                    (d) => s.days[d]!.any((x) => x.available),
                    orElse: () => dates.first,
                  ));
        final slots = s.days[selectedDate] ?? const <Slot>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Panel(
              highlight: c.asap,
              onTap: s.asapAvailable
                  ? () => ref.read(checkoutProvider.notifier).chooseAsap()
                  : null,
              child: Opacity(
                opacity: s.asapAvailable ? 1 : 0.55,
                child: Row(
                  children: [
                    Icon(
                      c.asap
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: FeyaColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.asapDelivery, style: t.titleSmall),
                          Text(
                            s.asapAvailable
                                ? l.asapHint(
                                    s.asapEtaMinutes,
                                    formatMoney(s.asapFee),
                                  )
                                : l.asapUnavailable,
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.bolt_rounded, color: FeyaColors.warning),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(l.scheduledDelivery, style: t.titleSmall),
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = DateTime.parse(dates[i]);
                  final sel = dates[i] == selectedDate;
                  final any = s.days[dates[i]]!.any((x) => x.available);
                  return Semantics(
                    button: true,
                    selected: sel,
                    label: formatDateLong(d, context.localeName),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(FeyaRadius.sm),
                      onTap: () => onDate(dates[i]),
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          color: sel
                              ? FeyaColors.primary.withValues(alpha: 0.16)
                              : FeyaColors.surface,
                          borderRadius: BorderRadius.circular(FeyaRadius.sm),
                          border: Border.all(
                            color: sel ? FeyaColors.primary : FeyaColors.border,
                          ),
                        ),
                        child: Opacity(
                          opacity: any ? 1 : 0.45,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _weekday(d, context.localeName),
                                style: t.bodySmall,
                              ),
                              Text('${d.day}', style: t.titleMedium),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (slots.isEmpty)
              Text(
                l.noSlotsForDay,
                style: t.bodyMedium?.copyWith(color: FeyaColors.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in slots)
                    Tooltip(
                      message: slot.available
                          ? ''
                          : (slot.reason == 'FULL'
                                ? l.errSlotFull
                                : l.slotClosed),
                      child: ChoiceChip(
                        label: Text(
                          '${slot.start}–${slot.end}${slot.surcharge > 0 ? '  +${formatMoney(slot.surcharge)}' : ''}',
                        ),
                        selected:
                            !c.asap &&
                            c.slot?.templateId == slot.templateId &&
                            c.slot?.date == slot.date,
                        showCheckmark: false,
                        onSelected: slot.available
                            ? (_) => ref
                                  .read(checkoutProvider.notifier)
                                  .chooseSlot(
                                    SlotChoice(
                                      templateId: slot.templateId,
                                      date: slot.date,
                                      start: slot.start,
                                      end: slot.end,
                                      surcharge: slot.surcharge,
                                    ),
                                  )
                            : null,
                        side: BorderSide(
                          color:
                              !c.asap &&
                                  c.slot?.templateId == slot.templateId &&
                                  c.slot?.date == slot.date
                              ? FeyaColors.primary
                              : FeyaColors.border,
                        ),
                      ),
                    ),
                ],
              ),
            if (showError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.chooseDeliveryTime,
                  style: t.bodySmall?.copyWith(color: FeyaColors.error),
                ),
              ),
          ],
        );
      },
    );
  }

  String _weekday(DateTime d, String locale) {
    const ru = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const kk = ['Дс', 'Сс', 'Ср', 'Бс', 'Жм', 'Сб', 'Жк'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final list = locale == 'kk' ? kk : (locale == 'en' ? en : ru);
    return list[d.weekday - 1];
  }
}
