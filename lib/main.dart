import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_state.dart';
import 'app/automatic_watering_app.dart';
import 'storage/local_watering_hub_storage.dart';
import 'storage/secure_watering_hub_token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final appController = AppController(
    wateringHubStorage: SharedPreferencesWateringHubStorage(preferences),
    tokenStorage: const SecureWateringHubTokenStorage(FlutterSecureStorage()),
  );

  runApp(AutomaticWateringApp(appController: appController));
}
