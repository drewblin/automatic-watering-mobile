import 'package:flutter/foundation.dart';

import 'app_startup_service.dart';
import 'app_state.dart';
import 'app_state_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required AppStateStore stateStore,
    required AppStartupService startupService,
  })  : _stateStore = stateStore,
        _startup = startupService {
    _stateStore.addListener(notifyListeners);
  }

  final AppStateStore _stateStore;
  final AppStartupService _startup;

  AppState get state => _stateStore.state;

  Future<void> initialize() => _startup.initialize();

  @override
  void dispose() {
    _stateStore.removeListener(notifyListeners);
    _stateStore.dispose();
    super.dispose();
  }
}
