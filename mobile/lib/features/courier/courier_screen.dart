import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/courier_models.dart';
import '../../data/repositories/courier_repository.dart';
import '../../l10n/l10n_ext.dart';
import '../auth/auth_controller.dart';
import 'courier_providers.dart';

/// Courier mode: shift, orders ready to claim, orders being carried, and live location sharing.
class CourierScreen extends ConsumerStatefulWidget {
  const CourierScreen({super.key});

  @override
  ConsumerState<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends ConsumerState<CourierScreen> {
  String _scope = CourierScope.mine;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final user = ref.watch(authProvider).user;
    if (user != null && !user.roles.contains('COURIER')) {
      return Scaffold(
        appBar: AppBar(title: Text(l.courierTitle)),
        body: EmptyView(
          icon: Icons.lock_outline_rounded,
          title: l.courierNoAccess,
        ),
      );
    }

    // Keep the location controller alive and tell it which order to attach to uploads.
    ref.watch(courierLocationProvider);
    ref
        .read(courierLocationProvider.notifier)
        .configure(
          title: l.courierNotificationTitle,
          text: l.courierNotificationText,
        );
    ref.listen(courierOrdersProvider(CourierScope.mine), (_, next) {
      final orders = next.value;
      if (orders == null) return;
      final carrying = orders.where((o) => o.isCarrying);
      ref
          .read(courierLocationProvider.notifier)
          .setActiveOrder(carrying.isEmpty ? null : carrying.first.id);
    });

    final profile = ref.watch(courierProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.courierTitle)),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(courierProfileProvider),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(courierOrdersProvider(_scope));
            await ref.read(courierOrdersProvider(_scope).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(FeyaSpace.page),
            children: [
              _ShiftCard(profile: p),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: CourierScope.mine,
                    label: Text(l.courierTabMine),
                    icon: const Icon(Icons.two_wheeler_rounded),
                  ),
                  ButtonSegment(
                    value: CourierScope.available,
                    label: Text(l.courierTabAvailable),
                    icon: const Icon(Icons.inventory_2_outlined),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
              const SizedBox(height: 16),
              _OrderList(scope: _scope, onShift: p.onShift),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------
// Shift
// ------------------------------------------------------------------------------------------------

class _ShiftCard extends ConsumerStatefulWidget {
  const _ShiftCard({required this.profile});
  final CourierProfile profile;

  @override
  ConsumerState<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends ConsumerState<_ShiftCard> {
  bool _busy = false;

  Future<void> _apply({required bool onShift, bool? sharing}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(courierProfileProvider.notifier)
          .setShift(onShift: onShift, locationSharing: sharing);
      ref.invalidate(courierOrdersProvider(CourierScope.available));
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final p = widget.profile;
    final sharing = ref.watch(courierLocationProvider);
    final warning = switch (sharing) {
      SharingStatus.permissionDenied => l.courierLocationDenied,
      SharingStatus.serviceDisabled => l.courierLocationServiceOff,
      _ => null,
    };
    return Panel(
      highlight: p.onShift,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SwitchRow(
            title: l.courierOnShift,
            subtitle: p.onShift ? l.courierShiftOn : l.courierShiftHint,
            big: true,
            value: p.onShift,
            onChanged: _busy ? null : (v) => _apply(onShift: v),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _SwitchRow(
            title: l.courierShareLocation,
            subtitle: sharing == SharingStatus.active
                ? l.courierLocationActive
                : l.courierShareHint,
            value: p.locationSharing,
            onChanged: _busy || !p.onShift
                ? null
                : (v) => _apply(onShift: true, sharing: v),
          ),
          if (warning != null && p.locationSharing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off_outlined,
                    size: 18,
                    color: FeyaColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: t.bodySmall?.copyWith(color: FeyaColors.warning),
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.big = false,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: big ? t.titleMedium : t.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: t.bodySmall?.copyWith(color: FeyaColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------
// Orders
// ------------------------------------------------------------------------------------------------

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.scope, required this.onShift});
  final String scope;
  final bool onShift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final async = ref.watch(courierOrdersProvider(scope));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: LoadingView(),
      ),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(courierOrdersProvider(scope)),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                scope == CourierScope.mine
                    ? l.courierNoMine
                    : (onShift ? l.courierNoAvailable : l.courierShiftHint),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: FeyaColors.textSecondary),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final o in orders) ...[
              _OrderCard(order: o, onShift: onShift),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.order, required this.onShift});
  final CourierOrder order;
  final bool onShift;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String message) async {
    final l = context.l;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.courierConfirm),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _advance(String next) async {
    final l = context.l;
    if (next == 'DELIVERED' && !await _confirm(l.courierDeliveredConfirm)) {
      return;
    }
    await _run(
      () => ref.read(courierActionsProvider).setStatus(widget.order.id, next),
    );
  }

  Future<void> _release() async {
    if (!await _confirm(context.l.courierReleaseConfirm)) return;
    await _run(
      () => ref
          .read(courierActionsProvider)
          .setStatus(widget.order.id, 'READY_FOR_PICKUP'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final o = widget.order;
    final next = o.nextStatus;
    final slot = o.asap
        ? l.courierAsap
        : [
            if (o.slotStart != null && o.slotEnd != null)
              '${o.slotStart}–${o.slotEnd}',
          ].join();
    return Panel(
      highlight: o.isCarrying,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(o.number, style: t.titleMedium)),
              StatusChip(o.status),
            ],
          ),
          if (slot.isNotEmpty || o.eta != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (slot.isNotEmpty) slot,
                if (o.eta != null)
                  '${l.estimatedDelivery}: ${formatTime(o.eta!)}',
              ].join(' · '),
              style: t.bodySmall?.copyWith(color: FeyaColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          _Line(
            icon: Icons.storefront_outlined,
            label: l.courierPickup,
            value: [?o.pickupName, ?o.pickupAddress].join(', '),
          ),
          const SizedBox(height: 8),
          _Line(
            icon: Icons.place_outlined,
            label: l.courierDeliverTo,
            value: o.deliveryAddress,
            onNavigate: () => _openRoute(o.deliveryAddress),
          ),
          if (o.recipientName != null || o.recipientPhone != null) ...[
            const SizedBox(height: 8),
            _Line(
              icon: Icons.person_outline_rounded,
              label: l.courierRecipient,
              value: [?o.recipientName, ?o.recipientPhone].join(' · '),
              onCall: o.recipientPhone == null
                  ? null
                  : () => launchUrl(Uri(scheme: 'tel', path: o.recipientPhone)),
            ),
          ],
          if (o.instructions != null && o.instructions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Line(
              icon: Icons.sticky_note_2_outlined,
              label: l.courierInstructions,
              value: o.instructions!,
            ),
          ],
          const SizedBox(height: 14),
          if (!o.isAssigned)
            FeyaButton(
              label: l.courierClaim,
              icon: Icons.add_task_rounded,
              loading: _busy,
              onPressed: widget.onShift && !_busy
                  ? () =>
                        _run(() => ref.read(courierActionsProvider).claim(o.id))
                  : null,
            )
          else ...[
            if (next != null)
              FeyaButton(
                label: switch (next) {
                  'PICKED_UP' => l.courierPickedUp,
                  'ON_THE_WAY' => l.courierOnTheWay,
                  _ => l.courierMarkDelivered,
                },
                icon: next == 'DELIVERED'
                    ? Icons.check_circle_outline_rounded
                    : Icons.arrow_forward_rounded,
                loading: _busy,
                onPressed: _busy ? null : () => _advance(next),
              ),
            if (o.status == 'COURIER_ASSIGNED') ...[
              const SizedBox(height: 8),
              FeyaButton(
                label: l.courierRelease,
                kind: FeyaButtonKind.ghost,
                onPressed: _busy ? null : _release,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _openRoute(String address) => launchUrl(
    Uri.parse(
      AppConfig.mapSearchTemplate.replaceAll(
        '{query}',
        Uri.encodeComponent(address),
      ),
    ),
    mode: LaunchMode.externalApplication,
  );
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.onNavigate,
    this.onCall,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onNavigate;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: FeyaColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.labelSmall?.copyWith(color: FeyaColors.textSecondary),
              ),
              Text(value, style: t.bodyMedium),
            ],
          ),
        ),
        if (onNavigate != null)
          IconButton(
            tooltip: l.courierNavigate,
            icon: const Icon(Icons.navigation_outlined),
            onPressed: onNavigate,
          ),
        if (onCall != null)
          IconButton(
            tooltip: l.courierCall,
            icon: const Icon(Icons.call_rounded, color: FeyaColors.primary),
            onPressed: onCall,
          ),
      ],
    );
  }
}
