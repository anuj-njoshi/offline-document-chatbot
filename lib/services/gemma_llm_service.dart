import 'dart:math';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:pdf_chatbot_offline/model/document.dart';

class GemmaLLMService {
  bool _initialized = false;
  late dynamic _model;
  dynamic _currentChat;
  
  final List<Map<String, String>> _conversationHistory = [];
  static const int maxHistoryTurns = 3;
  static const int maxTokens = 4096;

  Future<void> initialize() async {
    try {
      print('🤖 Initializing Gemma RAG System...');
      
      final isInstalled = await FlutterGemma.isModelInstalled('gemma-3-2b-it.task');
      
      if (!isInstalled) {
        print('📥 Installing Gemma model...');
        await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
            .fromNetwork(
              'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
              token: '',
            )
            .withProgress((progress) {
              print('Download progress: $progress%');
            })
            .install();
      }
      
      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );
      
      _initialized = true;
      print('✅ Gemma RAG System initialized');
    } catch (e, stackTrace) {
      print('❌ Failed to initialize: $e');
      print(stackTrace);
      rethrow;
    }
  }

  Future<String> generateAnswer({
    required String question,
    required List<DocumentChunk> allChunks,
    Function(String)? onToken,
    bool clearHistory = false,
  }) async {
    if (!_initialized) {
      throw Exception('RAG System not initialized');
    }

    if (clearHistory) {
      _conversationHistory.clear();
    }

    try {
      print('\n🎯 Query: "$question"');
      
      final relevantChunks = await _retrieveRelevantChunks(question, allChunks);
      
      if (relevantChunks.isEmpty) {
        print('⚠️ No relevant chunks, using top chunks');
        final fallbackChunks = await _getTopChunks(question, allChunks, 2);
        return await _generateWithChunks(question, fallbackChunks, onToken);
      }
      
      return await _generateWithChunks(question, relevantChunks, onToken);
      
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print(stackTrace);
      
      if (e.toString().contains('OUT_OF_RANGE') || 
          e.toString().contains('Input is too long')) {
        return await _generateWithMinimalContext(question, allChunks, onToken);
      }
      
      rethrow;
    }
  }

  Future<List<DocumentChunk>> _retrieveRelevantChunks(
    String question,
    List<DocumentChunk> allChunks,
  ) async {
    print('🔍 Searching ${allChunks.length} chunks...');
    
    final questionEmbedding = await _generateEmbedding(question);
    final queryWords = _extractKeywords(question);
    
    final scoredChunks = <Map<String, dynamic>>[];
    
    for (int i = 0; i < allChunks.length; i++) {
      final chunk = allChunks[i];
      final chunkEmbedding = await _generateEmbedding(chunk.content);
      final semanticScore = _cosineSimilarity(questionEmbedding, chunkEmbedding);
      final keywordScore = _improvedKeywordMatch(queryWords, question, chunk.content);
      
      final totalScore = (semanticScore * 0.8) + (keywordScore * 0.2);
      
      scoredChunks.add({
        'chunk': chunk,
        'score': totalScore,
        'semantic': semanticScore,
        'keyword': keywordScore,
      });
      
      print('  Chunk $i: total=${totalScore.toStringAsFixed(3)} '
            'semantic=${semanticScore.toStringAsFixed(3)} '
            'keyword=${keywordScore.toStringAsFixed(3)}');
    }
    
    scoredChunks.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    final threshold = 0.05;
    final selectedChunks = scoredChunks
        .where((item) => (item['score'] as double) > threshold)
        .take(1)
        .map((item) => item['chunk'] as DocumentChunk)
        .toList();
    
    if (selectedChunks.isEmpty && scoredChunks.isNotEmpty) {
      print('⚠️ No chunks above threshold, taking top 2');
      return scoredChunks.take(1).map((item) => item['chunk'] as DocumentChunk).toList();
    }
    
    print('✅ Selected ${selectedChunks.length} chunks');
    return selectedChunks;
  }

  Future<List<DocumentChunk>> _getTopChunks(String question, List<DocumentChunk> allChunks, int n) async {
    final questionEmbedding = await _generateEmbedding(question);
    final scoredChunks = <Map<String, dynamic>>[];
    
    for (final chunk in allChunks) {
      final chunkEmbedding = await _generateEmbedding(chunk.content);
      final score = _cosineSimilarity(questionEmbedding, chunkEmbedding);
      scoredChunks.add({'chunk': chunk, 'score': score});
    }
    
    scoredChunks.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scoredChunks.take(n).map((item) => item['chunk'] as DocumentChunk).toList();
  }

  Future<String> _generateWithChunks(
    String question,
    List<DocumentChunk> chunks,
    Function(String)? onToken,
  ) async {
    final context = _buildContext(chunks);
    
    // CRITICAL: Print the actual context being sent
    print('📄 Context being sent (${context.length} chars):');
    print('--- CONTEXT START ---');
    print(context);
    print('--- CONTEXT END ---');
    
    final prompt = _buildGemmaPrompt(question, context);
    
    print('📏 Full prompt being sent (${prompt.length} chars):');
    print('--- PROMPT START ---');
    print(prompt);
    print('--- PROMPT END ---');
    
    final answer = await _generateResponse(prompt, onToken);
    _addToHistory(question, answer);
    return answer;
  }

  Set<String> _extractKeywords(String text) {
    const stopwords = {
      'the', 'and', 'for', 'this', 'that', 'with', 'from', 'was', 'were',
      'how', 'what', 'when', 'where', 'who', 'why', 'can', 'will', 'are',
      'has', 'have', 'been', 'does', 'did', 'a', 'an', 'is', 'it', 'to',
      'in', 'on', 'at', 'by', 'or', 'as', 'of'
    };
    
    return text.toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 2 && !stopwords.contains(w))
        .toSet();
  }

  double _improvedKeywordMatch(Set<String> queryWords, String originalQuestion, String content) {
    final contentLower = content.toLowerCase();
    final questionLower = originalQuestion.toLowerCase();
    
    if (queryWords.isEmpty) {
      if (questionLower.contains('what') && questionLower.contains('this')) {
        if (contentLower.contains('purpose') || 
            contentLower.contains('role') ||
            contentLower.contains('is to') ||
            contentLower.contains('responsible')) {
          return 0.5;
        }
      }
      return 0.1;
    }
    
    int matches = 0;
    for (final word in queryWords) {
      if (contentLower.contains(word)) matches++;
    }
    
    return matches / queryWords.length;
  }

  String _buildContext(List<DocumentChunk> chunks) {
  final buffer = StringBuffer();
  
  for (int i = 0; i < chunks.length; i++) {
    final content = chunks[i].content.trim();
    // Truncate to 300 chars max per chunk
    final truncated = content.length > 300 ? content.substring(0, 300) : content;
    buffer.writeln(truncated);
    if (i < chunks.length - 1) buffer.writeln();
  }
  
  return buffer.toString();
}

  // CRITICAL FIX: Simplified prompt format that Gemma understands
 String _buildGemmaPrompt(String question, String context) {
  // Gemma-IT format: minimal prompt
  return """$context

Q: $question
A:""";
}
  Future<String> _generateResponse(String prompt, Function(String)? onToken) async {
    try {
      await _clearChatSession();
      _currentChat = await _model.createChat();
      
      print('💬 Generating response...');

      await _currentChat.addQueryChunk(Message.text(text: prompt, isUser: true));
      final ModelResponse response = await _currentChat.generateChatResponse();

      String fullResponse = '';

      if (response is TextResponse) {
        fullResponse = response.token;
        print('📝 Got TextResponse: "$fullResponse"');
      } else if (response is ThinkingResponse) {
        fullResponse = response.content;
        print('💭 Got ThinkingResponse: "$fullResponse"');
      } else if (response is FunctionCallResponse) {
        fullResponse = "Function: ${response.name}";
        print('🔧 Got FunctionCallResponse: "$fullResponse"');
      }

      if (onToken != null && fullResponse.isNotEmpty) {
        onToken(fullResponse);
      }

      fullResponse = fullResponse
          .replaceAll(RegExp(r'<end_of_turn>'), '')
          .replaceAll(RegExp(r'<start_of_turn>'), '')
          .replaceAll(RegExp(r'<start_of_turn>model'), '')
          .replaceAll(RegExp(r'<start_of_turn>user'), '')
          .trim();
      
      print('✅ Final cleaned response: "$fullResponse"');
      
     if (fullResponse.isEmpty || fullResponse == "I cannot find this information.") {
  print('⚠️ Empty response, retrying with simpler prompt');
  
  // Retry with ultra-simple format
  await _clearChatSession();
  _currentChat = await _model.createChat();
  
  final simplePrompt = prompt.length > 500 
      ? "${prompt.substring(0, 500)}\n\nAnswer briefly:"
      : "$prompt";
  
  await _currentChat.addQueryChunk(Message.text(text: simplePrompt, isUser: true));
  final retryResponse = await _currentChat.generateChatResponse();
  
  if (retryResponse is TextResponse && retryResponse.token.trim().isNotEmpty) {
    final retryText = retryResponse.token.trim();
    print('✅ Retry successful: "$retryText"');
    return retryText;
  }
  
  return "The model couldn't generate a response. Try asking a more specific question.";
}
      
      return fullResponse;
      
    } catch (e) {
      print('❌ Generation error: $e');
      if (e.toString().contains('OUT_OF_RANGE')) throw Exception('Context too long');
      rethrow;
    }
  }

  Future<String> _generateWithMinimalContext(
    String question,
    List<DocumentChunk> allChunks,
    Function(String)? onToken,
  ) async {
    print('⚠️ Fallback: minimal context mode');
    
    final topChunks = await _getTopChunks(question, allChunks, 1);
    if (topChunks.isEmpty) return "No information found in document.";
    
    final shortContent = topChunks[0].content.substring(0, min(400, topChunks[0].content.length));
    
    // Ultra-minimal prompt
    final minimalPrompt = """$shortContent

Question: $question
Answer:""";
    
    print('📏 Minimal prompt (${minimalPrompt.length} chars): $minimalPrompt');
    
    return await _generateResponse(minimalPrompt, onToken);
  }

  void _addToHistory(String question, String answer) {
    _conversationHistory.add({'question': question, 'answer': answer});
    if (_conversationHistory.length > maxHistoryTurns) _conversationHistory.removeAt(0);
  }

  void clearConversationHistory() {
    _conversationHistory.clear();
    print('🧹 History cleared');
  }

  Future<List<double>> _generateEmbedding(String text) async => _improvedTfidfEmbedding(text);

  List<double> _improvedTfidfEmbedding(String text) {
    const stopwords = {
      'the', 'and', 'for', 'this', 'that', 'with', 'from', 'was', 'were',
      'how', 'you', 'can', 'will', 'are', 'has', 'have', 'been', 'what',
      'when', 'where', 'who', 'why', 'does', 'did', 'is', 'it'
    };
    
    final words = text.toLowerCase().split(RegExp(r'\W+')).where((w) => w.isNotEmpty).toList();
    final embedding = List<double>.filled(512, 0.0);
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final weight = stopwords.contains(word) ? 0.3 : 1.0;
      
      _addToEmbedding(embedding, word, weight);
      
      if (i < words.length - 1) {
        _addToEmbedding(embedding, '${words[i]}_${words[i + 1]}', weight * 1.5);
      }
      
      if (word.length >= 3) {
        for (int j = 0; j <= word.length - 3; j++) {
          _addToEmbedding(embedding, word.substring(j, j + 3), weight * 0.5);
        }
      }
    }
    
    final magnitude = sqrt(embedding.fold(0.0, (sum, val) => sum + val * val));
    return magnitude > 0 ? embedding.map((v) => v / magnitude).toList() : embedding;
  }

  void _addToEmbedding(List<double> embedding, String term, double weight) {
    final hash = term.hashCode.abs();
    for (int i = 0; i < 4; i++) {
      embedding[(hash + i * 37) % 512] += weight;
    }
  }

  double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length) return 0.0;
    
    double dotProduct = 0.0, mag1 = 0.0, mag2 = 0.0;
    
    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      mag1 += vec1[i] * vec1[i];
      mag2 += vec2[i] * vec2[i];
    }
    
    mag1 = sqrt(mag1);
    mag2 = sqrt(mag2);
    
    return (mag1 > 0 && mag2 > 0) ? dotProduct / (mag1 * mag2) : 0.0;
  }

  Future<void> _clearChatSession() async {
    try {
      await _currentChat?.close();
      _currentChat = null;
    } catch (e) {}
  }

  Future<void> dispose() async {
    try {
      await _clearChatSession();
      await _model.close();
      _conversationHistory.clear();
      _initialized = false;
      print('🧹 Disposed');
    } catch (e) {
      print('Error disposing: $e');
    }
  }

  bool get isInitialized => _initialized;
}

