import 'dart:io';
import 'package:pdf_chatbot_offline/model/document.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

class PdfProcessor {
  static const int chunkSize = 500; // characters per chunk
  static const int chunkOverlap = 50; // overlap between chunks

  Future<Map<String, dynamic>> processDocument(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      // Create document ID once
      final documentId = const Uuid().v4();
      final documentChunks = <DocumentChunk>[];
      int totalChunks = 0;

      if (extension == 'pdf') {
        // PDF Processing - Layout Aware
        final PdfDocument document =
            PdfDocument(inputBytes: await file.readAsBytes());
        int chunkIndex = 0;

        for (int i = 0; i < document.pages.count; i++) {
          final List<TextLine> lines =
              PdfTextExtractor(document).extractTextLines(startPageIndex: i);

          if (lines.isNotEmpty) {
            // Group lines into blocks based on vertical proximity and horizontal alignment
            // This helps handle multi-column layouts better than flat text extraction
            final String structuredPageText = _reconstructLayout(lines);

            if (structuredPageText.trim().isNotEmpty) {
              final pageChunks = _createChunks(structuredPageText);

              for (final chunkContent in pageChunks) {
                documentChunks.add(
                  DocumentChunk(
                    id: '${documentId}_chunk_$chunkIndex',
                    documentId: documentId,
                    content: chunkContent,
                    chunkIndex: chunkIndex,
                    pageNumber: i + 1,
                  ),
                );
                chunkIndex++;
              }
            }
          }
        }
        document.dispose();
        totalChunks = chunkIndex;
      } else if (extension == 'txt') {
        // Text Processing - All at once
        final fullText = await file.readAsString();
        final chunks = _createChunks(fullText);

        for (int i = 0; i < chunks.length; i++) {
          documentChunks.add(
            DocumentChunk(
              id: '${documentId}_chunk_$i',
              documentId: documentId,
              content: chunks[i],
              chunkIndex: i,
              pageNumber: null,
            ),
          );
        }
        totalChunks = chunks.length;
      } else {
        throw Exception('Unsupported file type: $extension');
      }

      if (documentChunks.isEmpty) {
        throw Exception('No text found in document');
      }

      // Create document object
      final document = Document(
        id: documentId,
        name: fileName,
        filePath: file.path,
        createdAt: DateTime.now(),
        totalChunks: totalChunks,
      );

      return {
        'document': document,
        'chunks': documentChunks,
      };
    } catch (e, stack) {
      print("Error processing document: $e");
      print(stack);
      throw Exception('Failed to process document: $e');
    }
  }

  /// Reconstructs the layout by grouping lines that belong to the same column/block
  String _reconstructLayout(List<TextLine> lines) {
    if (lines.isEmpty) return '';

    // Sort lines primarily by vertical position (top) and secondarily by horizontal (left)
    // This isn't enough for multi-column. We need to identify columns.

    // Simple column identification: find clusters of 'left' coordinates
    final List<double> leftCoords = lines.map((l) => l.bounds.left).toList();
    leftCoords.sort();

    final List<double> columnStarts = [];
    if (leftCoords.isNotEmpty) {
      columnStarts.add(leftCoords[0]);
      for (int i = 1; i < leftCoords.length; i++) {
        if (leftCoords[i] - leftCoords[i - 1] > 50) {
          // 50 units threshold for new column
          columnStarts.add(leftCoords[i]);
        }
      }
    }

    if (columnStarts.length <= 1) {
      // Single column or simple layout - just join lines normally
      return lines.map((l) => l.text).join('\n');
    }

    // Multi-column layout handling
    final Map<int, List<TextLine>> columns = {};
    for (int i = 0; i < columnStarts.length; i++) {
      columns[i] = [];
    }

    for (final line in lines) {
      int colIndex = 0;
      double minDiff = (line.bounds.left - columnStarts[0]).abs();
      for (int i = 1; i < columnStarts.length; i++) {
        final diff = (line.bounds.left - columnStarts[i]).abs();
        if (diff < minDiff) {
          minDiff = diff;
          colIndex = i;
        }
      }
      columns[colIndex]!.add(line);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < columnStarts.length; i++) {
      final colLines = columns[i]!;
      colLines.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
      for (final line in colLines) {
        buffer.writeln(line.text);
      }
      buffer.writeln(); // Gap between columns
    }

    return buffer.toString();
  }

  // Improved chunking: try to split at sentence boundaries or double newlines
  List<String> _createChunks(String text) {
    if (text.isEmpty) return [];

    final chunks = <String>[];

    // Split into paragraphs first if possible
    final paragraphs = text.split(RegExp(r'\n\s*\n'));

    String currentChunk = '';

    for (var paragraph in paragraphs) {
      paragraph = paragraph.trim();
      if (paragraph.isEmpty) continue;

      if ((currentChunk + '\n\n' + paragraph).length <= chunkSize) {
        currentChunk =
            currentChunk.isEmpty ? paragraph : '$currentChunk\n\n$paragraph';
      } else {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
        }

        // If paragraph itself is too large, split by sentences
        if (paragraph.length > chunkSize) {
          final sentences = paragraph.split(RegExp(r'(?<=[.!?])\s+'));
          currentChunk = '';
          for (final sentence in sentences) {
            if ((currentChunk + ' ' + sentence).length <= chunkSize) {
              currentChunk =
                  currentChunk.isEmpty ? sentence : '$currentChunk $sentence';
            } else {
              if (currentChunk.isNotEmpty) {
                chunks.add(currentChunk.trim());
              }
              currentChunk = sentence;

              // Extreme case: single sentence > chunkSize
              if (currentChunk.length > chunkSize) {
                while (currentChunk.length > chunkSize) {
                  chunks.add(currentChunk.substring(0, chunkSize));
                  currentChunk = currentChunk.substring(chunkSize);
                }
              }
            }
          }
        } else {
          currentChunk = paragraph;
        }
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    return chunks;
  }
}
