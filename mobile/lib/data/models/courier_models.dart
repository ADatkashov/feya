/// Courier-side view of the API (`/courier/**`). Kept apart from the customer models.
class CourierProfile {
  const CourierProfile({
    required this.userId,
    required this.vehicle,
    required this.onShift,
    required this.locationSharing,
  });
  final String userId;
  final String? vehicle;
  final bool onShift;
  final bool locationSharing;

  factory CourierProfile.fromJson(Map<String, dynamic> j) => CourierProfile(
    userId: j['userId'] as String,
    vehicle: j['vehicle'] as String?,
    onShift: j['onShift'] as bool? ?? false,
    locationSharing: j['locationSharing'] as bool? ?? false,
  );
}

class CourierOrder {
  const CourierOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.pickupName,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.recipientName,
    required this.recipientPhone,
    required this.instructions,
    required this.deliveryDate,
    required this.slotStart,
    required this.slotEnd,
    required this.asap,
    required this.eta,
  });

  final String id;
  final String number;
  final String status;
  final String? pickupName;
  final String? pickupAddress;
  final String deliveryAddress;

  /// Recipient details are sent only for orders already assigned to this courier.
  final String? recipientName;
  final String? recipientPhone;
  final String? instructions;
  final String? deliveryDate;

  /// `HH:mm` (seconds from the API are dropped).
  final String? slotStart;
  final String? slotEnd;
  final bool asap;
  final DateTime? eta;

  bool get isAssigned => status != 'READY_FOR_PICKUP';

  /// The courier's next action on the order, in delivery order; null when nothing is left to do.
  String? get nextStatus => switch (status) {
    'COURIER_ASSIGNED' => 'PICKED_UP',
    'PICKED_UP' => 'ON_THE_WAY',
    'ON_THE_WAY' => 'DELIVERED',
    _ => null,
  };

  /// True while the customer can see the courier on the map.
  bool get isCarrying => status == 'PICKED_UP' || status == 'ON_THE_WAY';

  static String? _hhmm(Object? v) {
    if (v is! String || v.length < 5) return null;
    return v.substring(0, 5);
  }

  factory CourierOrder.fromJson(Map<String, dynamic> j) => CourierOrder(
    id: j['id'] as String,
    number: j['number'] as String,
    status: j['status'] as String,
    pickupName: j['pickupName'] as String?,
    pickupAddress: j['pickupAddress'] as String?,
    deliveryAddress: j['deliveryAddress'] as String? ?? '',
    recipientName: j['recipientName'] as String?,
    recipientPhone: j['recipientPhone'] as String?,
    instructions: j['instructions'] as String?,
    deliveryDate: j['deliveryDate'] as String?,
    slotStart: _hhmm(j['slotStart']),
    slotEnd: _hhmm(j['slotEnd']),
    asap: j['asap'] as bool? ?? false,
    eta: j['eta'] == null ? null : DateTime.parse(j['eta'] as String).toUtc(),
  );
}

/// One GPS fix from the device.
class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    required this.at,
  });
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final DateTime at;
}
