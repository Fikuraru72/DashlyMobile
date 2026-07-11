enum EventStatus {
  idle,
  start,
  finished,
}

enum EventCategory {
  running,
  cycling,
}

enum ParticipantState {
  registered,
  confirmed,
  tracking,
  finished,
}

class Event {
  final int id;
  final String name;
  final String description;
  final EventCategory category;
  final EventStatus status;
  final String token;
  final int currentCount;
  final int maxParticipants;
  final DateTime dateEvent;
  final Map<String, dynamic>? routeGeojson;
  final DateTime? startTime;
  final DateTime? endTime;
  final int monitoringStartOffset; // in minutes
  final int monitoringEndOffset;   // in minutes
  final Map<String, dynamic>? monitoringWindow;
  
  final String? bibNumber;
  final String? bannerBase64;
  final double? latitude;
  final double? longitude;
  final ParticipantState? participantState;

  const Event({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.status,
    required this.token,
    required this.currentCount,
    required this.maxParticipants,
    required this.dateEvent,
    this.routeGeojson,
    this.startTime,
    this.endTime,
    this.monitoringStartOffset = 60,
    this.monitoringEndOffset = 240,
    this.monitoringWindow,
    this.bibNumber,
    this.bannerBase64,
    this.latitude,
    this.longitude,
    this.participantState,
  });

  /// Computed: The actual time monitoring window opens
  DateTime? get actualStart {
    if (monitoringWindow != null && monitoringWindow!['actualStart'] != null) {
      return DateTime.parse(monitoringWindow!['actualStart']);
    }
    if (startTime == null) return null;
    return startTime!.subtract(Duration(minutes: monitoringStartOffset));
  }

  /// Computed: The actual time monitoring window closes
  DateTime? get actualEnd {
    if (monitoringWindow != null && monitoringWindow!['actualEnd'] != null) {
      return DateTime.parse(monitoringWindow!['actualEnd']);
    }
    if (endTime == null) return null;
    return endTime!.add(Duration(minutes: monitoringEndOffset));
  }

  /// Is the monitoring window currently open?
  bool get isMonitoringWindowOpen {
    final start = actualStart;
    final end = actualEnd;
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Can the participant start tracking? (Double-Lock check)
  bool get canStartTracking {
    return status == EventStatus.start && isMonitoringWindowOpen;
  }

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        category: _parseCategory(json['category'] as String?),
        status: _parseStatus(json['status'] as String),
        token: json['token'] as String,
        currentCount: json['currentCount'] as int,
        maxParticipants: json['maxParticipants'] as int,
        dateEvent: DateTime.parse(json['dateEvent'] as String),
        routeGeojson: json['routeGeojson'] as Map<String, dynamic>?,
        startTime: json['startTime'] != null ? DateTime.parse(json['startTime'] as String) : null,
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
        monitoringStartOffset: json['monitoringStartOffset'] as int? ?? 60,
        monitoringEndOffset: json['monitoringEndOffset'] as int? ?? 240,
        monitoringWindow: json['monitoringWindow'] as Map<String, dynamic>?,
        bibNumber: json['bibNumber'] as String?,
        bannerBase64: json['bannerBase64'] as String? ?? json['bannerImage'] as String?,
        latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
        longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
        participantState: _parseParticipantState(json['participantState'] as String?),
      );

  static EventStatus _parseStatus(String status) {
    if (status == 'START' || status == 'LIVE') return EventStatus.start;
    if (status == 'FINISHED') return EventStatus.finished;
    return EventStatus.idle;
  }

  static EventCategory _parseCategory(String? category) {
    if (category == 'CYCLING') return EventCategory.cycling;
    return EventCategory.running;
  }

  static ParticipantState? _parseParticipantState(String? state) {
    switch (state) {
      case 'REGISTERED': return ParticipantState.registered;
      case 'CONFIRMED': return ParticipantState.confirmed;
      case 'TRACKING': return ParticipantState.tracking;
      case 'FINISHED': return ParticipantState.finished;
      default: return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category == EventCategory.cycling ? 'CYCLING' : 'RUNNING',
        'status': status == EventStatus.start ? 'START' : status == EventStatus.finished ? 'FINISHED' : 'IDLE',
        'token': token,
        'currentCount': currentCount,
        'maxParticipants': maxParticipants,
        'dateEvent': dateEvent.toIso8601String(),
        'routeGeojson': routeGeojson,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'monitoringStartOffset': monitoringStartOffset,
        'monitoringEndOffset': monitoringEndOffset,
        'bibNumber': bibNumber,
        'bannerBase64': bannerBase64,
        'latitude': latitude,
        'longitude': longitude,
        'participantState': _serializeParticipantState(participantState),
      };

  String? _serializeParticipantState(ParticipantState? state) {
    switch (state) {
      case ParticipantState.registered: return 'REGISTERED';
      case ParticipantState.confirmed: return 'CONFIRMED';
      case ParticipantState.tracking: return 'TRACKING';
      case ParticipantState.finished: return 'FINISHED';
      default: return null;
    }
  }

  Event copyWith({
    int? id,
    String? name,
    String? description,
    EventCategory? category,
    EventStatus? status,
    String? token,
    int? currentCount,
    int? maxParticipants,
    DateTime? dateEvent,
    Map<String, dynamic>? routeGeojson,
    DateTime? startTime,
    DateTime? endTime,
    int? monitoringStartOffset,
    int? monitoringEndOffset,
    Map<String, dynamic>? monitoringWindow,
    String? bibNumber,
    String? bannerBase64,
    double? latitude,
    double? longitude,
    ParticipantState? participantState,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      token: token ?? this.token,
      currentCount: currentCount ?? this.currentCount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      dateEvent: dateEvent ?? this.dateEvent,
      routeGeojson: routeGeojson ?? this.routeGeojson,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      monitoringStartOffset: monitoringStartOffset ?? this.monitoringStartOffset,
      monitoringEndOffset: monitoringEndOffset ?? this.monitoringEndOffset,
      monitoringWindow: monitoringWindow ?? this.monitoringWindow,
      bibNumber: bibNumber ?? this.bibNumber,
      bannerBase64: bannerBase64 ?? this.bannerBase64,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      participantState: participantState ?? this.participantState,
    );
  }
}
