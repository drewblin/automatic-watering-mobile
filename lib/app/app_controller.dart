import 'package:flutter/foundation.dart';

import '../features/controller_settings/controller_settings_save_controller.dart';
import '../features/home/home_dashboard_controller.dart';
import '../features/service_console/service_console_dependencies.dart';
import 'app_startup_service.dart';
import 'app_state.dart';
import 'app_state_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required AppStateStore stateStore,
    required AppStartupService startupService,
    required this.serviceConsoleDependencies,
    required this.settingsSaveController,
    required this.homeDashboardController,
  })  : _stateStore = stateStore,
        _startup = startupService {
    _stateStore.addListener(notifyListeners);
  }

  final AppStateStore _stateStore;
  final AppStartupService _startup;
  final ServiceConsoleDependencies serviceConsoleDependencies;
  final ControllerSettingsSaveController settingsSaveController;
  final HomeDashboardController homeDashboardController;

  AppState get state => _stateStore.state;

  Future<void> initialize() => _startup.initialize();

  @override
  void dispose() {
    _stateStore.removeListener(notifyListeners);
    serviceConsoleDependencies.bleLogsController.dispose();
    settingsSaveController.dispose();
    homeDashboardController.dispose();
    _stateStore.dispose();
    super.dispose();
  }
}
