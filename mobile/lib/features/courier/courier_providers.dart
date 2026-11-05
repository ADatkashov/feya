import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/courier_models.dart';
import '../../data/repositories/courier_repository.dart';
import '../auth/auth_controller.dart';
import 'location_source.dart';

/// How often the order lists refresh. Overridden in tests.
final courierPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

/// Minimum gap between two position uploads. Must stay well under the server's freshness window (5 min).
final courierLocationIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

final locationSourceProvider = Provider<LocationSource>(
  (ref) => const GeolocatorSource(),
);

// ---- shift ---------------------------------------------------------------------------------------

class CourierProfileController extends AsyncNotifier<CourierProfile> {
  @override
  Future<CourierProfile> build() {
    // A different account must never see the previous courier's state.
    ref.watch(authProvider.select((a) => a.user?.id));
    return ref.watch(courierRepositoryProvider).me();
  }

  /// Throws on failure so the caller can show the error; the displayed state stays unchanged in that case.
  Future<void> setShift({required bool onShift, bool? locationSharing}) async {
    final current = state.value;
    final sharing =
        onShift && (locationSharing ?? current?.locationSharing ?? false);
    final updated = await ref
        .read(courierRepositoryProvider)
        .setShift(onShift: onShift, locationSharing: sharing);
    state = AsyncData(updated);
  }
}

final courierProfileProvider =
    AsyncNotifierProvider<CourierProfileController, CourierProfile>(
      CourierProfileController.new,
    );

// ---- orders --------------------------------------------------------------------------------------

/// Order list for [CourierScope.mine] or [CourierScope.available], refreshed on a timer while watched.
final courierOrdersProvider = StreamProvider.autoDispose
    .family<List<CourierOrder>, String>((ref, scope) {
      final repo = ref.watch(courierRepositoryProvider);
      final interval = ref.watch(courierPollIntervalProvider);
      final controller = StreamController<List<CourierOrder>>();
      var busy = false;
      var disposed = false;

      Future<void> poll() async {
        if (busy || disposed) return;
        busy = true;
        try {
          final list = await repo.orders(scope);
          if (!disposed) controller.add(list);
        } catch (e, st) {
          // Keep the last good list on screen; only the first load surfaces an error.
          if (!disposed && !controller.isClosed) controller.addError(e, st);
        } finally {
          busy = false;
        }
      }

      Timer? timer;
      void start() {
        timer?.cancel();
        timer = Timer.periodic(interval, (_) => poll());
      }

      poll();
      start();
      // Stop polling the moment nobody watches the list (screen left, app backgrounded); resume with a fresh load.
      ref.onCancel(() => timer?.cancel());
      ref.onResume(() {
        poll();
        start();
      });
      ref.onDispose(() {
        disposed = true;
        timer?.cancel();
        controller.close();
      });
      return controller.stream;
    });

/// Actions on orders. Each one refreshes both lists afterwards; errors propagate to the caller.
class CourierActions {
  CourierActions(this._ref);
  final Ref _ref;

  Future<void> claim(String id) async {
    await _ref.read(courierRepositoryProvider).claim(id);
    _refresh();
  }

  Future<void> setStatus(String id, String status) async {
    await _ref.read(courierRepositoryProvider).setStatus(id, status);
    _refresh();
  }

  void _refresh() {
    _ref.invalidate(courierOrdersProvider(CourierScope.mine));
    _ref.invalidate(courierOrdersProvider(CourierScope.available));
  }
}

final courierActionsProvider = Provider((ref) => CourierActions(ref));

// ---- live location -------------------------------------------------------------------------------

enum SharingStatus { off, starting, active, permissionDenied, serviceDisabled }

/// Uploads the device position while the courier is on shift with sharing enabled. Lives for the whole session
/// (not tied to a screen), so leaving the courier screen does not stop sharing; going off shift or signing out does.
class CourierLocationController extends Notifier<SharingStatus> {
  StreamSubscription<GeoFix>? _sub;
  DateTime? _lastSent;
  String? _activeOrderId;
  bool _sending = false;
  String _title = 'FEYA';
  String _text = '';
  bool _wanted = false;

  @override
  SharingStatus build() {
    ref.listen(courierProfileProvider, (_, next) => _sync(next.value));
    ref.listen(authProvider.select((a) => a.isAuthenticated), (_, signedIn) {
      if (!signedIn) _stop();
    });
    ref.onDispose(_release);
    // Pick up a shift that was already running on the server (app restarted mid-shift).
    Future.microtask(() => _sync(ref.read(courierProfileProvider).value));
    return SharingStatus.off;
  }

  /// Localized labels for the Android foreground-service notification; applied the next time sharing starts.
  void configure({required String title, required String text}) {
    _title = title;
    _text = text;
  }

  /// The order the courier is carrying right now, attached to uploads so the customer's map follows it.
  void setActiveOrder(String? id) => _activeOrderId = id;

  void _sync(CourierProfile? p) {
    final wanted = p != null && p.onShift && p.locationSharing;
    if (wanted == _wanted && (wanted == (_sub != null))) return;
    _wanted = wanted;
    if (wanted) {
      _start();
    } else {
      _stop();
    }
  }

  Future<void> _start() async {
    state = SharingStatus.starting;
    final source = ref.read(locationSourceProvider);
    final LocationAccess access;
    try {
      access = await source.ensureAccess();
    } catch (_) {
      if (_wanted) state = SharingStatus.permissionDenied;
      return;
    }
    if (!_wanted) return; // switched off while the permission dialog was open
    if (access != LocationAccess.granted) {
      state = access == LocationAccess.serviceDisabled
          ? SharingStatus.serviceDisabled
          : SharingStatus.permissionDenied;
      return;
    }
    await _sub?.cancel();
    _sub = source
        .positions(notificationTitle: _title, notificationText: _text)
        .listen(_onFix, onError: (_) => state = SharingStatus.serviceDisabled);
    state = SharingStatus.active;
  }

  /// Drops the GPS subscription. Safe inside `onDispose`: it does not touch provider state.
  void _release() {
    _wanted = false;
    _sub?.cancel();
    _sub = null;
    _lastSent = null;
  }

  void _stop() {
    _release();
    if (state != SharingStatus.off) state = SharingStatus.off;
  }

  Future<void> _onFix(GeoFix fix) async {
    final now = DateTime.now();
    final gap = ref.read(courierLocationIntervalProvider);
    if (_sending || (_lastSent != null && now.difference(_lastSent!) < gap)) {
      return;
    }
    _sending = true;
    _lastSent = now;
    try {
      await ref
          .read(courierRepositoryProvider)
          .sendLocation(fix, orderId: _activeOrderId);
    } catch (_) {
      // A dropped upload is not an error for the courier: the next fix replaces it.
    } finally {
      _sending = false;
    }
  }
}

final courierLocationProvider =
    NotifierProvider<CourierLocationController, SharingStatus>(
      CourierLocationController.new,
    );
