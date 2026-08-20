import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../ble/ble_constants.dart';
import '../../ble/ble_models.dart';
import '../../ble/ble_service.dart';
import '../../diagnostics/diagnostics_log.dart';
import '../../watering_hubs/watering_hub.dart';

typedef Clock = DateTime Function();

abstract interface class ActiveWateringHubListenable implements Listenable {
  WateringHub? get activeWateringHub;
}

enum BleControllerLogsConnectionState {
  idle,
  noActiveController,
  missingBleDeviceId,
  connecting,
  connected,
  connectionFailed,
  disconnected,
}

enum BleControllerLogsSubscriptionState {
  idle,
  subscribing,
  subscribed,
  failed,
}

@immutable
class BleControllerLogRecord {
  const BleControllerLogRecord({
    required this.receivedAt,
    required this.message,
  });

  final DateTime receivedAt;
  final String message;
}

@immutable
class BleControllerLogsState {
  const BleControllerLogsState({
    required this.connectionState,
    required this.subscriptionState,
    required this.records,
    this.deviceId,
    this.userMessage,
  });

  factory BleControllerLogsState.initial() {
    return const BleControllerLogsState(
      connectionState: BleControllerLogsConnectionState.idle,
      subscriptionState: BleControllerLogsSubscriptionState.idle,
      records: [],
    );
  }

  final BleControllerLogsConnectionState connectionState;
  final BleControllerLogsSubscriptionState subscriptionState;
  final List<BleControllerLogRecord> records;
  final String? deviceId;
  final String? userMessage;

  bool get canConnect {
    return connectionState != BleControllerLogsConnectionState.connecting &&
        connectionState != BleControllerLogsConnectionState.connected;
  }

  bool get canDisconnect {
    return connectionState == BleControllerLogsConnectionState.connected ||
        connectionState == BleControllerLogsConnectionState.connecting;
  }

  bool get canClear => records.isNotEmpty;

  BleControllerLogsState copyWith({
    BleControllerLogsConnectionState? connectionState,
    BleControllerLogsSubscriptionState? subscriptionState,
    List<BleControllerLogRecord>? records,
    String? deviceId,
    String? userMessage,
    bool clearDeviceId = false,
    bool clearUserMessage = false,
  }) {
    return BleControllerLogsState(
      connectionState: connectionState ?? this.connectionState,
      subscriptionState: subscriptionState ?? this.subscriptionState,
      records: List.unmodifiable(records ?? this.records),
      deviceId: clearDeviceId ? null : deviceId ?? this.deviceId,
      userMessage: clearUserMessage ? null : userMessage ?? this.userMessage,
    );
  }
}

class BleControllerLogsController extends ChangeNotifier {
  BleControllerLogsController({
    required BleService bleService,
    required DiagnosticsLog diagnosticsLog,
    required ActiveWateringHubListenable activeWateringHubListenable,
    Clock? clock,
    this.maxRecords = 200,
    this.reconnectDelay = const Duration(seconds: 5),
    this.autoReconnect = true,
  })  : assert(maxRecords > 0),
        _bleService = bleService,
        _diagnosticsLog = diagnosticsLog,
        _activeWateringHubListenable = activeWateringHubListenable,
        _clock = clock ?? (() => DateTime.now().toUtc()) {
    _activeWateringHubListenable.addListener(_handleActiveWateringHubChanged);
    unawaited(syncWithActiveController());
  }

  final BleService _bleService;
  final DiagnosticsLog _diagnosticsLog;
  final ActiveWateringHubListenable _activeWateringHubListenable;
  final Clock _clock;
  final int maxRecords;
  final Duration reconnectDelay;
  final bool autoReconnect;
  StreamSubscription<List<int>>? _logSubscription;
  String? _connectedDeviceId;
  String? _targetDeviceId;
  String _lineBuffer = '';
  int _connectionAttempt = 0;
  bool _isDisposed = false;
  Future<void>? _syncFuture;

  BleControllerLogsState _state = BleControllerLogsState.initial();

  BleControllerLogsState get state => _state;

  void _handleActiveWateringHubChanged() {
    unawaited(syncWithActiveController());
  }

  Future<void> syncWithActiveController() {
    final currentSync = _syncFuture;
    if (currentSync != null) {
      return currentSync;
    }

    final sync = _syncWithActiveController();
    _syncFuture = sync;
    return sync.whenComplete(() {
      if (identical(_syncFuture, sync)) {
        _syncFuture = null;
      }
    });
  }

