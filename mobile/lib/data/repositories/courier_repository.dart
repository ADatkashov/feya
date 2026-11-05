import '../../core/network/api_client.dart';
import '../models/courier_models.dart';

Map<String, dynamic> _map(dynamic v) => v as Map<String, dynamic>;

/// `scope` values understood by `GET /courier/orders`.
class CourierScope {
  CourierScope._();
  static const mine = 'mine';
  static const available = 'available';
}

class CourierRepository {
  CourierRepository(this._api);
  final ApiClient _api;

  Future<CourierProfile> me() async =>
      CourierProfile.fromJson(_map(await _api.get('/courier/me')));

  Future<CourierProfile> setShift({
    required bool onShift,
    required bool locationSharing,
  }) async => CourierProfile.fromJson(
    _map(
      await _api.put(
        '/courier/shift',
        body: {'onShift': onShift, 'locationSharing': locationSharing},
      ),
    ),
  );

  Future<List<CourierOrder>> orders(String scope) async {
    final j = _map(
      await _api.get('/courier/orders', query: {'scope': scope, 'size': 50}),
    );
    return (j['content'] as List? ?? const [])
        .map((e) => CourierOrder.fromJson(_map(e)))
        .toList();
  }

  Future<CourierOrder> claim(String id) async =>
      CourierOrder.fromJson(_map(await _api.post('/courier/orders/$id/claim')));

  Future<CourierOrder> setStatus(String id, String status) async =>
      CourierOrder.fromJson(
        _map(
          await _api.post(
            '/courier/orders/$id/status',
            body: {'status': status},
          ),
        ),
      );

  /// `recordedAt` is left out on purpose: the server stamps it, so a skewed phone clock cannot get a fix rejected.
  Future<void> sendLocation(GeoFix fix, {String? orderId}) => _api.post(
    '/courier/location',
    body: {
      'latitude': fix.latitude,
      'longitude': fix.longitude,
      'accuracyM': ?fix.accuracyM,
      'orderId': ?orderId,
    },
  );
}
