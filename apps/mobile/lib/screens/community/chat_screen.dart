import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';

class ChatScreen extends StatefulWidget {
  final String userName;
  final String userPhone;

  const ChatScreen({
    super.key,
    required this.userName,
    required this.userPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'text': 'Bonjour ! Comment vas-tu ?',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
    },
    {
      'id': '2',
      'text': 'Je vais bien merci ! Et toi ?',
      'isMe': true,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 4)),
    },
    {
      'id': '3',
      'text': 'Très bien aussi. Tu as payé ta cotisation de cette semaine ?',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 3)),
    },
    {
      'id': '4',
      'text': 'Oui, je l\'ai payée hier. Tout est en ordre 👍',
      'isMe': true,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 2)),
    },
    {
      'id': '5',
      'text': 'Parfait ! Merci pour ta régularité.',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 1)),
    },
  ];

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final newMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': _messageController.text,
      'isMe': true,
      'timestamp': DateTime.now(),
    };

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });

    // Simuler une réponse automatique
    _simulateReply();
  }

  void _simulateReply() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      final replyMessage = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': 'Merci pour votre message ! Je vous répondrai bientôt.',
        'isMe': false,
        'timestamp': DateTime.now().add(const Duration(seconds: 2)),
      };

      setState(() {
        _messages.add(replyMessage);
      });
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              backgroundColor: tontinePrimaryColor.withOpacity(0.1),
              radius: 16,
              child: Text(
                widget.userName[0],
                style: TextStyle(
                  color: tontinePrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? tontinePrimaryColor : tontineWhite,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'],
                    style: TextStyle(
                      color: isMe ? tontineWhite : tontineTextColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message['timestamp']),
                    style: TextStyle(
                      color: isMe ? tontineWhite.withOpacity(0.7) : tontineTextLight,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            CircleAvatar(
              backgroundColor: tontineAccentColor.withOpacity(0.1),
              radius: 16,
              child: Text(
                'M',
                style: TextStyle(
                  color: tontineAccentDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tontineBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.userPhone,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: tontinePrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              // Appeler l'utilisateur
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // Appel vidéo
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Liste des messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Zone de saisie
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tontineWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Tapez votre message...',
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
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: tontinePrimaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}