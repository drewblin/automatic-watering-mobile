import '../../core/json_helpers.dart';

class NormalizedPoint {
  const NormalizedPoint({required this.x, required this.y});

  final double x;
  final double y;

  factory NormalizedPoint.fromJson(Map<String, Object?> json) {
    return NormalizedPoint(
      x: readDouble(json['x'], 'x'),
      y: readDouble(json['y'], 'y'),
    );
  }

  Map<String, Object?> toJson() => {'x': x, 'y': y};
}

class CanvasSize {
  const CanvasSize({required this.width, required this.height});

  final double width;
  final double height;

  factory CanvasSize.normalized() => const CanvasSize(width: 1, height: 1);

  factory CanvasSize.fromJson(Map<String, Object?> json) {
    return CanvasSize(
      width: readDouble(json['width'], 'width'),
      height: readDouble(json['height'], 'height'),
    );
  }

  Map<String, Object?> toJson() => {'width': width, 'height': height};
}

class ElementStyle {
  const ElementStyle({
    this.fillColor,
    this.strokeColor,
    this.icon,
    this.markerType,
  });

  final String? fillColor;
  final String? strokeColor;
  final String? icon;
  final String? markerType;

  factory ElementStyle.fromJson(Map<String, Object?> json) {
    return ElementStyle(
      fillColor: json['fillColor'] as String?,
      strokeColor: json['strokeColor'] as String?,
      icon: json['icon'] as String?,
      markerType: json['markerType'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'fillColor': fillColor,
        'strokeColor': strokeColor,
        'icon': icon,
        'markerType': markerType,
      };
}

class ZoneShapeElement {
  const ZoneShapeElement({
    required this.id,
    required this.points,
    required this.deviceObjectId,
    required this.style,
  });

  final String id;
  final List<NormalizedPoint> points;
  final String deviceObjectId;
  final ElementStyle style;

  factory ZoneShapeElement.fromJson(Map<String, Object?> json) {
    return ZoneShapeElement(
      id: readString(json['id'], 'id'),
      points: readList(
        json['points'],
        'points',
        (item) => NormalizedPoint.fromJson(readObject(item, 'points[]')),
      ),
      deviceObjectId: readString(json['deviceObjectId'], 'deviceObjectId'),
      style: ElementStyle.fromJson(readObject(json['style'], 'style')),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'points': points.map((point) => point.toJson()).toList(),
        'deviceObjectId': deviceObjectId,
        'style': style.toJson(),
      };
}

enum LandmarkElementType {
  building,
  landmark;

  static LandmarkElementType fromJson(Object? value) {
    if (value is String) {
      return LandmarkElementType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => LandmarkElementType.landmark,
      );
    }
    throw const FormatException('Missing or invalid landmark type');
  }

  String toJson() => name;
}

class PlanGeometry {
  const PlanGeometry._({required this.polygon, required this.position});

  final List<NormalizedPoint>? polygon;
  final NormalizedPoint? position;

  factory PlanGeometry.polygon(List<NormalizedPoint> points) {
    return PlanGeometry._(
      polygon: List<NormalizedPoint>.unmodifiable(points),
      position: null,
    );
  }

  factory PlanGeometry.position(NormalizedPoint point) {
    return PlanGeometry._(polygon: null, position: point);
  }

  factory PlanGeometry.fromJson(Map<String, Object?> json) {
    if (json['polygon'] != null) {
      return PlanGeometry.polygon(
        readList(
          json['polygon'],
          'polygon',
          (item) => NormalizedPoint.fromJson(readObject(item, 'polygon[]')),
        ),
      );
    }
    if (json['position'] != null) {
      return PlanGeometry.position(
        NormalizedPoint.fromJson(readObject(json['position'], 'position')),
      );
    }
    throw const FormatException('Plan geometry must have polygon or position');
  }

  Map<String, Object?> toJson() => {
        'polygon': polygon?.map((point) => point.toJson()).toList(),
        'position': position?.toJson(),
      };
}

class LandmarkElement {
  const LandmarkElement({
    required this.id,
    required this.type,
    required this.label,
    required this.geometry,
    required this.style,
  });

  final String id;
  final LandmarkElementType type;
  final String? label;
  final PlanGeometry geometry;
  final ElementStyle style;

  factory LandmarkElement.fromJson(Map<String, Object?> json) {
    return LandmarkElement(
      id: readString(json['id'], 'id'),
      type: LandmarkElementType.fromJson(json['type']),
      label: json['label'] as String?,
      geometry: PlanGeometry.fromJson(readObject(json['geometry'], 'geometry')),
      style: ElementStyle.fromJson(readObject(json['style'], 'style')),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.toJson(),
        'label': label,
        'geometry': geometry.toJson(),
        'style': style.toJson(),
      };
}

class DeviceObjectMarker {
  const DeviceObjectMarker({
    required this.id,
    required this.position,
    required this.deviceObjectId,
    required this.style,
  });

  final String id;
  final NormalizedPoint position;
  final String deviceObjectId;
  final ElementStyle style;

  factory DeviceObjectMarker.fromJson(Map<String, Object?> json) {
    return DeviceObjectMarker(
      id: readString(json['id'], 'id'),
      position: NormalizedPoint.fromJson(
        readObject(json['position'], 'position'),
      ),
      deviceObjectId: readString(json['deviceObjectId'], 'deviceObjectId'),
      style: ElementStyle.fromJson(readObject(json['style'], 'style')),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'position': position.toJson(),
        'deviceObjectId': deviceObjectId,
        'style': style.toJson(),
      };
}

class PlanSchema {
  const PlanSchema({
    required this.id,
    required this.wateringHubId,
    required this.version,
    required this.canvasSize,
    required this.zoneShapes,
    required this.landmarks,
    required this.deviceMarkers,
  });

  final String id;
  final String wateringHubId;
  final int version;
  final CanvasSize canvasSize;
  final List<ZoneShapeElement> zoneShapes;
  final List<LandmarkElement> landmarks;
  final List<DeviceObjectMarker> deviceMarkers;

  factory PlanSchema.empty({
    required String id,
    required String wateringHubId,
  }) {
    return PlanSchema(
      id: id,
      wateringHubId: wateringHubId,
      version: 1,
      canvasSize: CanvasSize.normalized(),
      zoneShapes: const [],
      landmarks: const [],
      deviceMarkers: const [],
    );
  }

  factory PlanSchema.fromJson(Map<String, Object?> json) {
    return PlanSchema(
      id: readString(json['id'], 'id'),
      wateringHubId: readString(json['wateringHubId'], 'wateringHubId'),
      version: readInt(json['version'], 'version'),
      canvasSize: CanvasSize.fromJson(
        readObject(json['canvasSize'], 'canvasSize'),
      ),
      zoneShapes: readList(
        json['zoneShapes'],
        'zoneShapes',
        (item) => ZoneShapeElement.fromJson(readObject(item, 'zoneShapes[]')),
      ),
      landmarks: readList(
        json['landmarks'],
        'landmarks',
        (item) => LandmarkElement.fromJson(readObject(item, 'landmarks[]')),
      ),
      deviceMarkers: readList(
        json['deviceMarkers'],
        'deviceMarkers',
        (item) =>
            DeviceObjectMarker.fromJson(readObject(item, 'deviceMarkers[]')),
      ),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'wateringHubId': wateringHubId,
        'version': version,
        'canvasSize': canvasSize.toJson(),
        'zoneShapes': zoneShapes.map((shape) => shape.toJson()).toList(),
        'landmarks': landmarks.map((landmark) => landmark.toJson()).toList(),
        'deviceMarkers':
            deviceMarkers.map((marker) => marker.toJson()).toList(),
      };
}
