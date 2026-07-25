import 'package:flutter/foundation.dart';

import 'app_state.dart';

class AppStateStore extends ChangeNotifier {
  AppStateStore() : _state = AppState.loading();

  AppState _state;

  AppState get state => _state;

  void setState(AppState state) {
    _state = state;
    notifyListeners();
  }
}
