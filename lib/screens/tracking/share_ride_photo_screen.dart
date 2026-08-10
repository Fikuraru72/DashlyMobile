import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../core/utils/geo_utils.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';

/// ════════════════════════════════════════════════════════════════
/// ShareRidePhotoScreen — Custom Strava-Style Layout 📸
/// ════════════════════════════════════════════════════════════════
/// Custom Layout:
/// 1. Top Header: Event Name + Dashly Cycling & BIB Badge
/// 2. Bottom-Left: Compact Cycling Metrics (Dist, Time, Avg, Elev)
/// 3. Bottom-Right: Floating Orange GPS Route Vector Line
/// ════════════════════════════════════════════════════════════════
class ShareRidePhotoScreen extends StatefulWidget {
  final int eventId;
  final String eventName;
  final Duration elapsedDuration;
  final double totalDistanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double elevationGainM;
  final Map<String, dynamic>? routeGeojson;

  const ShareRidePhotoScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.elapsedDuration,
    required this.totalDistanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.elevationGainM,
    this.routeGeojson,
  });

  @override
  State<ShareRidePhotoScreen> createState() => _ShareRidePhotoScreenState();
}

class _ShareRidePhotoScreenState extends State<ShareRidePhotoScreen> {
  final GlobalKey _globalKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;
  List<DashlyLatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _extractRoutePoints();
  }

  void _extractRoutePoints() {
    if (widget.routeGeojson != null) {
      try {
        final geojson = widget.routeGeojson!;
        List<dynamic> rawCoords = [];

        if (geojson['type'] == 'LineString' && geojson['coordinates'] is List) {
          rawCoords = geojson['coordinates'];
        } else if (geojson['type'] == 'Feature' && geojson['geometry'] != null) {
          rawCoords = geojson['geometry']['coordinates'] ?? [];
        } else if (geojson['type'] == 'FeatureCollection' && geojson['features'] != null && (geojson['features'] as List).isNotEmpty) {
          final feat = (geojson['features'] as List).first;
          rawCoords = feat['geometry']['coordinates'] ?? [];
        }

        final parsed = <DashlyLatLng>[];
        for (var c in rawCoords) {
          if (c is List && c.length >= 2) {
            final double lng = (c[0] as num).toDouble();
            final double lat = (c[1] as num).toDouble();
            parsed.add(DashlyLatLng(lat, lng));
          }
        }

        if (parsed.length > 300) {
          final step = (parsed.length / 300).ceil();
          final sampled = <DashlyLatLng>[];
          for (int i = 0; i < parsed.length; i += step) {
            sampled.add(parsed[i]);
          }
          if (sampled.last != parsed.last) sampled.add(parsed.last);
          _routePoints = sampled;
        } else {
          _routePoints = parsed;
        }
      } catch (e) {
        print("Error parsing route GeoJSON for share overlay: $e");
      }
    }

    if (_routePoints.isEmpty) {
      // Fallback stylized cycling loop path
      _routePoints = const [
        DashlyLatLng(-7.250, 112.750),
        DashlyLatLng(-7.245, 112.753),
        DashlyLatLng(-7.240, 112.760),
        DashlyLatLng(-7.238, 112.768),
        DashlyLatLng(-7.242, 112.775),
        DashlyLatLng(-7.248, 112.782),
        DashlyLatLng(-7.255, 112.778),
        DashlyLatLng(-7.262, 112.770),
        DashlyLatLng(-7.260, 112.760),
        DashlyLatLng(-7.254, 112.752),
        DashlyLatLng(-7.250, 112.750),
      ];
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to select image: $e"),
            backgroundColor: context.dashlyColors.error,
          ),
        );
      }
    }
  }

  /// Captures the RepaintBoundary widget into a high-res PNG File
  Future<File?> _captureCardImage() async {
    try {
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/dashly_ride_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      print("Failed to capture image boundary: $e");
      return null;
    }
  }

  /// Download / Save Card to Device Gallery
  Future<void> _downloadCard() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final file = await _captureCardImage();
      if (file == null) throw Exception("Could not capture image card");

      bool galSuccess = false;
      try {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(file.path, album: 'Dashly');
        galSuccess = true;
      } catch (galError) {
        print("Gal save error (falling back to direct file write): $galError");
      }

      if (!galSuccess) {
        Directory targetDir;
        if (Platform.isAndroid) {
          targetDir = Directory('/storage/emulated/0/Pictures/Dashly');
          if (!await targetDir.exists()) {
            try {
              await targetDir.create(recursive: true);
            } catch (_) {
              targetDir = await getApplicationDocumentsDirectory();
            }
          }
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }
        final savedFile = File('${targetDir.path}/dashly_ride_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.copy(savedFile.path);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.black),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Card saved to Gallery / Pictures! 💾",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: context.dashlyColors.accent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving image: $e"),
            backgroundColor: context.dashlyColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Share Card to Social Media
  Future<void> _shareCard() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final file = await _captureCardImage();
      if (file == null) throw Exception("Could not capture image card");
      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Finished ${widget.eventName} with Dashly Cycling! 🚴‍♂️⚡ #Dashly #Cycling',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sharing card: $e"),
            backgroundColor: context.dashlyColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final currentEvent = eventProvider.currentEvent;
    final String bibText = (currentEvent != null && currentEvent.bibNumber != null)
        ? "BIB #${currentEvent.bibNumber}"
        : "";

    return Scaffold(
      backgroundColor: context.dashlyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: context.dashlyColors.textHint),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "SHARE RIDE CARD",
          style: TextStyle(
            color: context.dashlyColors.accent,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    // RepaintBoundary Custom Layout Photo Card
                    RepaintBoundary(
                      key: _globalKey,
                      child: Container(
                        width: double.infinity,
                        height: 450,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: context.dashlyColors.surface,
                          border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.3)),
                          boxShadow: DashlyTheme.glowShadow(
                            color: Colors.black45,
                            blur: 16,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Background Photo or Dark Gradient Canvas
                              if (_selectedImage != null)
                                Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.dashlyColors.surface,
                                        context.dashlyColors.surfaceLight,
                                        Colors.black,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.directions_bike_rounded,
                                      size: 120,
                                      color: context.dashlyColors.accent.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),

                              // Subtle Vignette Overlay for High Readability
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.6),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),

                              // 2. [TULISAN NAMA EVENT DI ATAS] Header Section
                              Positioned(
                                top: 18,
                                left: 18,
                                right: 18,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Event Name Title
                                          Text(
                                            widget.eventName.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              letterSpacing: 1.2,
                                              shadows: [
                                                Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
                                              ],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),

                                          // Dashly Cycling Badge Pill
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.6)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.bolt_rounded, size: 12, color: context.dashlyColors.accent),
                                                const SizedBox(width: 3),
                                                Text(
                                                  "DASHLY CYCLING",
                                                  style: TextStyle(
                                                    color: context.dashlyColors.accent,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 8.5,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // BIB Badge
                                    if (bibText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Text(
                                          bibText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9.5,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // 3. [STATS DI TARUH BAWAH KIRI] Compact Vertical Stack Card
                              Positioned(
                                bottom: 18,
                                left: 18,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildSideStatItem(context, "DISTANCE", "${widget.totalDistanceKm.toStringAsFixed(2)} km"),
                                      const SizedBox(height: 8),
                                      _buildSideStatItem(context, "TIME", _formatDuration(widget.elapsedDuration)),
                                      const SizedBox(height: 8),
                                      _buildSideStatItem(context, "AVG SPEED", "${widget.avgSpeedKmh.toStringAsFixed(1)} km/h"),
                                      const SizedBox(height: 8),
                                      _buildSideStatItem(context, "ELEV GAIN", "${widget.elevationGainM.toStringAsFixed(0)} m"),
                                    ],
                                  ),
                                ),
                              ),

                              // 4. [GAMBAR RUTE DI SEBELAH KANAN BAWAH] Floating Strava Orange GPS Vector Route Line
                              if (_routePoints.isNotEmpty)
                                Positioned(
                                  bottom: 18,
                                  right: 18,
                                  child: SizedBox(
                                    width: 140,
                                    height: 110,
                                    child: CustomPaint(
                                      painter: StravaRoutePainter(
                                        points: _routePoints,
                                        routeColor: const Color(0xFFFC5200), // Iconic Strava Orange
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo Controls (Camera vs Gallery)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: const Text("TAKE PHOTO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.dashlyColors.textPrimary,
                              side: BorderSide(color: context.dashlyColors.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text("SELECT GALLERY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.dashlyColors.textPrimary,
                              side: BorderSide(color: context.dashlyColors.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons: Save/Download & Share
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.dashlyColors.surface,
                border: Border(top: BorderSide(color: context.dashlyColors.divider)),
              ),
              child: Row(
                children: [
                  // 1. Download / Save Button
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _downloadCard,
                        icon: Icon(Icons.download_rounded, color: context.dashlyColors.accent, size: 18),
                        label: const Text(
                          "DOWNLOAD",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.dashlyColors.accent,
                          side: BorderSide(color: context.dashlyColors.accent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Share to Social Media Button
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _shareCard,
                        icon: _isProcessing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.share_rounded, color: Colors.black, size: 18),
                        label: Text(
                          _isProcessing ? "PROCESSING..." : "SHARE CARD",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.dashlyColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.dashlyColors.accent,
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

/// ════════════════════════════════════════════════════════════════
/// StravaRoutePainter — Floating Orange GPS Vector Route Line 🧡
/// ════════════════════════════════════════════════════════════════
class StravaRoutePainter extends CustomPainter {
  final List<DashlyLatLng> points;
  final Color routeColor;

  StravaRoutePainter({required this.points, required this.routeColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    double latSpan = maxLat - minLat;
    double lngSpan = maxLng - minLng;
    if (latSpan == 0) latSpan = 0.0001;
    if (lngSpan == 0) lngSpan = 0.0001;

    final path = Path();
    const double padding = 8.0;

    final drawWidth = size.width - (padding * 2);
    final drawHeight = size.height - (padding * 2);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = padding + ((p.longitude - minLng) / lngSpan) * drawWidth;
      final y = padding + (1.0 - ((p.latitude - minLat) / latSpan)) * drawHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Outer Shadow Line for High Readability on Photos
    final shadowPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Iconic Strava Orange Line
    final linePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
