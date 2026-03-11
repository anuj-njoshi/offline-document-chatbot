import 'package:pdf_chatbot_offline/model/chat_message.dart';
import 'package:pdf_chatbot_offline/model/document.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  Database? _database;

  Future<void> initialize() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'pdf_chatbot.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Documents table
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            filePath TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            totalChunks INTEGER NOT NULL
          )
        ''');

        // Document chunks table
        await db.execute('''
          CREATE TABLE chunks (
            id TEXT PRIMARY KEY,
            documentId TEXT NOT NULL,
            content TEXT NOT NULL,
            chunkIndex INTEGER NOT NULL,
            pageNumber INTEGER,
            FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
          )
        ''');

        // Chat messages table
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            documentId TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            sourceChunks TEXT,
            FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
          )
        ''');

        // Create indexes
        await db.execute('CREATE INDEX idx_chunks_doc ON chunks(documentId)');
        await db.execute('CREATE INDEX idx_messages_doc ON messages(documentId)');
      },
    );
  }

  // Document operations
  Future<void> insertDocument(Document document) async {
    await _database!.insert(
      'documents',
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Document>> getAllDocuments() async {
    final List<Map<String, dynamic>> maps = await _database!.query(
      'documents',
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => Document.fromMap(map)).toList();
  }

  Future<Document?> getDocument(String id) async {
    final List<Map<String, dynamic>> maps = await _database!.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Document.fromMap(maps.first);
  }

  Future<void> deleteDocument(String id) async {
    await _database!.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Chunk operations
  Future<void> insertChunks(List<DocumentChunk> chunks) async {
    final batch = _database!.batch();
    for (final chunk in chunks) {
      batch.insert('chunks', chunk.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<DocumentChunk>> getChunks(String documentId) async {
    final List<Map<String, dynamic>> maps = await _database!.query(
      'chunks',
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'chunkIndex ASC',
    );
    return maps.map((map) => DocumentChunk.fromMap(map)).toList();
  }

  // Message operations
  Future<void> insertMessage(ChatMessage message) async {
    await _database!.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getMessages(String documentId) async {
    final List<Map<String, dynamic>> maps = await _database!.query(
      'messages',
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }

  Future<void> deleteMessages(String documentId) async {
    await _database!.delete(
      'messages',
      where: 'documentId = ?',
      whereArgs: [documentId],
    );
  }
}