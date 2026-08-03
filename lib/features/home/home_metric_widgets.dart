import 'package:flutter/material.dart';

import '../sensors/sensor_metric.dart';
import 'home_formatters.dart';

class MetricIndex {
  const MetricIndex(this.metrics);

  final List<SensorMetric> metrics;

  SensorMetric? soilHumidity(int slaveAddress) {
    return _find(SensorType.soilHumidity, slaveAddress);
  }

  SensorMetric? soilTemperature(int slaveAddress) {
    return _find(SensorType.soilTemperature, slaveAddress);
  }

  SensorMetric? pressure(int slaveAddress) {
    return _find(SensorType.pressure, slaveAddress);
  }

  SensorMetric? waterCounter(int pin) {
    return _find(SensorType.waterCounter, pin);
  }

  SensorMetric? _find(SensorType type, int sensorId) {
    for (final metric in metrics) {
      if (metric.sensorType == type && metric.sensorId == sensorId) {
        return metric;
      }
    }
    return null;
  }
}

class MetricRow extends StatelessWidget {
  const MetricRow({required this.displays, super.key});

  final List<MetricDisplay> displays;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: displays,
    );
  }
}

class MetricDisplay extends StatelessWidget {
  const MetricDisplay({
    required this.label,
    required this.metric,
    required this.suffix,
    super.key,
  });

  final String label;
  final SensorMetric? metric;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final metric = this.metric;
    final value = metric == null
        ? 'немає даних'
        : metric.value == null
            ? 'недоступно'
            : '${formatNumber(metric.value!)} $suffix';
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          if (metric != null) Text(formatDateTime(metric.timestamp)),
        ],
      ),
    );
  }
}
