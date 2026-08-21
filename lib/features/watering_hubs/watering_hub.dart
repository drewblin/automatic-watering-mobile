import '../../core/json_helpers.dart';

class WateringHub {
  const WateringHub({
    required this.id,
    required this.displayName,
    required this.bleDeviceId,
    required this.lastKnownIpAddress,
    required this.lastKnownHostname,
    required this.apiAccessToken,
    required this.serverDeviceId,
    required this.onboardingCompletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final String bleDeviceId;
  final String? lastKnownIpAddress;
  final String lastKnownHostname;
  final String? apiAccessToken;
  final String? serverDeviceId;
  final DateTime? onboardingCompletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOnboardingComplete => onboardingCompletedAt != null;

  ReadyWateringHubAccess? get readyAccess {
    final token = apiAccessToken;
    final ipAddress = lastKnownIpAddress;
    if (token == null || ipAddress == null) {
      return null;
    }
    return ReadyWateringHubAccess(
      hub: this,
      host: ipAddress,
      apiAccessToken: token,
    );
  }

  factory WateringHub.fromJson(Map<String, Object?> json) {
    return WateringHub(
      id: readString(json['id'], 'id'),
      displayName: readString(json['displayName'], 'displayName'),
      bleDeviceId: readString(json['bleDeviceId'], 'bleDeviceId'),
      lastKnownIpAddress: json['lastKnownIpAddress'] as String?,
      lastKnownHostname:
          readString(json['lastKnownHostname'], 'lastKnownHostname'),
      apiAccessToken: null,
      serverDeviceId: json['serverDeviceId'] as String?,
      onboardingCompletedAt: json['onboardingCompletedAt'] == null
          ? null
          : readDateTime(
              json['onboardingCompletedAt'], 'onboardingCompletedAt'),
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
      'lastKnownHostname': lastKnownHostname,
      'serverDeviceId': serverDeviceId,
      'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  WateringHub copyWith({
    String? id,
    String? displayName,
    String? bleDeviceId,
    String? lastKnownIpAddress,
    String? lastKnownHostname,
    String? apiAccessToken,
    String? serverDeviceId,
    DateTime? onboardingCompletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearApiAccessToken = false,
  }) {
    return WateringHub(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      bleDeviceId: bleDeviceId ?? this.bleDeviceId,
      lastKnownIpAddress: lastKnownIpAddress ?? this.lastKnownIpAddress,
      lastKnownHostname: lastKnownHostname ?? this.lastKnownHostname,
      apiAccessToken:
          clearApiAccessToken ? null : apiAccessToken ?? this.apiAccessToken,
      serverDeviceId: serverDeviceId ?? this.serverDeviceId,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ReadyWateringHubAccess {
  const ReadyWateringHubAccess({
    required this.hub,
    required this.host,
    required this.apiAccessToken,
  });

  final WateringHub hub;
  final String host;
  final String apiAccessToken;

  String get ipAddress => host;

  String get wateringHubId => hub.id;
}
