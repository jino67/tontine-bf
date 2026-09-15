import 'package:flutter/material.dart';
import 'package:app_tontine_bf/screens/auth/login_screen.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/config/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('📝 Tentative d\'inscription avec: ${_phoneController.text}');

      await _authService.register(
        fullName: _fullNameController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inscription réussie ! Vous pouvez vous connecter.'),
          backgroundColor: tontineAccentDark,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );

    } catch (e) {
      if (!mounted) return;

      print('❌ Erreur d\'inscription: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: tontinePrimaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tontinePrimaryColor,
      appBar: AppBar(
        title: const Text('Inscription'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: tontineWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tontinePrimaryColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Rejoignez-nous',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: tontineWhite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Créez votre compte Tontine BF',
                      style: TextStyle(
                        fontSize: 14,
                        color: tontineWhite.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Formulaire
              Padding(
                padding: const EdgeInsets.all(30),
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            'Informations personnelles',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: tontinePrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 25),

                          // Nom complet
                          TextFormField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom Complet',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) => value!.isEmpty ? 'Veuillez entrer votre nom complet' : null,
                          ),
                          const SizedBox(height: 20),

                          // Téléphone
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Numéro de Téléphone',
                              prefixIcon: Icon(Icons.phone_android),
                              hintText: '70 12 34 56',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value!.isEmpty) return 'Veuillez entrer votre numéro';
                              if (value.length < 8) return 'Numéro invalide';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'E-mail (Facultatif)',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),

                          // Mot de passe
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: tontineTextLight,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) => value!.length < 6 ? 'Le mot de passe doit contenir au moins 6 caractères' : null,
                          ),
                          const SizedBox(height: 30),

                          // Bouton d'inscription
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tontinePrimaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(tontineWhite),
                                ),
                              )
                                  : const Text(
                                'S\'inscrire',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Lien de connexion
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Déjà membre ? ',
                                style: AppTextStyles.bodyMedium,
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  );
                                },
                                child: const Text(
                                  'Se connecter',
                                  style: TextStyle(
                                    color: tontinePrimaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}