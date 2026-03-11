import 'dart:math';
import 'package:pdf_chatbot_offline/model/document.dart';


class LLMService {
  bool _initialized = false;

  Future<void> initialize() async {
    // In a real app, this would load the LLM model
    // For now, we'll simulate it
    await Future.delayed(const Duration(seconds: 1));
    _initialized = true;
  }

  /// Generate answer using RAG (Retrieval-Augmented Generation)
  Future<String> generateAnswer({
    required String question,
    required List<DocumentChunk> allChunks,
    Function(String)? onToken,
  }) async {
    if (!_initialized) {
      throw Exception('LLM service not initialized');
    }

    // Step 1: Retrieve relevant chunks (simple keyword matching for demo)
    final relevantChunks = _retrieveRelevantChunks(question, allChunks);

    // Step 2: Build context
    final context = _buildContext(relevantChunks);

    // Step 3: Generate answer (simulated)
    final answer = await _generateResponse(question, context, onToken);

    return answer;
  }

  List<DocumentChunk> _retrieveRelevantChunks(
    String question,
    List<DocumentChunk> allChunks,
  ) {
    // Simple keyword-based retrieval (in production, use embeddings)
    final questionWords = question.toLowerCase().split(' ');
    
    final scored = allChunks.map((chunk) {
      final content = chunk.content.toLowerCase();
      int score = 0;
      
      for (final word in questionWords) {
        if (word.length > 3 && content.contains(word)) {
          score += 1;
        }
      }
      
      return {'chunk': chunk, 'score': score};
    }).toList();

    // Sort by score and take top 3
    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    final topChunks = scored
        .take(3)
        .where((item) => (item['score'] as int) > 0)
        .map((item) => item['chunk'] as DocumentChunk)
        .toList();

    return topChunks.isEmpty ? allChunks.take(3).toList() : topChunks;
  }

  String _buildContext(List<DocumentChunk> chunks) {
    final buffer = StringBuffer();
    for (int i = 0; i < chunks.length; i++) {
      buffer.writeln('Context ${i + 1}:');
      buffer.writeln(chunks[i].content);
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<String> _generateResponse(
    String question,
    String context,
    Function(String)? onToken,
  ) async {
    // Simulate LLM processing time
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate intelligent response based on question type
    final response = _createIntelligentResponse(question, context);

    // Simulate streaming
    if (onToken != null) {
      for (int i = 0; i < response.length; i += 5) {
        final end = (i + 5 > response.length) ? response.length : i + 5;
        onToken(response.substring(i, end));
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }

    return response;
  }

  String _createIntelligentResponse(String question, String context) {
    final q = question.toLowerCase();

    // Detect question type and generate appropriate response
    if (q.contains('main') && (q.contains('topic') || q.contains('conclusion'))) {
      return 'Based on the document, the main topic appears to be focused on the key concepts discussed in the text. The primary themes include the subject matter presented across different sections, with particular emphasis on the core arguments and supporting evidence provided.';
    }
    
    if (q.contains('key points') || q.contains('main points')) {
      return '''The key points from the document include:

1. The primary concept and its fundamental principles
2. Supporting evidence and examples that illustrate the main ideas
3. Relationships between different concepts discussed
4. Practical applications and real-world implications
5. Important conclusions and recommendations

These points are derived from the relevant sections of the document.''';
    }
    
    if (q.contains('page') && q.contains(RegExp(r'\d+'))) {
      final pageMatch = RegExp(r'\d+').firstMatch(q);
      final pageNum = pageMatch?.group(0) ?? '5';
      return 'According to page $pageNum of the document, the content discusses important aspects of the subject matter. The key information from this section includes relevant details, supporting arguments, and specific examples that contribute to the overall narrative of the document.';
    }
    
    if (q.contains('summarize') || q.contains('summary')) {
      return 'Here is a summary based on the document: The text presents a comprehensive overview of the main subject, providing detailed information across multiple aspects. Key themes include the primary arguments, supporting evidence, and practical implications. The document offers valuable insights through its structured approach to the topic.';
    }
    
    if (q.contains('who') || q.contains('author')) {
      return 'Based on the document content, the information about people or authors mentioned relates to their contributions and perspectives on the subject matter. The text references various individuals in the context of their work and ideas presented.';
    }
    
    if (q.contains('when') || q.contains('date') || q.contains('time')) {
      return 'According to the document, the timeline and chronological aspects are discussed in relation to the events and developments mentioned. The temporal context helps understand the progression and evolution of the topics covered.';
    }
    
    if (q.contains('how')) {
      return 'The document explains the process through a systematic approach. It outlines the methodology, steps involved, and mechanisms that contribute to understanding the topic. The explanation includes both theoretical foundations and practical applications.';
    }
    
    if (q.contains('why')) {
      return 'The rationale presented in the document suggests several contributing factors. The reasoning is supported by evidence and logical arguments that help explain the underlying causes and motivations discussed in the text.';
    }
    
    if (q.contains('what is') || q.contains('what are')) {
      return 'Based on the document, this refers to the specific concepts and definitions presented in the context. The text provides detailed information that helps clarify the nature, characteristics, and significance of the topic in question.';
    }
    
    // Default response
    return 'Based on the information provided in the document, I can address your question as follows: The relevant sections discuss this topic by presenting various perspectives and evidence. The document offers insights through its analysis and examples, which help answer your question by drawing from the contextual information available.';
  }

  bool get isInitialized => _initialized;
}