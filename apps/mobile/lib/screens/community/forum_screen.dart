import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // AJOUTEZ CET IMPORT
import 'package:app_tontine_bf/config/theme.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'user': {
        'name': 'Jean Kaboré',
        'phone': '70 12 34 56',
        'avatar': 'J',
      },
      'message': 'Je viens de gagner 50,000 FCFA dans ma tontine ! Merci à tous les participants 🙏',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'likes': 12,
      'comments': 3,
      'isVerified': true,
    },
    {
      'id': '2',
      'user': {
        'name': 'Marie Ouédraogo',
        'phone': '79 87 65 43',
        'avatar': 'M',
      },
      'message': 'Quelqu\'un peut m\'expliquer comment fonctionne le tirage au sort ? Je suis nouvelle sur l\'appli.',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'likes': 8,
      'comments': 7,
      'isVerified': false,
    },
    {
      'id': '3',
      'user': {
        'name': 'Tontine BF Support',
        'phone': 'Support',
        'avatar': 'T',
      },
      'message': '📢 Nouvelle fonctionnalité : Vous pouvez maintenant créer des cagnottes solidaires pour vos projets personnels !',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'likes': 25,
      'comments': 5,
      'isVerified': true,
    },
  ];

  void _postMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final newMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'user': {
        'name': 'Moi',
        'phone': 'Mon numéro',
        'avatar': 'M',
      },
      'message': _messageController.text,
      'timestamp': DateTime.now(),
      'likes': 0,
      'comments': 0,
      'isVerified': false,
    };

    setState(() {
      _messages.insert(0, newMessage);
      _messageController.clear();
    });

    // Ici, vous enverriez le message à votre API
  }

  Widget _buildUserAvatar(Map<String, dynamic> user) {
    return CircleAvatar(
      backgroundColor: tontinePrimaryColor.withOpacity(0.1),
      child: Text(
        user['avatar'],
        style: TextStyle(
          color: tontinePrimaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du message
            Row(
              children: [
                _buildUserAvatar(message['user']),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            message['user']['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (message['isVerified'])
                            Icon(
                              Icons.verified,
                              color: tontineAccentDark,
                              size: 16,
                            ),
                        ],
                      ),
                      Text(
                        message['user']['phone'],
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(message['timestamp']),
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contenu du message
            Text(
              message['message'],
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.favorite_border,
                    color: tontineTextLight,
                    size: 20,
                  ),
                  onPressed: () {
                    // Like functionality
                  },
                ),
                Text(
                  '${message['likes']}',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    Icons.comment_outlined,
                    color: tontineTextLight,
                    size: 20,
                  ),
                  onPressed: () {
                    // Comment functionality
                  },
                ),
                Text(
                  '${message['comments']}',
                  style: AppTextStyles.bodyMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: tontineTextLight,
                    size: 20,
                  ),
                  onPressed: () {
                    // Share functionality
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';

    return DateFormat('dd/MM/yy').format(timestamp); // CORRIGÉ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tontineBackgroundColor,
      appBar: AppBar(
        title: const Text('Forum Communautaire'),
        backgroundColor: tontinePrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.trending_up),
            onPressed: () {
              // Voir les tendances
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone de publication
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tontineWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Partagez votre expérience...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: tontineBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _postMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: tontinePrimaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _postMessage,
                  ),
                ),
              ],
            ),
          ),

          // Liste des messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageCard(_messages[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}