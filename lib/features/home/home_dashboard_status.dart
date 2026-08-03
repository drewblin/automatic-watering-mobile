import 'package:flutter/material.dart';

import 'home_dashboard_controller.dart';
import 'home_formatters.dart';

class DashboardStatusCard extends StatelessWidget {
  const DashboardStatusCard({
    required this.hubName,
    required this.settingsSyncedAt,
    required this.controllerCurrentTime,
    required this.lastMetricsSyncedAt,
    required this.refreshStatus,
    required this.errorMessage,
    required this.onRefresh,
    super.key,
  });

  final String hubName;
  final DateTime settingsSyncedAt;
  final String controllerCurrentTime;
  final DateTime? lastMetricsSyncedAt;
  final DashboardRefreshStatus refreshStatus;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final refreshing = refreshStatus == DashboardRefreshStatus.loading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hubName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (refreshing)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Оновити стан',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Контролер доступний'),
            Text('Час контролера: $controllerCurrentTime'),
            Text('Налаштування: ${formatDateTime(settingsSyncedAt)}'),
            Text(
              'Показники: ${lastMetricsSyncedAt == null ? 'ще не оновлювались' : formatDateTime(lastMetricsSyncedAt!)}',
            ),
            if (errorMessage case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
