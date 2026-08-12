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
  bool _hasFittedOverview = false;
  bool _isFollowingUser = false;
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

    // Camera follow mode: only active if user enabled follow or after significant movement (> 10m)
    if (_styleLoaded && _mapController != null && widget.currentPosition != null) {
      final pos = widget.currentPosition!;
      final oldPos = oldWidget.currentPosition;

      // Auto-enable follow mode if participant starts moving significantly (> 10m)
      if (!_isFollowingUser && oldPos != null) {
        final dLat = (pos.latitude - oldPos.latitude).abs();
        final dLng = (pos.longitude - oldPos.longitude).abs();
        if (dLat > 0.0001 || dLng > 0.0001) {
          _isFollowingUser = true;
        }
      }

      if (!_isFollowingUser) return;

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

  List<dynamic>? _extractCoordinates(Map<String, dynamic> geojson) {
    try {
      if (geojson['type'] == 'FeatureCollection' &&
          geojson['features'] != null &&
          (geojson['features'] as List).isNotEmpty) {
        final feature = geojson['features'][0];
        if (feature['geometry'] != null && feature['geometry']['coordinates'] != null) {
          return feature['geometry']['coordinates'] as List;
        }
      } else if (geojson['type'] == 'Feature' &&
          geojson['geometry'] != null &&
          geojson['geometry']['coordinates'] != null) {
        return geojson['geometry']['coordinates'] as List;
      } else if (geojson['type'] == 'LineString' && geojson['coordinates'] != null) {
        return geojson['coordinates'] as List;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _drawRoute() async {
    if (_mapController == null || widget.routeGeojson == null || !_styleLoaded) return;

    try {
      final normalizedGeojson = _normalizeGeojson(widget.routeGeojson!);

      // Remove previous layer & source if re-drawing
      try {
        await _mapController?.removeLayer("start-point-layer");
        await _mapController?.removeSource("start-point");
        await _mapController?.removeLayer("finish-point-layer");
        await _mapController?.removeSource("finish-point");
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

      // Extract Start & Finish coordinates and render markers
      final coords = _extractCoordinates(normalizedGeojson);
      if (coords != null && coords.length >= 2) {
        final startPt = coords.first as List;
        final finishPt = coords.last as List;

        final startGeojson = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {'title': 'START'},
              'geometry': {'type': 'Point', 'coordinates': [startPt[0], startPt[1]]}
            }
          ]
        };

        final finishGeojson = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {'title': 'FINISH'},
              'geometry': {'type': 'Point', 'coordinates': [finishPt[0], finishPt[1]]}
            }
          ]
        };

        await _mapController?.addSource(
          "start-point",
          GeojsonSourceProperties(data: startGeojson),
        );
        await _mapController?.addCircleLayer(
          "start-point",
          "start-point-layer",
          const CircleLayerProperties(
            circleColor: '#22c55e',
            circleRadius: 8.0,
            circleStrokeWidth: 3.0,
            circleStrokeColor: '#ffffff',
          ),
        );

        await _mapController?.addSource(
          "finish-point",
          GeojsonSourceProperties(data: finishGeojson),
        );
        await _mapController?.addCircleLayer(
          "finish-point",
          "finish-point-layer",
          const CircleLayerProperties(
            circleColor: '#ef4444',
            circleRadius: 8.0,
            circleStrokeWidth: 3.0,
            circleStrokeColor: '#ffffff',
          ),
        );
      }

      _isRouteDrawn = true;
      debugPrint("🛣️ [LiveMapWidget] Route & Start/Finish markers rendered successfully.");

      // Auto zoom-out overview: fit full route shape when map is first drawn
      if (coords != null && coords.isNotEmpty && !_hasFittedOverview) {
        _hasFittedOverview = true;
        final bounds = _calculateRouteBounds(coords);
        if (bounds != null) {
          Future.delayed(const Duration(milliseconds: 300), () {
            try {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngBounds(
                  bounds,
                  top: 120,
                  bottom: 260,
                  left: 40,
                  right: 40,
                ),
              );
              debugPrint("🗺️ [LiveMapWidget] Initial full route overview bounds fitted.");
            } catch (e) {
              debugPrint("⚠️ [LiveMapWidget] Route overview fit bounds error: $e");
            }
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ [LiveMapWidget] Failed to draw route: $e");
    }
  }

  LatLngBounds? _calculateRouteBounds(List<dynamic> coords) {
    if (coords.isEmpty) return null;
    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    for (final pt in coords) {
      if (pt is List && pt.length >= 2) {
        final lng = (pt[0] as num).toDouble();
        final lat = (pt[1] as num).toDouble();
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
    }

    if (minLat >= maxLat || minLng >= maxLng) return null;

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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
