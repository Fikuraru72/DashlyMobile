import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/dashly_theme.dart';

class AltitudeChartWidget extends StatelessWidget {
  final List<dynamic> altitudeProfile;
  final double currentDistanceMeters;
  final List<Map<String, dynamic>> otherRunners;

  const AltitudeChartWidget({
    super.key,
    required this.altitudeProfile,
    required this.currentDistanceMeters,
    this.otherRunners = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (altitudeProfile.isEmpty) return const SizedBox.shrink();

    final List<FlSpot> spots = [];
    double maxElev = 0;
    double minElev = double.infinity;
    double maxDist = 0;

    for (var pt in altitudeProfile) {
      double dist = (pt['distance'] as num).toDouble();
      double elev = (pt['elevation'] as num).toDouble();
      spots.add(FlSpot(dist, elev));
      if (elev > maxElev) maxElev = elev;
      if (elev < minElev) minElev = elev;
      if (dist > maxDist) maxDist = dist;
    }

    if (maxElev == 0 && minElev == double.infinity) return const SizedBox.shrink();

    // Find current user's interpolated elevation along profile
    double userElev = spots.isNotEmpty ? spots.first.y : 0;
    int userSpotIndex = 0;
    if (spots.isNotEmpty) {
      double minDiff = (spots.first.x - currentDistanceMeters).abs();
      for (int i = 0; i < spots.length; i++) {
        double diff = (spots[i].x - currentDistanceMeters).abs();
        if (diff < minDiff) {
          minDiff = diff;
          userElev = spots[i].y;
          userSpotIndex = i;
        }
      }
    }

    final List<VerticalLine> verticalLines = [
      VerticalLine(
        x: currentDistanceMeters,
        color: Colors.cyanAccent,
        strokeWidth: 2,
        dashArray: [4, 4],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(left: 4, top: 2),
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
          labelResolver: (line) => 'YOU',
        ),
      ),
    ];

    // Plot vertical lines for other runners
    for (var runner in otherRunners) {
      final double runnerDistKm = (runner['d'] as num).toDouble();
      final double runnerDistMeters = runnerDistKm * 1000.0;
      final int rank = (runner['r'] as num).toInt();

      verticalLines.add(
        VerticalLine(
          x: runnerDistMeters,
          color: Colors.amberAccent.withOpacity(0.7),
          strokeWidth: 1.5,
          dashArray: [2, 2],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(left: 2, top: 12),
            style: const TextStyle(color: Colors.amberAccent, fontSize: 9),
            labelResolver: (line) => '#$rank',
          ),
        ),
      );
    }

    return Container(
      height: 140,
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 0, right: 16),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxDist > 0 ? maxDist : 1000,
          minY: minElev - 10,
          maxY: maxElev + 10,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: context.dashlyColors.divider,
                strokeWidth: 1,
                dashArray: [4, 4],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      '${value.toInt()}m',
                      style: TextStyle(color: context.dashlyColors.textHint, fontSize: 10),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: maxDist / 4 > 0 ? maxDist / 4 : 1000,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${(value / 1000).toStringAsFixed(1)}km',
                      style: TextStyle(color: context.dashlyColors.textHint, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: context.dashlyColors.accent,
              barWidth: 2,
              isStrokeCapRound: true,
              showingIndicators: spots.isNotEmpty ? [userSpotIndex] : [],
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) {
                  return (spot.x - currentDistanceMeters).abs() < 50;
                },
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: Colors.cyanAccent,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    context.dashlyColors.accent.withOpacity(0.4),
                    context.dashlyColors.accent.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            verticalLines: verticalLines,
          ),
        ),
      ),
    );
  }
}