  Future<void> _syncWithActiveController() async {
    final attempt = ++_connectionAttempt;
    final hub = _activeWateringHubListenable.activeWateringHub;
    if (hub == null) {
      await _stopListening();
      _setState(
        _state.copyWith(
          connectionState: BleControllerLogsConnectionState.noActiveController,
          subscriptionState: BleControllerLogsSubscriptionState.idle,
          clearDeviceId: true,
          userMessage:
              'Активний контролер ще не налаштовано. Завершіть onboarding, щоб читати BLE логи.',
        ),
      );
      return;
    }

    final deviceId = hub.bleDeviceId.trim();
    if (deviceId.isEmpty) {
      await _stopListening();
      _setState(
        _state.copyWith(
          connectionState: BleControllerLogsConnectionState.missingBleDeviceId,
          subscriptionState: BleControllerLogsSubscriptionState.idle,
          clearDeviceId: true,
          userMessage: 'BLE ID відсутній.',
        ),
      );
      return;
    }

    if (_targetDeviceId == deviceId &&
        (state.connectionState == BleControllerLogsConnectionState.connecting ||
            state.connectionState ==
                BleControllerLogsConnectionState.connected) &&
        state.subscriptionState != BleControllerLogsSubscriptionState.failed) {
      return;
    }

    _targetDeviceId = deviceId;
    _setState(
      _state.copyWith(
        connectionState: BleControllerLogsConnectionState.connecting,
        subscriptionState: BleControllerLogsSubscriptionState.idle,
        deviceId: deviceId,
        clearUserMessage: true,
      ),
    );
    await _cancelSubscription();
    if (_connectedDeviceId != null && _connectedDeviceId != deviceId) {
      await _disconnectDevice(_connectedDeviceId!);
      _connectedDeviceId = null;
    }

    final device = BleDiscoveredDevice(
      id: deviceId,
      name: hub.displayName,
      rssi: null,
      isLikelyAutomaticWateringHub: true,
      advertisedServiceUuids: const {
        AutomaticWateringBleConstants.serviceUuid,
      },
    );

    try {
      await _bleService.reconnect(device);
      if (_isDisposed || attempt != _connectionAttempt) {
        await _disconnectDevice(deviceId);
        return;
      }
      _connectedDeviceId = deviceId;
      _setState(
        _state.copyWith(
          connectionState: BleControllerLogsConnectionState.connected,
          subscriptionState: BleControllerLogsSubscriptionState.subscribing,
          deviceId: deviceId,
          clearUserMessage: true,
        ),
      );
      await _subscribe(deviceId, attempt);
    } catch (error) {
      _connectedDeviceId = null;
      recordDiagnosticsIssue(
        diagnosticsLog: _diagnosticsLog,
        message: 'Не вдалося підключитися до BLE логів контролера.',
        error: error,
      );
      _setState(
        _state.copyWith(
          connectionState: BleControllerLogsConnectionState.connectionFailed,
          subscriptionState: BleControllerLogsSubscriptionState.idle,
          userMessage: 'Не вдалося підключитися.',
        ),
      );
    }
  }

  Future<void> disconnect() async {
    _connectionAttempt += 1;
    await _stopListening();
    _setState(
      _state.copyWith(
        connectionState: BleControllerLogsConnectionState.idle,
        subscriptionState: BleControllerLogsSubscriptionState.idle,
        clearDeviceId: true,
        clearUserMessage: true,
      ),
    );
  }

  void clear() {
    _setState(_state.copyWith(records: const []));
  }

  Future<void> connect() {
    return syncWithActiveController();
  }

