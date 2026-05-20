import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

/// Cubit managing the active application [Locale].
///
/// Persists the user's choice in [SharedPreferences] and synchronizes
/// active language context with [ApiClient] headers in real-time.
class LanguageCubit extends Cubit<Locale> {
  static const String _prefsKey = 'user_preferred_language';
  final SharedPreferences _prefs;
  final ApiClient _apiClient;

  LanguageCubit({
    required SharedPreferences prefs,
    required ApiClient apiClient,
    required String defaultLanguage,
  })  : _prefs = prefs,
        _apiClient = apiClient,
        super(Locale(() {
          final savedCountry = prefs.getString('user_preferred_country');
          if (savedCountry == 'TH') {
            return 'en';
          }
          return prefs.getString(_prefsKey) ?? defaultLanguage;
        }())) {
    // Synchronize network client header on startup
    _apiClient.setLanguage(state.languageCode);
  }

  /// Change application language dynamically and persist the choice.
  Future<void> switchLanguage(String languageCode) async {
    final activeCountry = _prefs.getString('user_preferred_country');
    final targetLang = activeCountry == 'TH' ? 'en' : languageCode;
    if (targetLang == state.languageCode) return;
    
    await _prefs.setString(_prefsKey, targetLang);
    _apiClient.setLanguage(targetLang);
    emit(Locale(targetLang));
  }
}
