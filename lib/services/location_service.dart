import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationSnapshot {
  final double latitude;
  final double longitude;
  final String? address;

  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

/// Captures the device's current GPS position and resolves it to a
/// human-readable address via the platform geocoder.
class LocationService {
  Future<LocationSnapshot?> captureCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = [p.locality, p.administrativeArea]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
          if (address.isEmpty) address = p.name;
        }
      } catch (_) {
        // Geocoder unavailable (offline / no provider) — fall back to
        // raw coordinates only, per the spec's error-handling requirement.
        address = null;
      }

      return LocationSnapshot(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );
    } catch (_) {
      // GPS unavailable / timed out.
      return null;
    }
  }
}
