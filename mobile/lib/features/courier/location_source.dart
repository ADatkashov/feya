import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/courier_models.dart';

enum LocationAccess { granted, denied, serviceDisabled }

/// Where GPS fixes come from. A seam so tests (and the web build) never touch a platform plugin.
abstract class LocationSource {
  Future<LocationAccess> ensureAccess();

  /// Keeps emitting while the app is in the background where the platform allows it (Android foreground service,
  /// iOS background location). [notificationTitle]/[notificationText] label the Android foreground notification.
  Stream<GeoFix> positions({
    required String notificationTitle,
    required String notificationText,
  });
}

class GeolocatorSource implements LocationSource {
  const GeolocatorSource();

  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever
        ? LocationAccess.denied
        : LocationAccess.granted;
  }

  @override
  Stream<GeoFix> positions({
    required String notificationTitle,
    required String notificationText,
  }) {
    // distanceFilter 0: a stationary courier must keep refreshing, or the server drops the position as stale.
    final LocationSettings settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          enableWakeLock: true,
        ),
      ),
      TargetPlatform.iOS => AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      ),
      _ => const LocationSettings(accuracy: LocationAccuracy.high),
    };
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => GeoFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyM: p.accuracy.isFinite && p.accuracy >= 0 ? p.accuracy : null,
        at: p.timestamp,
      ),
    );
  }
}
