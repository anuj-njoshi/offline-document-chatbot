import 'dart:math';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';

/// Advanced Embedding Service with Real Vector Similarity
/// 
/// This implementation provides:
/// 1. TF-IDF embeddings (fallback)
/// 2. Cosine similarity search
/// 3. Cached embeddings for performance
/// 4. Option to integrate sentence-transformers
class AdvancedEmbeddingService {
  final Database database;
  final Map<String, List<double>> _embeddingCache = {};
  final Map<String, double> _idfScores = {};
  bool _initialized = false;
  
  static const int embeddingDimensions = 384; // Standard for sentence-transformers

  AdvancedEmbeddingService(this.database);

  Future<void> initialize() async {
    print('🧠 Initializing embedding service...');
    
    // In production, load pre-trained embedding model here
    // For now, we'll use TF-IDF with proper normalization
    
    _initialized = true;
    print('✅ Embedding service ready');
  }

  /// Generate embedding for text
  Future<List<double>> generateEmbedding(String text) async {
    if (!_initialized) await initialize();
    
    // Check cache first
    if (_embeddingCache.containsKey(text)) {
      return _embeddingCache[text]!;
    }
    
    // Generate new embedding
    final embedding = await _computeEmbedding(text);
    
    // Cache it
    _embeddingCache[text] = embedding;
    
    return embedding;
  }

  /// Compute embedding using TF-IDF with proper normalization
  Future<List<double>> _computeEmbedding(String text) async {
    // OPTION A: TF-IDF (current implementation)
    return _tfIdfEmbedding(text);
    
    // OPTION B: Sentence-BERT via ONNX Runtime (production)
    // Uncomment when using onnxruntime
    /*
    try {
      return await _sentenceBertEmbedding(text);
    } catch (e) {
      print('⚠️ Sentence-BERT failed, falling back to TF-IDF: $e');
      return _tfIdfEmbedding(text);
    }
    */
  }

  /// TF-IDF based embedding with improved algorithm
  List<double> _tfIdfEmbedding(String text) {
    final words = _tokenize(text);
    final wordFreq = <String, int>{};
    
    // Calculate term frequency
    for (final word in words) {
      wordFreq[word] = (wordFreq[word] ?? 0) + 1;
    }
    
    // Create embedding vector
    final embedding = List<double>.filled(embeddingDimensions, 0.0);
    
    // Use multiple hash functions for better distribution
    for (final entry in wordFreq.entries) {
      final word = entry.key;
      final tf = entry.value / words.length;
      final idf = _idfScores[word] ?? 1.0;
      final tfidf = tf * idf;
      
      // Map word to multiple dimensions using different hash functions
      for (int hashIndex = 0; hashIndex < 5; hashIndex++) {
        final hash = _multiHash(word, hashIndex);
        final dimension = hash % embeddingDimensions;
        embedding[dimension] += tfidf;
      }
    }
    
    // L2 normalization
    return _normalize(embedding);
  }

  /// Sentence-BERT embedding (for production use)
  /*
  Future<List<double>> _sentenceBertEmbedding(String text) async {
    // Requires: onnxruntime package + sentence-bert model
    
    // 1. Load ONNX model
    final session = OrtSession.fromFile('assets/models/sentence-bert.onnx');
    
    // 2. Tokenize text
    final tokens = _tokenizeForBert(text);
    
    // 3. Create input tensors
    final inputIds = OrtValueTensor.createTensorWithDataList(
      tokens['input_ids'],
      [1, tokens['input_ids'].length],
    );
    
    final attentionMask = OrtValueTensor.createTensorWithDataList(
      tokens['attention_mask'],
      [1, tokens['attention_mask'].length],
    );
    
    // 4. Run inference
    final outputs = session.run({
      'input_ids': inputIds,
      'attention_mask': attentionMask,
    });
    
    // 5. Extract embedding
    final embedding = outputs['last_hidden_state'].value as List<double>;
    
    // 6. Mean pooling
    return _meanPooling(embedding, tokens['attention_mask']);
  }
  */

