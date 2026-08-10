/// Nested health information model.
class HealthInfo {
  final String? bloodType;
  final double? weight;
  final double? height;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? emergencyRelation;
  final String? emergencyContact;
  final String? medicalHistory;

  const HealthInfo({
    this.bloodType,
    this.weight,
    this.height,
    this.emergencyName,
    this.emergencyPhone,
    this.emergencyRelation,
    this.emergencyContact,
    this.medicalHistory,
  });

  factory HealthInfo.fromJson(Map<String, dynamic> json) => HealthInfo(
        bloodType: json['bloodType'] as String?,
        weight: (json['weight'] as num?)?.toDouble(),
        height: (json['height'] as num?)?.toDouble(),
        emergencyName: json['emergencyName'] as String?,
        emergencyPhone: json['emergencyPhone'] as String?,
        emergencyRelation: json['emergencyRelation'] as String?,
        emergencyContact: json['emergencyContact'] as String?,
        medicalHistory: json['medicalHistory'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'bloodType': bloodType,
        'weight': weight,
        'height': height,
        'emergencyName': emergencyName,
        'emergencyPhone': emergencyPhone,
        'emergencyRelation': emergencyRelation,
        'emergencyContact': formattedEmergencyContact,
        'medicalHistory': medicalHistory,
      };

  String get formattedEmergencyContact {
    if ((emergencyName != null && emergencyName!.isNotEmpty) ||
        (emergencyPhone != null && emergencyPhone!.isNotEmpty) ||
        (emergencyRelation != null && emergencyRelation!.isNotEmpty)) {
      final parts = <String>[];
      if (emergencyName != null && emergencyName!.isNotEmpty) parts.add(emergencyName!);
      if (emergencyRelation != null && emergencyRelation!.isNotEmpty) parts.add('($emergencyRelation)');
      if (emergencyPhone != null && emergencyPhone!.isNotEmpty) parts.add('- $emergencyPhone');
      if (parts.isNotEmpty) return parts.join(' ');
    }
    return emergencyContact ?? 'Not set';
  }

  HealthInfo copyWith({
    String? bloodType,
    double? weight,
    double? height,
    String? emergencyName,
    String? emergencyPhone,
    String? emergencyRelation,
    String? emergencyContact,
    String? medicalHistory,
  }) =>
      HealthInfo(
        bloodType: bloodType ?? this.bloodType,
        weight: weight ?? this.weight,
        height: height ?? this.height,
        emergencyName: emergencyName ?? this.emergencyName,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        emergencyRelation: emergencyRelation ?? this.emergencyRelation,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        medicalHistory: medicalHistory ?? this.medicalHistory,
      );
}

/// Main user model mapped to the backend `users` table.
class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final HealthInfo? healthInfo;
  final String? role;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.healthInfo,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        avatar: json['avatar'] as String?,
        healthInfo: (json['healthProfile'] != null || json['healthInfo'] != null)
            ? HealthInfo.fromJson(
                (json['healthProfile'] ?? json['healthInfo']) as Map<String, dynamic>)
            : null,
        role: json['role'] is String
            ? json['role'] as String
            : (json['role'] is Map ? (json['role']['name'] as String?) : null),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'healthInfo': healthInfo?.toJson(),
        'role': role,
      };

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    HealthInfo? healthInfo,
    String? role,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatar: avatar ?? this.avatar,
        healthInfo: healthInfo ?? this.healthInfo,
        role: role ?? this.role,
      );
}
