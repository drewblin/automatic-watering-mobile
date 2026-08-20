import 'package:flutter/material.dart';

import 'ble_controller_logs_controller.dart';

class BleLogsTab extends StatefulWidget {
  const BleLogsTab({
    required this.controller,
    super.key,
  });

  final BleControllerLogsController controller;

  @override
  State<BleLogsTab> createState() => _BleLogsTabState();
}

class _BleLogsTabState extends State<BleLogsTab> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(BleLogsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Column(
      children: [
        _BleLogsActions(
          state: state,
          onConnect: widget.controller.connect,
          onDisconnect: widget.controller.disconnect,
          onClear: widget.controller.clear,
        ),
        _BleLogsStatus(state: state),
        Expanded(
          child: _BleLogsList(records: state.records),
        ),
      ],
    );
  }
}

class _BleLogsActions extends StatelessWidget {
  const _BleLogsActions({
    required this.state,
    required this.onConnect,
    required this.onDisconnect,
    required this.onClear,
  });

  final BleControllerLogsState state;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Підключитися',
              onPressed: state.canConnect ? onConnect : null,
              icon: const Icon(Icons.bluetooth_connected),
            ),
            IconButton(
              tooltip: 'Відключитися',
              onPressed: state.canDisconnect ? onDisconnect : null,
              icon: const Icon(Icons.bluetooth_disabled),
            ),
            IconButton(
              tooltip: 'Очистити',
              onPressed: state.canClear ? onClear : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _BleLogsStatus extends StatelessWidget {
  const _BleLogsStatus({required this.state});

  final BleControllerLogsState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final userMessage = state.userMessage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: 'BLE',
              value: _connectionLabel(state.connectionState),
            ),
            _StatusChip(
              label: 'Сповіщення',
              value: _subscriptionLabel(state.subscriptionState),
            ),
            if (state.deviceId case final deviceId?)
              _StatusChip(label: 'BLE ID', value: deviceId),
            if (userMessage != null && userMessage.isNotEmpty)
              Text(
                userMessage,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _BleLogsList extends StatelessWidget {
  const _BleLogsList({required this.records});

  final List<BleControllerLogRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('BLE логів немає.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _BleLogRecordView(record: records[index]);
      },
    );
  }
}

class _BleLogRecordView extends StatelessWidget {
  const _BleLogRecordView({required this.record});

  final BleControllerLogRecord record;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDateTime(record.receivedAt),
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            SelectableText(
              record.message,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _connectionLabel(BleControllerLogsConnectionState state) {
  return switch (state) {
    BleControllerLogsConnectionState.idle => 'не підключено',
    BleControllerLogsConnectionState.noActiveController =>
      'контролер не налаштовано',
    BleControllerLogsConnectionState.missingBleDeviceId => 'BLE ID відсутній',
    BleControllerLogsConnectionState.connecting => 'підключення',
    BleControllerLogsConnectionState.connected => 'підключено',
    BleControllerLogsConnectionState.connectionFailed => 'помилка підключення',
    BleControllerLogsConnectionState.disconnected => 'відключено',
  };
}

String _subscriptionLabel(BleControllerLogsSubscriptionState state) {
  return switch (state) {
    BleControllerLogsSubscriptionState.idle => 'немає підписки',
    BleControllerLogsSubscriptionState.subscribing => 'підписка',
    BleControllerLogsSubscriptionState.subscribed => 'підписано',
    BleControllerLogsSubscriptionState.failed => 'помилка підписки',
  };
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute:$second';
}
