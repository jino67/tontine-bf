import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_tontine_bf/screens/auth/register_screen.dart';
import 'package:app_tontine_bf/screens/home/dashboard_screen.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final String _supportPhoneNumber = '+22670000000';

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('🔐 Tentative de connexion avec: ${_phoneController.text}');

      await _authService.login(_phoneController.text, _passwordController.text);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connexion réussie !'),
          backgroundColor: tontineAccentDark,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );

    } catch (e) {
      if (!mounted) return;

      // Afficher l'erreur complète pour debug
      print('❌ Erreur de connexion: $e');

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

  Future<void> _launchWhatsAppRecovery() async {
    final String message = Uri.encodeComponent(
        "Bonjour, je souhaite réinitialiser mon mot de passe pour l'application Tontine BF. Mon numéro de téléphone est : ${_phoneController.text}"
    );
    final Uri url = Uri.parse("whatsapp://send?phone=$_supportPhoneNumber&text=$message");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("WhatsApp n'est pas installé"),
            backgroundColor: tontinePrimaryColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible d'ouvrir WhatsApp: $e"),
          backgroundColor: tontinePrimaryColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tontinePrimaryColor,
      body: _isLoading
          ? _buildLoadingScreen()
          : SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header avec design amélioré
              _buildHeader(),
              // Formulaire
              _buildLoginForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(tontineWhite),
          ),
          const SizedBox(height: 20),
          Text(
            'Connexion...',
            style: TextStyle(
              color: tontineWhite,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: tontinePrimaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tontineWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.cardShadow,
            ),
            child: Icon(
              Icons.people_alt_rounded,
              size: 40,
              color: tontinePrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'TONTINE BF',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: tontineWhite,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Solidarité & Épargne',
            style: TextStyle(
              fontSize: 14,
              color: tontineWhite.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Padding(
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
                  'Connexion',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: tontinePrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Utilisez votre numéro de téléphone',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 25),

                // Champ téléphone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    prefixIcon: Icon(Icons.phone_android),
                    hintText: '70 12 34 56',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre numéro';
                    }
                    if (value.length < 8) {
                      return 'Numéro invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Champ mot de passe
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre mot de passe';
                    }
                    if (value.length < 6) {
                      return 'Le mot de passe doit avoir au moins 6 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Mot de passe oublié
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _launchWhatsAppRecovery,
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(
                        color: tontinePrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Bouton de connexion
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
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
                      'Se connecter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Lien d'inscription
                // Lien d'inscription - CORRIGÉ
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Nouveau membre ?',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        'Créer un compte',
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
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}