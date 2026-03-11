class ChatMessage {
  final String id;
  final String documentId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<String>? sourceChunks; // For showing which parts of document were used

  ChatMessage({
    required this.id,
    required this.documentId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.sourceChunks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'role': role,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sourceChunks': sourceChunks?.join(','),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      documentId: map['documentId'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      sourceChunks: map['sourceChunks'] != null
          ? (map['sourceChunks'] as String).split(',')
          : null,
    );
  }

  bool get isUser => role == 'user';
}