import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';

/// Shared bootstrap with explicit [AppConfig].
Future<void> mainWithConfig(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode as per architecture spec.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize dependency injection with the config.
  await configureDependencies(config);

  runApp(const LoobApp());
}

/// Shared bootstrap called by every flavor entry point.
Future<void> mainWithEnv(AppEnv env) async {
  await mainWithConfig(AppConfig.fromEnv(env));
}

/// Default entry point — parses configuration from Dart defines (`--dart-define` / `--dart-define-from-file`),
/// falling back to [AppEnv.devMY] if no environment parameters are set.
void main() => mainWithConfig(AppConfig.fromEnvironment());

