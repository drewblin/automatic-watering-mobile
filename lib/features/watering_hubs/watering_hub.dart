import '../../core/json_helpers.dart';

class WateringHub {
  const WateringHub({
    required this.id,
    required this.displayName,
    required this.bleDeviceId,
    required this.lastKnownIpAddress,
    required this.apiAccessToken,
    required this.serverDeviceId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final String bleDeviceId;
  final String? lastKnownIpAddress;
  final String? apiAccessToken;
  final String? serverDeviceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WateringHub.fromJson(Map<String, Object?> json) {
    return WateringHub(
      id: readString(json['id'], 'id'),
      displayName: readString(json['displayName'], 'displayName'),
      bleDeviceId: readString(json['bleDeviceId'], 'bleDeviceId'),
      lastKnownIpAddress: json['lastKnownIpAddress'] as String?,
      apiAccessToken: null,
      serverDeviceId: json['serverDeviceId'] as String?,
      createdAt: readDateTime(json['createdAt'], 'createdAt'),
      updatedAt: readDateTime(json['updatedAt'], 'updatedAt'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'bleDeviceId': bleDeviceId,
      'lastKnownIpAddress': lastKnownIpAddress,
      'serverDeviceId': serverDeviceId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  WateringHub copyWith({
    String? id,
    String? displayName,
    String? bleDeviceId,
    String? lastKnownIpAddress,
    String? apiAccessToken,
    String? serverDeviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WateringHub(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      bleDeviceId: bleDeviceId ?? this.bleDeviceId,
      lastKnownIpAddress: lastKnownIpAddress ?? this.lastKnownIpAddress,
      apiAccessToken: apiAccessToken ?? this.apiAccessToken,
      serverDeviceId: serverDeviceId ?? this.serverDeviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
