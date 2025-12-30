import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/screens/auth/login_screen.dart';
import 'package:app_tontine_bf/screens/home/main_navigation.dart';
import 'package:app_tontine_bf/services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  late Future<bool> _isLoggedInFuture;

  @override
  void initState() {
    super.initState();
    _isLoggedInFuture = _authService.isLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tontine BF',
      theme: tontineTheme,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: _isLoggedInFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen();
          }

          if (snapshot.hasData && snapshot.data == true) {
            return const MainNavigation();
          } else {
            return const LoginScreen();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainNavigation(),
      },
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: tontinePrimaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de l'application
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: tontineWhite,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.people_alt_rounded,
                size: 60,
                color: tontinePrimaryColor,
              ),
            ),
            const SizedBox(height: 30),

            // Nom de l'application
            Text(
              'TONTINE BF',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: tontineWhite,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),

            // Slogan
            Text(
              'Solidarité • Épargne • Cagnottes',
              style: TextStyle(
                fontSize: 16,
                color: tontineWhite.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 50),

            // Indicateur de chargement
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),

            // Message de chargement
            Text(
              'Chargement...',
              style: TextStyle(
                color: tontineWhite.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}