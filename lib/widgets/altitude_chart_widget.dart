import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/dashly_theme.dart';

class AltitudeChartWidget extends StatefulWidget {
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
  State<AltitudeChartWidget> createState() => _AltitudeChartWidgetState();
}

class _AltitudeChartWidgetState extends State<AltitudeChartWidget> {
  double _zoomFactor = 1.0; // 1.0x (full view) up to 4.0x

  void _zoomIn() {
    setState(() {
      if (_zoomFactor < 4.0) _zoomFactor += 0.75;
    });
  }

  void _zoomOut() {
    setState(() {
      if (_zoomFactor > 1.0) {
        _zoomFactor -= 0.75;
        if (_zoomFactor < 1.0) _zoomFactor = 1.0;
      }
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomFactor = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.altitudeProfile.isEmpty) return const SizedBox.shrink();

    final List<FlSpot> spots = [];
    double maxElev = 0;
    double minElev = double.infinity;
    double maxDist = 0;

    for (var pt in widget.altitudeProfile) {
      double dist = (pt['distance'] as num).toDouble();
      double elev = (pt['elevation'] as num).toDouble();
      spots.add(FlSpot(dist, elev));
      if (elev > maxElev) maxElev = elev;
      if (elev < minElev) minElev = elev;
      if (dist > maxDist) maxDist = dist;
    }

    if (maxElev == 0 && minElev == double.infinity) return const SizedBox.shrink();

    final double totalDist = maxDist > 0 ? maxDist : 1000.0;

    // Determine viewport X range based on zoom factor
    double minX = 0;
    double maxX = totalDist;

    if (_zoomFactor > 1.0) {
      double visibleWindow = totalDist / _zoomFactor;
      // Center visible window around current distance if possible
      minX = widget.currentDistanceMeters - (visibleWindow / 2);
      maxX = widget.currentDistanceMeters + (visibleWindow / 2);

      if (minX < 0) {
        minX = 0;
        maxX = visibleWindow;
      }
      if (maxX > totalDist) {
        maxX = totalDist;
        minX = totalDist - visibleWindow;
        if (minX < 0) minX = 0;
      }
    }

    // Find current user's spot index along profile
    int userSpotIndex = 0;
    if (spots.isNotEmpty) {
      double minDiff = (spots.first.x - widget.currentDistanceMeters).abs();
      for (int i = 0; i < spots.length; i++) {
        double diff = (spots[i].x - widget.currentDistanceMeters).abs();
        if (diff < minDiff) {
          minDiff = diff;
          userSpotIndex = i;
        }
      }
    }

    final List<VerticalLine> verticalLines = [
      VerticalLine(
        x: widget.currentDistanceMeters,
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
    for (var runner in widget.otherRunners) {
      final double runnerDistKm = (runner['d'] as num).toDouble();
      final double runnerDistMeters = runnerDistKm * 1000.0;
      final int rank = (runner['r'] as num).toInt();

      verticalLines.add(
        VerticalLine(
          x: runnerDistMeters,
          color: Colors.amberAccent.withValues(alpha: 0.7),
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
      height: 165,
      padding: const EdgeInsets.only(top: 12, bottom: 8, left: 0, right: 16),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dashlyColors.divider.withValues(alpha: 0.6)),
      ),
      child: Stack(
        children: [
          // Chart View
          Positioned.fill(
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minElev - 10 < 0 ? 0 : minElev - 10,
                maxY: maxElev + 15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: context.dashlyColors.divider.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Text(
                            '${value.toInt()}m',
                            style: TextStyle(color: context.dashlyColors.textHint, fontSize: 9),
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
                      interval: (maxX - minX) / 4 > 0 ? (maxX - minX) / 4 : 1000,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            '${(value / 1000).toStringAsFixed(1)}km',
                            style: TextStyle(color: context.dashlyColors.textHint, fontSize: 9),
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
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    showingIndicators: spots.isNotEmpty ? [userSpotIndex] : [],
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) {
                        return (spot.x - widget.currentDistanceMeters).abs() < 50;
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
                          context.dashlyColors.accent.withValues(alpha: 0.4),
                          context.dashlyColors.accent.withValues(alpha: 0.0),
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
          ),

          // Zoom Controls Overlay (Top Right)
          Positioned(
            top: 0,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.dashlyColors.divider.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_zoomFactor.toStringAsFixed(1)}x',
                    style: TextStyle(
                      color: context.dashlyColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildZoomIconButton(
                    icon: Icons.zoom_in_rounded,
                    onTap: _zoomIn,
                    tooltip: "Zoom In",
                  ),
                  _buildZoomIconButton(
                    icon: Icons.zoom_out_rounded,
                    onTap: _zoomOut,
                    tooltip: "Zoom Out",
                  ),
                  if (_zoomFactor > 1.0)
                    _buildZoomIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: _resetZoom,
                      tooltip: "Reset Zoom",
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}
