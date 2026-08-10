import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';

/// ════════════════════════════════════════════════════════════════
/// ShareRidePhotoScreen — Strava-Style Cycling Photo Share & Download 📸
/// ════════════════════════════════════════════════════════════════
/// Allows riders to pick/take a photo, overlay performance metrics,
/// download to gallery, and share directly to social media.
/// ════════════════════════════════════════════════════════════════
class ShareRidePhotoScreen extends StatefulWidget {
  final int eventId;
  final String eventName;
  final Duration elapsedDuration;
  final double totalDistanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double elevationGainM;

  const ShareRidePhotoScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.elapsedDuration,
    required this.totalDistanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.elevationGainM,
  });

  @override
  State<ShareRidePhotoScreen> createState() => _ShareRidePhotoScreenState();
}

class _ShareRidePhotoScreenState extends State<ShareRidePhotoScreen> {
  final GlobalKey _globalKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;

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

      // Use 2.0x pixel ratio for maximum memory safety and high sharpness
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
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

  /// Option 1: Download / Save Card to Gallery
  Future<void> _downloadCard() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final file = await _captureCardImage();
      if (file == null) throw Exception("Could not capture image card");

      // Save directly to device Gallery via Gal plugin (registers with Android MediaStore & iOS Photos)
      await Gal.putImage(file.path, album: 'Dashly');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.black),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Card saved to Gallery (Dashly Album)! 💾",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: context.dashlyColors.accent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving image to gallery: $e"),
            backgroundColor: context.dashlyColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Option 2: Share Card to Social Media
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
        text: 'Finished ${widget.eventName} with Dashly Cycling! 🚴‍♂️⚡ #DashlyCycling',
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
                    // RepaintBoundary Canvas Card
                    RepaintBoundary(
                      key: _globalKey,
                      child: Container(
                        width: double.infinity,
                        height: 440,
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
                              // 1. Background Image or Gradient
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
                                      color: context.dashlyColors.accent.withValues(alpha: 0.12),
                                    ),
                                  ),
                                ),

                              // Gradient Vignette Overlay for Contrast
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.6),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.85),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),

                              // 2. Top Header Branding
                              Positioned(
                                top: 20,
                                left: 20,
                                right: 20,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Dashly Logo Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.6)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.bolt_rounded, size: 14, color: context.dashlyColors.accent),
                                          const SizedBox(width: 4),
                                          Text(
                                            "DASHLY CYCLING",
                                            style: TextStyle(
                                              color: context.dashlyColors.accent,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // BIB Badge
                                    if (bibText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Text(
                                          bibText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // 3. Event Name
                              Positioned(
                                top: 62,
                                left: 20,
                                right: 20,
                                child: Text(
                                  widget.eventName.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(color: Colors.black87, blurRadius: 6),
                                    ],
                                  ),
                                ),
                              ),

                              // 4. Bottom Metrics Overlay Card (Glassmorphism)
                              Positioned(
                                bottom: 20,
                                left: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: _buildOverlayMetricItem(context, "DISTANCE", widget.totalDistanceKm.toStringAsFixed(2), "KM", Icons.straighten_rounded)),
                                          _buildDivider(context),
                                          Expanded(child: _buildOverlayMetricItem(context, "RIDE TIME", _formatDuration(widget.elapsedDuration), "", Icons.timer_outlined)),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Divider(height: 1, color: Colors.white12),
                                      ),
                                      Row(
                                        children: [
                                          Expanded(child: _buildOverlayMetricItem(context, "AVG SPEED", widget.avgSpeedKmh.toStringAsFixed(1), "KM/H", Icons.directions_bike_rounded)),
                                          _buildDivider(context),
                                          Expanded(child: _buildOverlayMetricItem(context, "ELEV GAIN", widget.elevationGainM.toStringAsFixed(0), "M", Icons.landscape_rounded)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Photo Selector Controls (Camera vs Gallery)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text("TAKE PHOTO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.dashlyColors.textPrimary,
                              side: BorderSide(color: context.dashlyColors.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text("SELECT GALLERY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.dashlyColors.textPrimary,
                              side: BorderSide(color: context.dashlyColors.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                      height: 52,
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
                    flex: 1,
                    child: SizedBox(
                      height: 52,
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

  Widget _buildOverlayMetricItem(BuildContext context, String label, String value, String unit, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: context.dashlyColors.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: context.dashlyColors.accent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  color: context.dashlyColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white12,
    );
  }
}
