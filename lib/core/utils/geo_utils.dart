import 'dart:math';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

/// Custom coordinate model for Dashly to replace latlong2 dependency.
class DashlyLatLng {
  final double latitude;
  final double longitude;
  final double heading;

  const DashlyLatLng(this.latitude, this.longitude, {this.heading = 0.0});

  /// Helper to convert Geolocator Position to DashlyLatLng.
  factory DashlyLatLng.fromPosition(Position position) {
    final h = position.heading >= 0 ? position.heading : 0.0;
    return DashlyLatLng(position.latitude, position.longitude, heading: h);
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

/// Geographic utilities for Dashly route & location processing
class GeoUtils {
  /// Parses raw GeoJSON (Map or String) into a list of DashlyLatLng coordinates.
  static List<DashlyLatLng> parseGeoJsonCoordinates(dynamic rawGeojson) {
    if (rawGeojson == null) return [];
    Map<String, dynamic>? geojson;
    if (rawGeojson is String) {
      try {
        geojson = jsonDecode(rawGeojson) as Map<String, dynamic>?;
      } catch (_) {
        return [];
      }
    } else if (rawGeojson is Map<String, dynamic>) {
      geojson = rawGeojson;
    }

    if (geojson == null) return [];
    List<dynamic> rawCoords = [];

    try {
      if (geojson['type'] == 'LineString' && geojson['coordinates'] is List) {
        rawCoords = geojson['coordinates'];
      } else if (geojson['type'] == 'Feature' && geojson['geometry'] != null) {
        rawCoords = geojson['geometry']['coordinates'] ?? [];
      } else if (geojson['type'] == 'FeatureCollection' &&
          geojson['features'] != null &&
          (geojson['features'] as List).isNotEmpty) {
        for (var feat in geojson['features']) {
          final geom = feat['geometry'];
          if (geom != null && geom['type'] == 'LineString' && geom['coordinates'] is List) {
            rawCoords.addAll(geom['coordinates']);
          }
        }
      }

      final List<DashlyLatLng> points = [];
      for (var c in rawCoords) {
        if (c is List && c.length >= 2) {
          final double lon = (c[0] as num).toDouble();
          final double lat = (c[1] as num).toDouble();
          points.add(DashlyLatLng(lat, lon));
        }
      }
      return points;
    } catch (_) {
      return [];
    }
  }

  /// Calculates minimum distance in meters from a point to a line segment AB.
  static double distanceToSegment(DashlyLatLng p, DashlyLatLng a, DashlyLatLng b) {
    final l2 = a.distanceTo(b);
    if (l2 == 0) return p.distanceTo(a);

    final cosLat = cos(p.latitude * pi / 180.0);
    final ax = a.longitude * cosLat * 111320.0;
    final ay = a.latitude * 111320.0;
    final bx = b.longitude * cosLat * 111320.0;
    final by = b.latitude * 111320.0;
    final px = p.longitude * cosLat * 111320.0;
    final py = p.latitude * 111320.0;

    final vx = bx - ax;
    final vy = by - ay;
    final segLengthSq = vx * vx + vy * vy;
    if (segLengthSq == 0) return p.distanceTo(a);

    final t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / segLengthSq));
    final projLat = a.latitude + t * (b.latitude - a.latitude);
    final projLon = a.longitude + t * (b.longitude - a.longitude);

    return p.distanceTo(DashlyLatLng(projLat, projLon));
  }

  /// Calculates minimum distance in meters from a point to a route polyline.
  static double minDistanceToPolyline(DashlyLatLng point, List<DashlyLatLng> polyline) {
    if (polyline.isEmpty) return 0.0;
    if (polyline.length == 1) return point.distanceTo(polyline.first);

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final dist = distanceToSegment(point, polyline[i], polyline[i + 1]);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance;
  }

  /// Returns true if point is off-route by more than [thresholdMeters].
  static bool isOffRoute(DashlyLatLng? point, List<DashlyLatLng> polyline, {double thresholdMeters = 50.0}) {
    if (point == null || polyline.isEmpty) return false;
    return minDistanceToPolyline(point, polyline) > thresholdMeters;
  }
}
