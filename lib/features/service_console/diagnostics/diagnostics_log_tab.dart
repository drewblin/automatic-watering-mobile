import 'package:flutter/material.dart';

import '../../diagnostics/diagnostics_log.dart';

class DiagnosticsLogTab extends StatefulWidget {
  const DiagnosticsLogTab({
    required this.diagnosticsLog,
    super.key,
  });

  final DiagnosticsLog diagnosticsLog;

  @override
  State<DiagnosticsLogTab> createState() => _DiagnosticsLogTabState();
}

class _DiagnosticsLogTabState extends State<DiagnosticsLogTab> {
  List<DiagnosticsLogEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _entries = widget.diagnosticsLog.entries;
    });
  }

  Future<void> _confirmClear() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистити діагностичний лог?'),
        content: const Text(
          'Ця дія видалить поточні діагностичні записи. Відновити їх не вдасться.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистити'),
          ),
        ],
      ),
    );
    if (shouldClear != true || !mounted) {
      return;
    }
    widget.diagnosticsLog.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          _DiagnosticsActions(
            isClearEnabled: _entries.isNotEmpty,
            onRefresh: _refresh,
            onClear: _confirmClear,
          ),
          Expanded(
            child: _DiagnosticsLogList(entries: _entries),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsActions extends StatelessWidget {
  const _DiagnosticsActions({
    required this.isClearEnabled,
    required this.onRefresh,
    required this.onClear,
  });

  final bool isClearEnabled;
  final VoidCallback onRefresh;
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
              tooltip: 'Оновити',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Очистити',
              onPressed: isClearEnabled ? onClear : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsLogList extends StatelessWidget {
  const _DiagnosticsLogList({required this.entries});

  final List<DiagnosticsLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('Діагностичних записів немає.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _DiagnosticsLogEntryView(entry: entries[index]);
      },
    );
  }
}

class _DiagnosticsLogEntryView extends StatelessWidget {
  const _DiagnosticsLogEntryView({required this.entry});

  final DiagnosticsLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final metadata = <Widget>[
      _LogField(label: 'Час', value: _formatDateTime(entry.occurredAt)),
      _LogField(label: 'Метод', value: entry.method),
      _LogField(label: 'Хост', value: entry.host),
      _LogField(label: 'Шлях', value: entry.path),
      _LogField(label: 'HTTP статус', value: entry.statusCode?.toString()),
      _LogField(label: 'Клас помилки', value: entry.exceptionType),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.message,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: metadata,
            ),
            _ExpandableTextField(
              label: 'Тіло відповіді',
              value: entry.responseBody,
            ),
            _ExpandableTextField(
              label: 'Деталі',
              value: entry.details,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogField extends StatelessWidget {
  const _LogField({
    required this.label,
    required this.value,
  });

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: text),
          ],
        ),
        overflow: TextOverflow.visible,
        style: textTheme.bodySmall,
      ),
    );
  }
}

class _ExpandableTextField extends StatelessWidget {
  const _ExpandableTextField({
    required this.label,
    required this.value,
  });

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(label),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
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
