import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';

/// Shared bootstrap called by every flavor entry point.
Future<void> mainWithEnv(AppEnv env) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode as per architecture spec.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize dependency injection with the flavor-specific config.
  await configureDependencies(AppConfig.fromEnv(env));

  runApp(const LoobApp());
}

/// Default entry point — runs as [AppEnv.devMY].
///
/// Use the flavor-specific entry points (e.g. `main_dev_th.dart`) to target
/// a different region or environment tier.
void main() => mainWithEnv(AppEnv.devMY);

