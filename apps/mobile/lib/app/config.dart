import 'package:flutter/foundation.dart';

/// Configuration fournie à la compilation :
/// flutter build apk --dart-define=API_URL=https://api.exemple.bf/api/v1
abstract final class AppConfig {
  static const appName = 'Tontine BF';
  static const version = '0.2.0';

  static const _apiUrl = String.fromEnvironment('API_URL');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  /// Sans API_URL, l'app vise l'API locale. 10.0.2.2 désigne l'ordinateur hôte vu depuis l'émulateur Android.
  static String get apiUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;
    return kIsWeb ? 'http://localhost:8000/api/v1' : 'http://10.0.2.2:8000/api/v1';
  }
}
