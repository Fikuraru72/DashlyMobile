import 'package:flutter/material.dart';
import '../../theme/dashly_theme.dart';
import 'tracking_screen.dart';
import 'stats_tracking_screen.dart';

/// Shows a sleek bottom sheet to choose between Tracking With Map and Tracking Without Map (Stats Only).
/// Directly launches tracking & telemetry immediately without interlock screens or start buttons.
Future<void> showTrackingModeSelectionDialog(
  BuildContext context, {
  required int eventId,
  required String eventName,
}) async {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.dashlyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SELECT TRACKING MODE",
              style: TextStyle(
                color: context.dashlyColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Choose how you want to track your race progress:",
              style: TextStyle(
                color: context.dashlyColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // MODE 1: MAP MODE
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackingScreen(
                      eventId: eventId,
                      eventName: eventName,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.dashlyColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.dashlyColors.accent),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.map_rounded,
                      color: context.dashlyColors.accent,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TRACKING WITH MAP",
                            style: TextStyle(
                              color: context.dashlyColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Interactive 3D navigation map with route & live position.",
                            style: TextStyle(
                              color: context.dashlyColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: context.dashlyColors.accent,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // MODE 2: STATS ONLY (BATTERY SAVER)
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatsTrackingScreen(
                      eventId: eventId,
                      eventName: eventName,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.dashlyColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.dashlyColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Colors.orangeAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TRACKING WITHOUT MAP (STATS ONLY)",
                            style: TextStyle(
                              color: context.dashlyColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Battery saver mode. Displays metrics & altitude charts.",
                            style: TextStyle(
                              color: context.dashlyColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: context.dashlyColors.textHint,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
