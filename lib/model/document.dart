class Document {
  final String id;
  final String name;
  final String filePath;
  final DateTime createdAt;
  final int totalChunks;

  Document({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
    required this.totalChunks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'totalChunks': totalChunks,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as String,
      name: map['name'] as String,
      filePath: map['filePath'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      totalChunks: map['totalChunks'] as int,
    );
  }
}

class DocumentChunk {
  final String id;
  final String documentId;
  final String content;
  final int chunkIndex;
  final int? pageNumber;

  DocumentChunk({
    required this.id,
    required this.documentId,
    required this.content,
    required this.chunkIndex,
    this.pageNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'content': content,
      'chunkIndex': chunkIndex,
      'pageNumber': pageNumber,
    };
  }

  factory DocumentChunk.fromMap(Map<String, dynamic> map) {
    return DocumentChunk(
      id: map['id'] as String,
      documentId: map['documentId'] as String,
      content: map['content'] as String,
      chunkIndex: map['chunkIndex'] as int,
      pageNumber: map['pageNumber'] as int?,
    );
  }
}