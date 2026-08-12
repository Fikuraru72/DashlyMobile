import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/utils/geo_utils.dart';

/// ════════════════════════════════════════════════════════════════
/// Live Map Widget — MapLibre GL Native Location Tracking
/// ════════════════════════════════════════════════════════════════
/// Displays real-time GPS location on a dark-themed map.
/// Uses safe MyLocationTrackingMode.tracking and MyLocationRenderMode.normal
/// to prevent Android 14 native C++ sensor crashes in libmaplibre.so.
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
  bool _isRouteDrawn = false;
  double _currentBearing = 0.0;
  DashlyLatLng? _lastAnimatedPosition;

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

    // Only update map route if GeoJSON has changed
    if (oldWidget.routeGeojson != widget.routeGeojson || !_isRouteDrawn) {
      _drawRoute();
    }

    // Smoothly center camera target on participant pointer and rotate bearing when turning (> 3m movement)
    if (_styleLoaded && _mapController != null && widget.currentPosition != null) {
      final pos = widget.currentPosition!;
      final oldPos = oldWidget.currentPosition;

      if (_lastAnimatedPosition != null) {
        final dLat = (pos.latitude - _lastAnimatedPosition!.latitude).abs();
        final dLng = (pos.longitude - _lastAnimatedPosition!.longitude).abs();
        if (dLat < 0.00003 && dLng < 0.00003) return;
      }

      // Determine heading/bearing: prefer position.heading, fallback to movement vector calculation
      if (pos.heading > 0) {
        _currentBearing = pos.heading;
      } else if (oldPos != null) {
        final dLat = (pos.latitude - oldPos.latitude).abs();
        final dLng = (pos.longitude - oldPos.longitude).abs();
        if (dLat > 0.000003 || dLng > 0.000003) {
          _currentBearing = _calculateBearing(
            oldPos.latitude,
            oldPos.longitude,
            pos.latitude,
            pos.longitude,
          );
        }
      }

      _lastAnimatedPosition = pos;
      try {
        final double activeZoom = _mapController?.cameraPosition?.zoom ?? 18.0;
        final double activeTilt = _mapController?.cameraPosition?.tilt ?? 55.0;

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(pos.latitude, pos.longitude),
              zoom: activeZoom,
              tilt: activeTilt,
              bearing: _currentBearing,
            ),
          ),
        );
      } catch (e) {
        debugPrint("⚠️ [LiveMapWidget] Safe position follow error: $e");
      }
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

      // Remove previous layer & source if re-drawing
      try {
        await _mapController?.removeLayer("route-main-layer");
        await _mapController?.removeSource("route-main");
      } catch (_) {}

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
          lineWidth: 6.0,
          lineOpacity: 1.0,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      _isRouteDrawn = true;
      debugPrint("🛣️ [LiveMapWidget] Route rendered successfully.");
    } catch (e) {
      debugPrint("⚠️ [LiveMapWidget] Failed to draw route: $e");
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
        zoom: 14.5,
        tilt: 0.0,
      ),
      styleString: styleUrl,
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      trackCameraPosition: true,
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
      myLocationRenderMode: MyLocationRenderMode.normal,
      compassEnabled: false,
      attributionButtonMargins: Point(-10, -10),
    );
  }
}
