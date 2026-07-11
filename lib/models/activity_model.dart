class RecentActivity {
  final String eventName;
  final String date;
  final double distance;
  final String duration;

  const RecentActivity({
    required this.eventName,
    required this.date,
    required this.distance,
    required this.duration,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) => RecentActivity(
        eventName: json['eventName'] as String,
        date: json['date'] as String,
        distance: (json['distance'] as num).toDouble(),
        duration: json['duration'] as String,
      );

  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'date': date,
        'distance': distance,
        'duration': duration,
      };
}
