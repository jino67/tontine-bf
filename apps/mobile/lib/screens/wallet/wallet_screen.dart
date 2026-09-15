import 'package:flutter/material.dart';
import 'package:app_tontine_bf/models/wallet.dart';
import 'package:app_tontine_bf/services/wallet_service.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/config/theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  final AuthService _authService = AuthService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Wallet? _wallet;
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _showDepositForm = false;
  bool _showWithdrawForm = false;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      final userId = await _authService.getUserId();
      if (userId != null) {
        final wallet = await _walletService.getWallet(userId);
        final transactions = await _walletService.getTransactionHistory(wallet.id);

        if (!mounted) return; // Ajout de la vérification

        setState(() {
          _wallet = wallet;
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      // print('Error loading wallet: $e'); // Supprimé: avoid_print
      if (!mounted) return; // Ajout de la vérification
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deposit() async {
    if (_amountController.text.isEmpty || _phoneController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    try {
      final userId = await _authService.getUserId();
      if (userId == null) return;

      final result = await _walletService.deposit(
        userId: userId,
        amount: amount,
        phoneNumber: _phoneController.text,
      );

      if (!mounted) return; // CORRIGÉ: use_build_context_synchronously

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dépôt réussi: ${result['message']}'),
            backgroundColor: tontineAccentDark,
          ),
        );
        _resetForms();
        _loadWalletData(); // Recharger les données
      }
    } catch (e) {
      if (!mounted) return; // CORRIGÉ: use_build_context_synchronously pour le catch

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: tontinePrimaryColor,
        ),
      );
    }
  }

  Future<void> _withdraw() async {
    if (_amountController.text.isEmpty || _phoneController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    try {
      final userId = await _authService.getUserId();
      if (userId == null) return;

      final result = await _walletService.withdraw(
        userId: userId,
        amount: amount,
        phoneNumber: _phoneController.text,
      );

      if (!mounted) return; // CORRIGÉ: use_build_context_synchronously

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retrait réussi: ${result['message']}'),
            backgroundColor: tontineAccentDark,
          ),
        );
        _resetForms();
        _loadWalletData();
      }
    } catch (e) {
      if (!mounted) return; // CORRIGÉ: use_build_context_synchronously pour le catch

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: tontinePrimaryColor,
        ),
      );
    }
  }

  void _resetForms() {
    setState(() {
      _showDepositForm = false;
      _showWithdrawForm = false;
      _amountController.clear();
      _phoneController.clear();
    });
  }

  Widget _buildWalletCard() {
    if (_wallet == null) return Container();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tontinePrimaryColor, tontinePrimaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            'Solde du Portefeuille',
            style: TextStyle(
              fontSize: 16,
              color: tontineWhite.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_wallet!.balance} FCFA',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: tontineWhite,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton('Déposer', Icons.add, () {
                setState(() {
                  _showDepositForm = true;
                  _showWithdrawForm = false;
                });
              }),
              _buildActionButton('Retirer', Icons.remove, () {
                setState(() {
                  _showWithdrawForm = true;
                  _showDepositForm = false;
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: tontineWhite.withOpacity(0.2),
            child: Icon(icon, color: tontineWhite),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: tontineWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionForm() {
    if (!_showDepositForm && !_showWithdrawForm) return Container();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showDepositForm ? 'Déposer de l\'argent' : 'Retirer de l\'argent',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant (FCFA)',
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro Orange Money',
                prefixIcon: Icon(Icons.phone),
                hintText: '70 12 34 56',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _resetForms,
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showDepositForm ? _deposit : _withdraw,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showDepositForm ? tontineAccentDark : tontinePrimaryColor,
                    ),
                    child: Text(_showDepositForm ? 'Déposer' : 'Retirer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getTransactionColor(transaction.type).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getTransactionIcon(transaction.type),
            color: _getTransactionColor(transaction.type),
            size: 20,
          ),
        ),
        title: Text(
          _getTransactionTitle(transaction.type),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(transaction.description),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${transaction.amount} FCFA',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _getTransactionColor(transaction.type),
              ),
            ),
            Text(
              _formatDate(transaction.createdAt),
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'deposit': return tontineAccentDark;
      case 'withdrawal': return tontinePrimaryColor;
      case 'payment': return tontineGold;
      case 'receipt': return tontineAccentColor;
      default: return tontineTextLight;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'deposit': return Icons.add;
      case 'withdrawal': return Icons.remove;
      case 'payment': return Icons.payment;
      case 'receipt': return Icons.receipt;
      default: return Icons.money;
    }
  }

  String _getTransactionTitle(String type) {
    switch (type) {
      case 'deposit': return 'Dépôt';
      case 'withdrawal': return 'Retrait';
      case 'payment': return 'Paiement';
      case 'receipt': return 'Reçu';
      default: return 'Transaction';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tontineBackgroundColor,
      appBar: AppBar(
        title: const Text('Mon Portefeuille'),
        backgroundColor: tontinePrimaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Carte du portefeuille
          _buildWalletCard(),

          // Formulaire de dépôt/retrait
          _buildTransactionForm(),

          // Historique des transactions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historique',
                  style: AppTextStyles.titleMedium,
                ),
                Text(
                  '${_transactions.length} transactions',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),

          // Liste des transactions
          Expanded(
            child: _transactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                return _buildTransactionCard(_transactions[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: tontineTextLight.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune transaction',
            style: AppTextStyles.titleMedium.copyWith(
              color: tontineTextLight,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Vos transactions apparaîtront ici',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}