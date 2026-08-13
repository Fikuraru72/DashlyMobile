import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════
/// OffRouteAlertBanner — Sleek Pulsing Alert badge matching TO DESTINATION size
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

    _glowAnimation = Tween<double>(begin: 4.0, end: 14.0).animate(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0707).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.redAccent, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.45),
                  blurRadius: _glowAnimation.value,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 15,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "OFF COURSE WARNING",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "+${roundedDist} M OFF",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
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
