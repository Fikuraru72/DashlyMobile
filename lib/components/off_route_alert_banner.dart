import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════
/// OffRouteAlertBanner — Pulsing Alert when Participant is Off Route
/// ════════════════════════════════════════════════════════════════
class OffRouteAlertBanner extends StatefulWidget {
  final bool isOffRoute;
  final double? offRouteDistanceMeters;

  const OffRouteAlertBanner({
    super.key,
    required this.isOffRoute,
    this.offRouteDistanceMeters,
  });

  @override
  State<OffRouteAlertBanner> createState() => _OffRouteAlertBannerState();
}

class _OffRouteAlertBannerState extends State<OffRouteAlertBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOffRoute) return const SizedBox.shrink();

    final int roundedDist = widget.offRouteDistanceMeters?.round() ?? 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.6),
                  blurRadius: _glowAnimation.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "PESERTA KELUAR JALUR!",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const Spacer(),
                          if (roundedDist > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "+${roundedDist}m",
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Anda berada di luar jalur resmi event. Harap kembali ke rute yang telah ditentukan.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
