import 'package:flutter/foundation.dart';

import 'ble_onboarding_state.dart';

class BleOnboardingStateStore extends ChangeNotifier {
  BleOnboardingStateStore() : _state = const CheckingBluetooth();

  BleOnboardingState _state;
  bool _isClosed = false;

  BleOnboardingState get state => _state;

  void setState(BleOnboardingState state) {
    if (_isClosed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  void close() {
    _isClosed = true;
  }
}
