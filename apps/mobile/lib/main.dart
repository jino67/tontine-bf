import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'core/api/api_client.dart';
import 'core/session/session_controller.dart';
import 'core/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Les polices sont embarquées dans assets/google_fonts : l'app n'a pas besoin de réseau pour les afficher.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(_fontLicenses);

  await initializeDateFormatting('fr');

  final session = SessionController(
    api: ApiClient(baseUrl: AppConfig.apiUrl),
    store: DeviceSessionStore(),
  );

  runApp(TontineApp(session: session));
  unawaited(session.restore());
}

Stream<LicenseEntry> _fontLicenses() async* {
  yield LicenseEntryWithLineBreaks(
    ['Young Serif'],
    await rootBundle.loadString('assets/google_fonts/OFL-YoungSerif.txt'),
  );
  yield LicenseEntryWithLineBreaks(
    ['Atkinson Hyperlegible'],
    await rootBundle.loadString('assets/google_fonts/OFL-AtkinsonHyperlegible.txt'),
  );
}