  /// Tokenize text into words
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toList();
  }

  /// Multi-hash function for better distribution
  int _multiHash(String word, int seed) {
    int hash = seed;
    for (int i = 0; i < word.length; i++) {
      hash = ((hash << 5) + hash) + word.codeUnitAt(i);
    }
    return hash.abs();
  }

  /// L2 normalization
  List<double> _normalize(List<double> vector) {
    double norm = 0.0;
    for (final val in vector) {
      norm += val * val;
    }
    norm = sqrt(norm);
    
    if (norm == 0.0) return vector;
    
    return vector.map((val) => val / norm).toList();
  }

  /// Update IDF scores based on document corpus
  Future<void> updateIdfScores(List<String> allDocuments) async {
    print('📊 Computing IDF scores from corpus...');
    
    final docCount = allDocuments.length;
    final wordDocCount = <String, int>{};
    
    // Count documents containing each word
    for (final doc in allDocuments) {
      final words = _tokenize(doc).toSet();
      for (final word in words) {
        wordDocCount[word] = (wordDocCount[word] ?? 0) + 1;
      }
    }
    
    // Calculate IDF scores
    _idfScores.clear();
    for (final entry in wordDocCount.entries) {
      final word = entry.key;
      final count = entry.value;
      _idfScores[word] = log(docCount / count);
    }
    
    print('✅ IDF scores updated for ${_idfScores.length} words');
  }

  /// Search for similar chunks using embeddings
  Future<List<SimilarityResult>> searchSimilar({
    required String query,
    required String documentId,
    int topK = 5,
    double threshold = 0.3,
  }) async {
    print('🔍 Searching for similar chunks...');
    
    // Generate query embedding
    final queryEmbedding = await generateEmbedding(query);
    
    // Get all chunks for document
    final chunks = await database.query(
      'chunks',
      where: 'documentId = ?',
      whereArgs: [documentId],
    );
    
    final results = <SimilarityResult>[];
    
    // Calculate similarity for each chunk
    for (final chunkMap in chunks) {
      final chunkId = chunkMap['id'] as String;
      final content = chunkMap['content'] as String;
      final chunkIndex = chunkMap['chunkIndex'] as int;
      final pageNumber = chunkMap['pageNumber'] as int?;
      
      // Get or generate chunk embedding
      final chunkEmbedding = await generateEmbedding(content);
      
      // Calculate cosine similarity
      final similarity = _cosineSimilarity(queryEmbedding, chunkEmbedding);
      
      if (similarity >= threshold) {
        results.add(SimilarityResult(
          chunkId: chunkId,
          content: content,
          similarity: similarity,
          chunkIndex: chunkIndex,
          pageNumber: pageNumber,
        ));
      }
    }
    
    // Sort by similarity (descending)
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    
    // Return top K
    final topResults = results.take(topK).toList();
    
    print('✅ Found ${topResults.length} similar chunks');
    for (int i = 0; i < topResults.length; i++) {
      print('  ${i + 1}. Score: ${topResults[i].similarity.toStringAsFixed(3)} - ${topResults[i].content.substring(0, min(50, topResults[i].content.length))}...');
    }
    
    return topResults;
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vectors must have same dimensions');
    }
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Convert embedding to bytes for storage
  Uint8List embeddingToBytes(List<double> embedding) {
    final byteData = ByteData(embedding.length * 8);
    for (int i = 0; i < embedding.length; i++) {
      byteData.setFloat64(i * 8, embedding[i], Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  /// Convert bytes to embedding
  List<double> bytesToEmbedding(Uint8List bytes) {
    final byteData = ByteData.view(bytes.buffer);
    final embedding = <double>[];
    
    for (int i = 0; i < bytes.length; i += 8) {
      embedding.add(byteData.getFloat64(i, Endian.little));
    }
    
    return embedding;
  }

  /// Store embeddings in database (optional, for persistence)
  Future<void> storeEmbedding(String chunkId, List<double> embedding) async {
    final bytes = embeddingToBytes(embedding);
    
    await database.insert(
      'embeddings',
      {
        'id': 'emb_$chunkId',
        'chunk_id': chunkId,
        'embedding': bytes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load embedding from database
  Future<List<double>?> loadEmbedding(String chunkId) async {
    final result = await database.query(
      'embeddings',
      where: 'chunk_id = ?',
      whereArgs: [chunkId],
    );
    
    if (result.isEmpty) return null;
    
    final bytes = result.first['embedding'] as Uint8List;
    return bytesToEmbedding(bytes);
  }

  /// Clear cache (for memory management)
  void clearCache() {
    _embeddingCache.clear();
    print('🧹 Embedding cache cleared');
  }
}

/// Result of similarity search
class SimilarityResult {
  final String chunkId;
  final String content;
  final double similarity;
  final int chunkIndex;
  final int? pageNumber;

  SimilarityResult({
    required this.chunkId,
    required this.content,
    required this.similarity,
    required this.chunkIndex,
    this.pageNumber,
  });

  @override
  String toString() {
    return 'SimilarityResult(score: ${similarity.toStringAsFixed(3)}, chunk: $chunkIndex${pageNumber != null ? ', page: $pageNumber' : ''})';
  }
}