import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Custom coordinate model for Dashly to replace latlong2 dependency.
class DashlyLatLng {
  final double latitude;
  final double longitude;

  const DashlyLatLng(this.latitude, this.longitude);

  /// Helper to convert Geolocator Position to DashlyLatLng.
  factory DashlyLatLng.fromPosition(Position position) {
    return DashlyLatLng(position.latitude, position.longitude);
  }

  /// Calculates the distance to another coordinate using the Haversine Formula.
  /// Result is returned in meters.
  double distanceTo(DashlyLatLng other) {
    const double earthRadius = 6371000; // in meters (mean radius)
    
    final double phi1 = latitude * pi / 180;
    final double phi2 = other.latitude * pi / 180;
    
    final double deltaPhi = (other.latitude - latitude) * pi / 180;
    final double deltaLambda = (other.longitude - longitude) * pi / 180;

    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) *
        sin(deltaLambda / 2) * sin(deltaLambda / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashlyLatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'DashlyLatLng(lat: $latitude, lon: $longitude)';
}
