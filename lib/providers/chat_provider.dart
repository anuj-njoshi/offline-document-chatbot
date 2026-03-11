import 'package:flutter/foundation.dart';
import 'package:pdf_chatbot_offline/model/chat_message.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import '../services/gemma_llm_service.dart';

class ChatProvider with ChangeNotifier {
  final DatabaseService _databaseService;
  final GemmaLLMService _gemmaService;

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _currentDocumentId;

  ChatProvider(this._databaseService, this._gemmaService);

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMessages(String documentId) async {
    _currentDocumentId = documentId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await _databaseService.getMessages(documentId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (_currentDocumentId == null || content.trim().isEmpty) return;

    // Create user message
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      documentId: _currentDocumentId!,
      role: 'user',
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    // Add to list and save
    _messages.add(userMessage);
    notifyListeners();

    try {
      await _databaseService.insertMessage(userMessage);

      // Get AI response
      _isLoading = true;
      notifyListeners();

      // Get all chunks for this document
      final chunks = await _databaseService.getChunks(_currentDocumentId!);

      // Generate answer with streaming using Gemma
      String streamingAnswer = '';
      
      final answer = await _gemmaService.generateAnswer(
        question: content,
        allChunks: chunks,
        onToken: (token) {
          streamingAnswer += token;
          // Update the last message if it's the assistant's
          if (_messages.isNotEmpty && !_messages.last.isUser) {
            _messages.removeLast();
          }
          _messages.add(ChatMessage(
            id: 'temp',
            documentId: _currentDocumentId!,
            role: 'assistant',
            content: streamingAnswer,
            timestamp: DateTime.now(),
          ));
          notifyListeners();
        },
      );

      // Create final assistant message
      final assistantMessage = ChatMessage(
        id: const Uuid().v4(),
        documentId: _currentDocumentId!,
        role: 'assistant',
        content: 'answer>$answer',
        timestamp: DateTime.now(),
      );

      // Replace temp message with final
      if (_messages.isNotEmpty && _messages.last.id == 'temp') {
        _messages.removeLast();
      }
      _messages.add(assistantMessage);
      notifyListeners();

      await _databaseService.insertMessage(assistantMessage);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    if (_currentDocumentId == null) return;

    try {
      await _databaseService.deleteMessages(_currentDocumentId!);
      _messages.clear();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearCurrentChat() {
    _messages.clear();
    _currentDocumentId = null;
    notifyListeners();
  }
}