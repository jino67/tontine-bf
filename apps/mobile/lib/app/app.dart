import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_scope.dart';
import '../core/widgets/brand.dart';
import '../core/widgets/ui.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/phone_screen.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/organizations/organization_picker_screen.dart';
import 'config.dart';
import 'home_shell.dart';
import 'theme.dart';

class TontineApp extends StatefulWidget {
  const TontineApp({super.key, required this.session});

  final SessionController session;

  @override
  State<TontineApp> createState() => _TontineAppState();
}

class _TontineAppState extends State<TontineApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  SessionStatus? _lastStatus;
  int? _lastOrganizationId;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Après une déconnexion ou un changement d'organisation, les écrans ouverts par-dessus n'ont plus de sens.
  void _onSessionChanged() {
    final session = widget.session;
    final organizationId = session.currentOrganization?.id;
    final leftSession = _lastStatus == SessionStatus.signedIn && session.status != SessionStatus.signedIn;
    final changedOrganization = _lastOrganizationId != null && organizationId != _lastOrganizationId;

    if (leftSession || changedOrganization) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

    _lastStatus = session.status;
    _lastOrganizationId = organizationId;
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const SessionGate(),
      ),
    );
  }
}

/// Choisit l'écran racine selon l'état de la session.
class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return switch (session.status) {
      SessionStatus.loading => const SplashScreen(),
      SessionStatus.onboarding => const OnboardingScreen(),
      SessionStatus.signedOut => const PhoneScreen(),
      SessionStatus.unreachable => Scaffold(
          body: SafeArea(
            child: MessageView(
              icon: Icons.wifi_off_rounded,
              tone: Tone.danger,
              title: 'Serveur injoignable',
              message: session.errorMessage ?? 'Vérifiez votre connexion à Internet puis réessayez.',
              action: FilledButton(onPressed: session.restore, child: const Text('Réessayer')),
            ),
          ),
        ),
      SessionStatus.signedIn when session.needsProfile => const ProfileSetupScreen(),
      SessionStatus.signedIn when session.currentOrganization == null => const OrganizationPickerScreen(),
      SessionStatus.signedIn => HomeShell(key: ValueKey(session.currentOrganization!.id)),
    };
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.leafDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 88),
            const SizedBox(height: 20),
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 140,
              child: LinearProgressIndicator(color: AppColors.gold, backgroundColor: Color(0x33FFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}
