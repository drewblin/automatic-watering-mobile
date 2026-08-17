import 'package:flutter/foundation.dart';

import '../features/service_console/ble_logs/ble_controller_logs_controller.dart';
import '../features/watering_hubs/watering_hub.dart';
import 'app_state_store.dart';

class AppStateActiveWateringHubListenable extends ChangeNotifier
    implements ActiveWateringHubListenable {
  AppStateActiveWateringHubListenable(this._stateStore)
      : _activeWateringHub = _stateStore.state.activeWateringHub {
    _stateStore.addListener(_handleStateChanged);
  }

  final AppStateStore _stateStore;
  WateringHub? _activeWateringHub;

  @override
  WateringHub? get activeWateringHub => _activeWateringHub;

  void _handleStateChanged() {
    final next = _stateStore.state.activeWateringHub;
    if (identical(next, _activeWateringHub) ||
        (next?.id == _activeWateringHub?.id &&
            next?.bleDeviceId == _activeWateringHub?.bleDeviceId)) {
      _activeWateringHub = next;
      return;
    }

    _activeWateringHub = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateStore.removeListener(_handleStateChanged);
    super.dispose();
  }
}