  Future<void> _subscribe(String deviceId, int attempt) async {
    if (_isDisposed || attempt != _connectionAttempt) {
      return;
    }
    try {
      _logSubscription =
          _bleService.subscribeToLogNotifications(deviceId).listen(
        _handlePayload,
        onError: (Object error) {
          if (_isDisposed || attempt != _connectionAttempt) {
            return;
          }
          _connectedDeviceId = null;
          recordDiagnosticsIssue(
            diagnosticsLog: _diagnosticsLog,
            message: 'Не вдалося отримувати BLE логи контролера.',
            error: error,
          );
          _setState(
            _state.copyWith(
              connectionState: BleControllerLogsConnectionState.disconnected,
              subscriptionState: BleControllerLogsSubscriptionState.failed,
              userMessage: 'Контролер відключився.',
            ),
          );
          unawaited(_retryCurrentTarget(attempt));
        },
        onDone: () {
          if (_isDisposed || attempt != _connectionAttempt) {
            return;
          }
          _connectedDeviceId = null;
          _setState(
            _state.copyWith(
              connectionState: BleControllerLogsConnectionState.disconnected,
              subscriptionState: BleControllerLogsSubscriptionState.idle,
              userMessage: 'Контролер відключився.',
            ),
          );
          unawaited(_retryCurrentTarget(attempt));
        },
      );
      if (_isDisposed || attempt != _connectionAttempt) {
        await _cancelSubscription();
        return;
      }
      _setState(
        _state.copyWith(
          subscriptionState: BleControllerLogsSubscriptionState.subscribed,
          clearUserMessage: true,
        ),
      );
    } catch (error) {
      if (_isDisposed || attempt != _connectionAttempt) {
        return;
      }
      recordDiagnosticsIssue(
        diagnosticsLog: _diagnosticsLog,
        message: 'Не вдалося підписатися на BLE notifications логів.',
        error: error,
      );
      await _disconnectDevice(deviceId);
      _connectedDeviceId = null;
      _setState(
        _state.copyWith(
          connectionState: BleControllerLogsConnectionState.disconnected,
          subscriptionState: BleControllerLogsSubscriptionState.failed,
          userMessage: 'Не вдалося підписатися на сповіщення.',
        ),
      );
      unawaited(_retryCurrentTarget(attempt));
    }
  }

  Future<void> _retryCurrentTarget(int failedAttempt) async {
    if (!autoReconnect || _isDisposed || failedAttempt != _connectionAttempt) {
      return;
    }
    if (reconnectDelay > Duration.zero) {
      await Future<void>.delayed(reconnectDelay);
    }
    if (_isDisposed || failedAttempt != _connectionAttempt) {
      return;
    }
    await syncWithActiveController();
  }

  void _handlePayload(List<int> payload) {
    if (_isDisposed) {
      return;
    }
    String decoded;
    try {
      decoded = const Utf8Decoder(allowMalformed: false).convert(payload);
    } catch (error) {
      recordDiagnosticsIssue(
        diagnosticsLog: _diagnosticsLog,
        message: 'Отримано неочікуваний payload BLE логів.',
        error: error,
        details: payload.toString(),
      );
      _setState(
        _state.copyWith(userMessage: 'Отримано неочікуваний payload.'),
      );
      return;
    }

    _lineBuffer += decoded;
    final lines = _lineBuffer.split('\n');
    _lineBuffer = lines.removeLast();

    for (final rawLine in lines) {
      final message = rawLine.trim();
      if (message.isEmpty) {
        continue;
      }
      _appendRecord(message);
    }
  }

  void _appendRecord(String message) {
    final records = [
      BleControllerLogRecord(receivedAt: _clock(), message: message),
      ..._state.records,
    ];
    if (records.length > maxRecords) {
      records.removeRange(maxRecords, records.length);
    }
    _setState(
      _state.copyWith(
        records: records,
        clearUserMessage: true,
      ),
    );
  }

  Future<void> _cancelSubscription() async {
    await _logSubscription?.cancel();
    _logSubscription = null;
  }

  Future<void> _stopListening() async {
    await _cancelSubscription();
    final deviceId = _connectedDeviceId ?? _targetDeviceId;
    _connectedDeviceId = null;
    _targetDeviceId = null;
    _lineBuffer = '';
    if (deviceId != null) {
      await _disconnectDevice(deviceId);
    }
  }

  Future<void> _disconnectDevice(String deviceId) async {
    try {
      await _bleService.disconnect(deviceId);
    } catch (error) {
      recordDiagnosticsIssue(
        diagnosticsLog: _diagnosticsLog,
        message: 'Не вдалося відключитися від BLE логів контролера.',
        error: error,
      );
    }
  }

  void _setState(BleControllerLogsState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeWateringHubListenable.removeListener(
      _handleActiveWateringHubChanged,
    );
    _connectionAttempt += 1;
    final deviceId = _connectedDeviceId ?? _state.deviceId;
    _connectedDeviceId = null;
    _targetDeviceId = null;
    unawaited(_cancelSubscription());
    if (deviceId != null) {
      unawaited(_disconnectDevice(deviceId));
    }
    super.dispose();
  }
}
