import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../services/event_service.dart';

class DashboardStats {
  final double totalDistance;
  final int totalEvents;
  final double avgSpeed;
  final int points;

  const DashboardStats({
    required this.totalDistance,
    required this.totalEvents,
    required this.avgSpeed,
    required this.points,
  });
}

class DashboardProvider extends ChangeNotifier {
  DashboardStats _stats = const DashboardStats(
    totalDistance: 0.0,
    totalEvents: 0,
    avgSpeed: 0.0,
    points: 0,
  );

  // We won't use recent activities in DashboardStats directly anymore, 
  // or we can fetch them from EventProvider.myEvents on the UI side.
  // Leaving this empty.
  final List<RecentActivity> _recentActivities = [];

  DashboardStats get stats => _stats;
  List<RecentActivity> get recentActivities => List.unmodifiable(_recentActivities);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final EventService _eventService = EventService();

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    notifyListeners();

    final statsData = await _eventService.getUserStats();
    if (statsData != null) {
      _stats = DashboardStats(
        totalDistance: (statsData['totalDistance'] as num?)?.toDouble() ?? 0.0,
        totalEvents: (statsData['totalEvents'] as num?)?.toInt() ?? 0,
        avgSpeed: (statsData['avgSpeed'] as num?)?.toDouble() ?? 0.0,
        points: (statsData['points'] as num?)?.toInt() ?? 0,
      );
    }

    _isLoading = false;
    notifyListeners();
  }
}
