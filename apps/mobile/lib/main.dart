import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'core/api/api_client.dart';
import 'core/session/session_controller.dart';
import 'core/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');

  final session = SessionController(
    api: ApiClient(baseUrl: AppConfig.apiUrl),
    store: DeviceSessionStore(),
  );

  runApp(TontineApp(session: session));
  unawaited(session.restore());
}
