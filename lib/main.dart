import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'services/database_service.dart';
import 'services/gemma_llm_service.dart';
import 'providers/document_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Flutter Gemma
  FlutterGemma.initialize();
  
  // Initialize database
  final databaseService = DatabaseService();
  await databaseService.initialize();
  
  // Initialize Gemma LLM service
  final gemmaService = GemmaLLMService();
  try {
    await gemmaService.initialize();
    print('✅ Gemma LLM service initialized');
  } catch (e) {
    print('⚠️ Failed to initialize Gemma LLM: $e');
    print('Please ensure you have internet connection to download the model on first run');
  }
  
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        Provider<GemmaLLMService>.value(value: gemmaService),
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(databaseService),
        ),
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            databaseService,
            context.read<GemmaLLMService>(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Chatbot Offline',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}