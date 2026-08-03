import 'package:flutter/foundation.dart';

import '../features/controller_settings/controller_settings_save_controller.dart';
import 'app_startup_service.dart';
import 'app_state.dart';
import 'app_state_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required AppStateStore stateStore,
    required AppStartupService startupService,
    required this.settingsSaveController,
  })  : _stateStore = stateStore,
        _startup = startupService {
    _stateStore.addListener(notifyListeners);
  }

  final AppStateStore _stateStore;
  final AppStartupService _startup;
  final ControllerSettingsSaveController settingsSaveController;

  AppState get state => _stateStore.state;

  Future<void> initialize() => _startup.initialize();

  @override
  void dispose() {
    _stateStore.removeListener(notifyListeners);
    settingsSaveController.dispose();
    _stateStore.dispose();
    super.dispose();
  }
}
