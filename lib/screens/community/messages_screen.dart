import 'package:flutter/material.dart';
import 'package:app_tontine_bf/screens/community/chat_screen.dart';
import 'package:app_tontine_bf/config/theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<Map<String, dynamic>> _conversations = [
    {
      'id': '1',
      'userName': 'Jean Kaboré',
      'userPhone': '70 12 34 56',
      'lastMessage': 'Merci pour le paiement !',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'unreadCount': 0,
      'isOnline': true,
    },
    {
      'id': '2',
      'userName': 'Marie Ouédraogo',
      'userPhone': '79 87 65 43',
      'lastMessage': 'Quand est le prochain tirage ?',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'unreadCount': 3,
      'isOnline': false,
    },
    {
      'id': '3',
      'userName': 'Tontine BF Support',
      'userPhone': 'Support',
      'lastMessage': 'Bienvenue sur Tontine BF !',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'unreadCount': 0,
      'isOnline': true,
    },
    {
      'id': '4',
      'userName': 'Pierre Sawadogo',
      'userPhone': '76 54 32 10',
      'lastMessage': 'Je rejoins la tontine la semaine prochaine',
      'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      'unreadCount': 1,
      'isOnline': false,
    },
  ];

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: tontinePrimaryColor.withOpacity(0.1),
              child: Text(
                conversation['userName'][0],
                style: TextStyle(
                  color: tontinePrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (conversation['isOnline'])
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tontineAccentDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: tontineWhite, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          conversation['userName'],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          conversation['lastMessage'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(conversation['timestamp']),
              style: AppTextStyles.bodyMedium,
            ),
            if (conversation['unreadCount'] > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tontinePrimaryColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  conversation['unreadCount'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userName: conversation['userName'],
                userPhone: conversation['userPhone'],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Maintenant';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min';
    if (difference.inHours < 24) return '${difference.inHours} h';
    if (difference.inDays < 7) return '${difference.inDays} j';

    return '${timestamp.day}/${timestamp.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tontineBackgroundColor,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: tontinePrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Recherche de conversations
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              // Nouvelle conversation de groupe
            },
          ),
        ],
      ),
      body: _conversations.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          return _buildConversationCard(_conversations[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: tontineTextLight.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun message',
            style: AppTextStyles.titleMedium.copyWith(
              color: tontineTextLight,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Commencez une conversation avec les membres de vos tontines',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}