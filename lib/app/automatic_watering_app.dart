import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/onboarding/ble_onboarding_controller.dart';
import 'app_controller.dart';
import 'fatal_error_screen.dart';

class AutomaticWateringApp extends StatefulWidget {
  const AutomaticWateringApp({
    required this.appController,
    required this.bleOnboardingController,
    this.fatalErrorListenable,
    super.key,
  });

  final AppController appController;
  final BleOnboardingController bleOnboardingController;
  final ValueNotifier<Object?>? fatalErrorListenable;

  @override
  State<AutomaticWateringApp> createState() => _AutomaticWateringAppState();
}

class _AutomaticWateringAppState extends State<AutomaticWateringApp> {
  Object? _fatalError;

  @override
  void initState() {
    super.initState();
    widget.fatalErrorListenable?.addListener(_handleExternalFatalError);
    _initialize();
  }

  @override
  void didUpdateWidget(AutomaticWateringApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fatalErrorListenable != oldWidget.fatalErrorListenable) {
      oldWidget.fatalErrorListenable?.removeListener(_handleExternalFatalError);
      widget.fatalErrorListenable?.addListener(_handleExternalFatalError);
      _handleExternalFatalError();
    }
    if (widget.appController != oldWidget.appController) {
      _initialize();
    }
  }

  @override
  void dispose() {
    widget.fatalErrorListenable?.removeListener(_handleExternalFatalError);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await widget.appController.initialize();
      if (mounted && _fatalError != null) {
        setState(() {
          _fatalError = null;
        });
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      if (mounted) {
        setState(() {
          _fatalError = error;
        });
      }
    }
  }

  Future<void> _retryInitialize() async {
    widget.fatalErrorListenable?.value = null;
    if (mounted) {
      setState(() {
        _fatalError = null;
      });
    }
    await _initialize();
  }

  void _restartOnboarding() {
    // todo реалізувати повторний onboarding для вже доданого контролера.
  }

  void _handleExternalFatalError() {
    final error = widget.fatalErrorListenable?.value;
    if (error == null || !mounted) {
      return;
    }
    setState(() {
      _fatalError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Автоматичний полив',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: widget.appController,
        builder: (context, _) {
          final fatalError = _fatalError;
          if (fatalError != null) {
            return FatalErrorScreen(
              error: fatalError,
              onRetry: _retryInitialize,
              onRestartOnboarding: _restartOnboarding,
            );
          }
          return HomeScreen(
            state: widget.appController.state,
            onOnboardingComplete: _initialize,
            bleOnboardingController: widget.bleOnboardingController,
            settingsSaveController:
                widget.appController.settingsSaveController,
          );
        },
      ),
    );
  }
}
