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
/// ShareRidePhotoScreen — Ultra-Clean Minimalist Cycling Photo Share 📸
/// ════════════════════════════════════════════════════════════════
/// Features:
/// 1. Top Header: Event Name + Dashly Cycling & BIB Badge
/// 2. Bottom-Left 2x2 Grid Stats (Distance, Time HH:MM, Avg, Elev)
///    - Floating pure white text (No black background box)
/// 3. Bottom-Right: Neon Green Floating GPS Vector Route Line 💚
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
    Map<String, dynamic>? geojson = widget.routeGeojson;
    if (geojson == null && mounted) {
      final eventProv = context.read<EventProvider>();
      final cached = eventProv.getCachedEvent(widget.eventId);
      if (cached?.routeGeojson != null) {
        geojson = cached!.routeGeojson;
      } else {
        try {
          final myEv = eventProv.myEvents.firstWhere((e) => e.id == widget.eventId);
          if (myEv.routeGeojson != null) {
            geojson = myEv.routeGeojson;
          }
        } catch (_) {}
      }
    }

    if (geojson != null) {
      try {
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

  String _formatDurationHHMMSS(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
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
                    // RepaintBoundary Clean Photo Card
                    RepaintBoundary(
                      key: _globalKey,
                      child: Container(
                        width: double.infinity,
                        height: 450,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                              // 1. Background Photo or Dark Canvas
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

                              // Subtle Gradient Overlay for Clean Pure White Text Contrast
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.55),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.75),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),

                              // 2. [TULISAN NAMA EVENT DI ATAS] Clean White Header Section
                              Positioned(
                                top: 20,
                                left: 20,
                                right: 20,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Event Name Title in Pure White
                                          Text(
                                            widget.eventName.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              letterSpacing: 1.2,
                                              shadows: [
                                                Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 1)),
                                              ],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),

                                          // Dashly Cycling Title in Pure White Text
                                          Row(
                                            children: [
                                              const Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                                              const SizedBox(width: 3),
                                              Text(
                                                "DASHLY CYCLING",
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 9,
                                                  letterSpacing: 1.0,
                                                  shadows: const [
                                                    Shadow(color: Colors.black, blurRadius: 6),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // BIB Badge in Pure White Text
                                    if (bibText.isNotEmpty)
                                      Text(
                                        bibText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 1.0,
                                          shadows: [
                                            Shadow(color: Colors.black, blurRadius: 6),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // 3. [STATS 2X2 GRID DI BAWAH KIRI] Clean Pure White Text, Tanpa Background Hitam
                              Positioned(
                                bottom: 20,
                                left: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Row 1: Distance & Time (HH:MM)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildCleanWhiteStat("DISTANCE", "${widget.totalDistanceKm.toStringAsFixed(2)} km"),
                                        const SizedBox(width: 24),
                                        _buildCleanWhiteStat("TIME", _formatDurationHHMMSS(widget.elapsedDuration)),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    // Row 2: Avg Speed & Elev Gain
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildCleanWhiteStat("AVG SPEED", "${widget.avgSpeedKmh.toStringAsFixed(1)} km/h"),
                                        const SizedBox(width: 24),
                                        _buildCleanWhiteStat("ELEV GAIN", "${widget.elevationGainM.toStringAsFixed(0)} m"),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // 4. [GAMBAR RUTE DI SEBELAH KANAN BAWAH] Neon Green Floating GPS Route Line 💚
                              if (_routePoints.isNotEmpty)
                                Positioned(
                                  bottom: 20,
                                  right: 20,
                                  child: SizedBox(
                                    width: 135,
                                    height: 105,
                                    child: CustomPaint(
                                      painter: NeonGreenRoutePainter(
                                        points: _routePoints,
                                        routeColor: const Color(0xFF00FF66), // Neon Vibrant Green 💚
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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

  Widget _buildCleanWhiteStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// ════════════════════════════════════════════════════════════════
/// NeonGreenRoutePainter — Floating Neon Green GPS Vector Line 💚
/// ════════════════════════════════════════════════════════════════
class NeonGreenRoutePainter extends CustomPainter {
  final List<DashlyLatLng> points;
  final Color routeColor;

  NeonGreenRoutePainter({required this.points, required this.routeColor});

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

    // Outer Shadow Line for High Contrast on any photo
    final shadowPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Neon Green Route Line
    final linePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
