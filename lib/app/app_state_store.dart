import 'package:flutter/foundation.dart';

import '../features/watering_hubs/watering_hub_state.dart';
import 'app_state.dart';

class AppStateStore extends ChangeNotifier {
  AppStateStore()
      : _state = AppState.loading(
          activeWateringHub: null,
          connectionState: WateringHubConnectionState.noDevice,
        );

  AppState _state;

  AppState get state => _state;

  void setState(AppState state) {
    _state = state;
    notifyListeners();
  }

  // todo прибрати
  void update(AppState Function(AppState state) updateState) {
    setState(updateState(_state));
  }
}
