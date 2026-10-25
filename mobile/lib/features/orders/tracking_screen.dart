import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_ext.dart';
import 'order_providers.dart';

/// Live order tracking. A map position is shown only when the courier app is reporting a fresh, permitted location.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final async = ref.watch(trackingProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text(l.tracking)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(trackingProvider(orderId)),
        ),
        data: (t) => _Content(tracking: t),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.tracking});
  final Tracking tracking;

  static const _steps = [
    'CONFIRMED',
    'PREPARING',
    'READY_FOR_PICKUP',
    'COURIER_ASSIGNED',
    'ON_THE_WAY',
    'DELIVERED',
  ];

  int _stepIndex(String status) {
    final normalized = status == 'PICKED_UP'
        ? 'ON_THE_WAY'
        : (status == 'PAID' ? 'CONFIRMED' : status);
    return _steps.indexOf(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final tr = tracking;
    final idx = _stepIndex(tr.status);
    final inactive = const {
      'CANCELLED',
      'PAYMENT_FAILED',
      'REFUNDED',
      'PENDING_PAYMENT',
      'CREATED',
    }.contains(tr.status);
    return ListView(
      padding: const EdgeInsets.all(FeyaSpace.page),
      children: [
        // ---- headline ------------------------------------------------------------------------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(tr.number, style: t.titleMedium)),
                  StatusChip(tr.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(_headline(l, tr.status), style: t.headlineSmall),
              if (tr.eta != null && !inactive && tr.status != 'DELIVERED') ...[
                const SizedBox(height: 6),
                Text(
                  '${l.estimatedDelivery}: ${formatDateTime(tr.eta!, context.localeName)}',
                  style: t.bodyMedium?.copyWith(
                    color: FeyaColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---- map / live location -------------------------------------------------------------
        _LocationCard(tracking: tr),
        const SizedBox(height: 14),
        // ---- courier -------------------------------------------------------------------------
        if (tr.courier != null)
          Panel(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: FeyaColors.gradient,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tr.courier!.name.isEmpty
                        ? 'F'
                        : tr.courier!.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.courier!.name, style: t.titleMedium),
                      Text(
                        [
                          l.yourCourier,
                          if (tr.courier!.vehicle != null) tr.courier!.vehicle!,
                        ].join(' · '),
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: l.callCourier,
                  child: Material(
                    color: FeyaColors.surface2,
                    shape: const CircleBorder(
                      side: BorderSide(color: FeyaColors.border),
                    ),
                    child: IconButton(
                      tooltip: l.callCourier,
                      icon: const Icon(
                        Icons.call_rounded,
                        color: FeyaColors.primary,
                      ),
                      onPressed: () => launchUrl(
                        Uri(scheme: 'tel', path: tr.courier!.phone),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (!inactive && tr.status != 'DELIVERED')
          Panel(
            child: Row(
              children: [
                const Icon(
                  Icons.two_wheeler_rounded,
                  color: FeyaColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.courierNotAssigned, style: t.bodyMedium),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        // ---- steps ---------------------------------------------------------------------------
        if (!inactive)
          Panel(
            child: Column(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          i < idx || tr.status == 'DELIVERED'
                              ? Icons.check_circle_rounded
                              : (i == idx
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked),
                          size: 22,
                          color: i <= idx
                              ? FeyaColors.primary
                              : FeyaColors.border,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          orderStatusLabel(context, _steps[i]),
                          style: t.titleSmall?.copyWith(
                            color: i <= idx
                                ? FeyaColors.text
                                : FeyaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        FeyaButton(
          label: l.viewOrder,
          kind: FeyaButtonKind.secondary,
          onPressed: () => context.push('/orders/${tr.orderId}'),
        ),
        const SizedBox(height: 10),
        FeyaButton(
          label: l.contactSupport,
          icon: Icons.support_agent_rounded,
          kind: FeyaButtonKind.ghost,
          onPressed: () =>
              launchUrl(Uri(scheme: 'tel', path: AppConfig.supportPhone)),
        ),
      ],
    );
  }

  String _headline(dynamic l, String status) => switch (status) {
    'PENDING_PAYMENT' => l.statusPendingPayment as String,
    'PAID' || 'CONFIRMED' => l.trackConfirmed as String,
    'PREPARING' => l.trackPreparing as String,
    'READY_FOR_PICKUP' => l.trackReady as String,
    'COURIER_ASSIGNED' => l.trackCourierAssigned as String,
    'PICKED_UP' || 'ON_THE_WAY' => l.trackOnTheWay as String,
    'DELIVERED' => l.trackDelivered as String,
    'CANCELLED' => l.statusCancelled as String,
    'REFUNDED' => l.statusRefunded as String,
    _ => l.statusPaymentFailed as String,
  };
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.tracking});
  final Tracking tracking;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final loc = tracking.location;
    final live = tracking.liveTracking && loc != null;
    final delivered = tracking.status == 'DELIVERED';
    return Container(
      height: 168,
      decoration: BoxDecoration(
        borderRadius: FeyaRadius.card,
        border: Border.all(color: FeyaColors.border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14151F), Color(0xFF1C1424)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (live ? FeyaColors.primary : FeyaColors.surface2)
                          .withValues(alpha: live ? 0.2 : 1),
                      border: Border.all(
                        color: live ? FeyaColors.primary : FeyaColors.border,
                      ),
                    ),
                    child: Icon(
                      delivered
                          ? Icons.home_rounded
                          : (live
                                ? Icons.two_wheeler_rounded
                                : Icons.location_off_outlined),
                      color: live
                          ? FeyaColors.primary
                          : FeyaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    live
                        ? l.liveLocationOn
                        : (delivered
                              ? l.trackDelivered
                              : l.liveLocationUnavailable),
                    style: t.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    live
                        ? l.locationUpdated(formatTime(loc.updatedAt))
                        : l.liveLocationUnavailableHint,
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (live)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          AppConfig.mapLinkTemplate
                              .replaceAll('{lat}', '${loc.latitude}')
                              .replaceAll('{lng}', '${loc.longitude}'),
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(l.openInMaps),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = FeyaColors.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
