import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_chatbot_offline/model/document.dart';
import 'dart:io';
import '../services/database_service.dart';
import '../services/pdf_processor.dart';

class DocumentProvider with ChangeNotifier {
  final DatabaseService _databaseService;
  final PdfProcessor _pdfProcessor = PdfProcessor();

  List<Document> _documents = [];
  bool _isLoading = false;
  String? _error;

  DocumentProvider(this._databaseService) {
    loadDocuments();
  }

  List<Document> get documents => _documents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _documents = await _databaseService.getAllDocuments();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Document?> pickAndProcessDocument() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      final file = File(result.files.single.path!);

      // Process document
      final processed = await _pdfProcessor.processDocument(file);
      final document = processed['document'] as Document;
      final chunks = processed['chunks'] as List<DocumentChunk>;

      // Save to database
      await _databaseService.insertDocument(document);
      await _databaseService.insertChunks(chunks);

      // Reload documents
      await loadDocuments();

      return document;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDocument(String documentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.deleteDocument(documentId);
      await loadDocuments();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}