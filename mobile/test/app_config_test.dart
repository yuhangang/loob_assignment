import 'package:flutter_test/flutter_test.dart';
import 'package:loob_app/core/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('AppConfig.fromEnv returns correct presets', () {
      final config = AppConfig.fromEnv(AppEnv.dev);
      expect(config.env, AppEnv.dev);
      expect(config.baseUrl, 'http://localhost:8080');
      expect(config.defaultCountryCode, 'MY');
      expect(config.defaultLanguage, 'en');
    });

    test('AppConfig.fromEnvironment fallback defaults to devMY', () {
      final config = AppConfig.fromEnvironment();
      expect(config.env, AppEnv.dev);
      expect(config.baseUrl, 'http://localhost:8080');
      expect(config.defaultCountryCode, 'MY');
      expect(config.defaultLanguage, 'en');
    });
  });
}
