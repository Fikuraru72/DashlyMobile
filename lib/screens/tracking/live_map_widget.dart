import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/utils/geo_utils.dart';

/// ════════════════════════════════════════════════════════════════
/// Live Map Widget — MapLibre GL + MapTiler Dark Mode
/// ════════════════════════════════════════════════════════════════
/// Shows the user's real-time GPS location on a dark-themed map.
/// Uses MapLibre's native `myLocationEnabled` for the blue dot,
/// plus a neon-green circle overlay for visual emphasis.
/// ════════════════════════════════════════════════════════════════

// MapTiler API Key — dataviz-dark style
const String _mapTilerKey = 'wjOjSKbyIzsUb94sRNWi';
const String _darkStyleUrl =
    'https://api.maptiler.com/maps/dataviz-dark/style.json?key=$_mapTilerKey';
const String _lightStyleUrl =
    'https://api.maptiler.com/maps/dataviz-light/style.json?key=$_mapTilerKey';

class LiveMapWidget extends StatefulWidget {
  final DashlyLatLng? currentPosition;
  final Map<String, dynamic>? routeGeojson;
  final void Function(MapLibreMapController)? onControllerCreated;

  const LiveMapWidget({
    super.key,
    required this.currentPosition,
    this.routeGeojson,
    this.onControllerCreated,
  });

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  double _currentBearing = 0.0;

  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * (pi / 180.0);
    final phi1 = lat1 * (pi / 180.0);
    final phi2 = lat2 * (pi / 180.0);
    final y = sin(dLng) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLng);
    final bearing = atan2(y, x) * (180.0 / pi);
    return (bearing + 360.0) % 360.0;
  }

  @override
  void didUpdateWidget(LiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != null && oldWidget.currentPosition != null) {
      final lat1 = oldWidget.currentPosition!.latitude;
      final lng1 = oldWidget.currentPosition!.longitude;
      final lat2 = widget.currentPosition!.latitude;
      final lng2 = widget.currentPosition!.longitude;

      if (lat1 != lat2 || lng1 != lng2) {
        // Compute bearing if moved > 0.5 meters
        final dLat = (lat2 - lat1).abs();
        final dLng = (lng2 - lng1).abs();
        if (dLat > 0.000005 || dLng > 0.000005) {
          _currentBearing = _calculateBearing(lat1, lng1, lat2, lng2);
        }

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(lat2, lng2),
              zoom: 18.0,
              tilt: 55.0,
              bearing: _currentBearing,
            ),
          ),
        );
      }
    } else if (widget.currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude),
            zoom: 18.0,
            tilt: 55.0,
            bearing: _currentBearing,
          ),
        ),
      );
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    widget.onControllerCreated?.call(controller);
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    _drawRoute();
  }

  /// Normalize any GeoJSON variant into a FeatureCollection that MapLibre expects.
  Map<String, dynamic> _normalizeGeojson(Map<String, dynamic> geojson) {
    if (geojson['type'] == 'FeatureCollection') return geojson;
    if (geojson['type'] == 'Feature') {
      return {
        'type': 'FeatureCollection',
        'features': [geojson],
      };
    }
    if (geojson['type'] == 'LineString') {
      return {
        'type': 'FeatureCollection',
        'features': [
          {'type': 'Feature', 'properties': {}, 'geometry': geojson}
        ],
      };
    }
    return geojson;
  }

  Future<void> _drawRoute() async {
    if (_mapController == null || widget.routeGeojson == null || !_styleLoaded) return;

    try {
      final normalizedGeojson = _normalizeGeojson(widget.routeGeojson!);

      await _mapController?.addSource(
        "route-main",
        GeojsonSourceProperties(
          data: normalizedGeojson,
        ),
      );

      await _mapController?.addLineLayer(
        "route-main",
        "route-main-layer",
        const LineLayerProperties(
          lineColor: '#8b5cf6',
          lineWidth: 5.0,
          lineOpacity: 1.0,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      print("🛣️ [LiveMapWidget] Route rendered successfully.");
    } catch (e) {
      print("⚠️ [LiveMapWidget] Failed to draw route: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = widget.currentPosition != null
        ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
        : const LatLng(-7.8711, 112.5269); // Batu, Malang

    // Select style based on current brightness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final styleUrl = isDark ? _darkStyleUrl : _lightStyleUrl;

    return MapLibreMap(
      initialCameraPosition: CameraPosition(
        target: initialPos,
        zoom: 17.0,
        tilt: 50.0,
      ),
      styleString: styleUrl,
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      trackCameraPosition: true,
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
      myLocationRenderMode: MyLocationRenderMode.compass,
      compassEnabled: false,
      attributionButtonMargins: const Point(-100, -100), // hide off-screen
    );
  }
}
