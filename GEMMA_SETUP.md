# Flutter Gemma Integration Guide

## Overview

This guide explains how to integrate **flutter_gemma** with your offline document chatbot. Flutter Gemma provides fast, on-device LLM inference using Google's Gemma models, without requiring any internet connection after model download.

**Current Version:** flutter_gemma 0.12.3+

## Quick Start

```bash
# 1. Install dependencies
flutter pub get

# 2. Run the app
flutter run

# 3. On first run, the app will download Gemma 3 2B model (~1.6GB)
# This takes 5-30 minutes depending on your internet connection
```

## Setup Steps

### 1. Update Dependencies

Run `flutter pub get` to install flutter_gemma ^0.12.3 and all dependencies.

### 2. Platform-Specific Setup

#### iOS
1. Set minimum iOS version to 16.0 in `ios/Podfile`:
```ruby
platform :ios, '16.0'  # Required for MediaPipe GenAI
```

2. Use static linking in `ios/Podfile`:
```ruby
use_frameworks! :linkage => :static
```

3. Add memory entitlements in `ios/Runner/Release.entitlements`:
```xml
<dict>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
</dict>
```

**Build:**
```bash
cd ios && pod install --repo-update && cd ..
flutter build ios
```

#### Android
Update `android/app/build.gradle`:

```gradle
android {
    ...
    defaultConfig {
        ...
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
    }
}
```

Add to `android/AndroidManifest.xml` (for GPU support):
```xml
<uses-native-library
    android:name="libOpenCL.so"
    android:required="false"/>
<uses-native-library 
    android:name="libOpenCL-car.so" 
    android:required="false"/>
```

**Build:**
```bash
flutter build apk
```

#### macOS/Linux/Windows
No additional configuration needed. Platform-specific setup is handled automatically.

### 3. Initialize in Your App

The integration automatically initializes Flutter Gemma in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Flutter Gemma (automatic model download on first run)
  FlutterGemma.initialize();
  
  // ... rest of initialization
}
```

## Model Information

### Supported Models
- **Gemma 3 2B Instruct** (Currently Used - Recommended)
  - Size: ~1.6 GB (quantized)
  - RAM: 4 GB minimum
  - Speed: 15-30 seconds per response
  - Best for: Most mobile devices

- **Gemma 3 1B** (Alternative - Smaller)
  - Size: ~500 MB
  - RAM: 2-3 GB
  - Best for: Low-end devices

- **Gemma3n Models** (Advanced - Multimodal)
  - Supports text + image input
  - Requires 8GB+ RAM
  - Not currently used in this app

### Download URLs
Models are automatically downloaded from Hugging Face on first run:
- Gemma 3 2B: https://huggingface.co/litert-community/Gemma3-2B-IT
- Gemma 3 1B: https://huggingface.co/litert-community/Gemma3-1B-IT

## Usage

### Basic Usage in Your Code

```dart
import 'package:flutter_gemma/flutter_gemma.dart';

// Model is automatically managed by GemmaLLMService
// No manual initialization needed in your widgets

// The ChatProvider automatically uses Gemma for responses
await context.read<ChatProvider>().sendMessage("Your question here");
```

### Chat Integration

Messages stream in real-time using the `generateChatResponseAsync()` API:

```dart
// In GemmaLLMService, this happens automatically:
final responses = chat.generateChatResponseAsync();

await for (final response in responses) {
  if (response is TextResponse) {
    // Update UI with each token
    onToken?.call(response.token);
  }
}
```

## Performance Settings

Adjust in `lib/services/gemma_llm_service.dart`:

```dart
class GemmaLLMService {
  static const int contextSize = 1024;    // Context window
  static const int maxTokens = 256;       // Max response length
  static const double temperature = 0.7;  // Creativity (0-1)
  static const int topK = 40;             // Sampling parameter
  static const double topP = 0.95;        // Nucleus sampling
}
```

### Recommended Settings by Device

**Low-end devices (2-4 GB RAM):**
```dart
maxTokens = 128;
preferredBackend = PreferredBackend.cpu;  // Use CPU only
```

**Mid-range devices (4-6 GB RAM):**
```dart
maxTokens = 256;
preferredBackend = PreferredBackend.gpu;  // Use GPU if available
```

**High-end devices (8 GB+ RAM):**
```dart
maxTokens = 512;
preferredBackend = PreferredBackend.gpu;  // Always use GPU
```

## Troubleshooting

### "Model not found" Error
```
Solution:
1. Ensure internet connection for first-time download
2. Check device has at least 2GB free storage
3. Try: flutter clean && flutter pub get
4. Delete build folder: rm -rf build/
5. Rebuild: flutter run
```

### "Failed to initialize Gemma LLM"
```
Solution:
1. Check iOS platform is 16.0+ (on iOS)
2. Ensure platform-specific setup completed (see above)
3. Check device has minimum required RAM
4. View detailed logs in app console
5. Try manual restart: flutter clean && flutter pub get
```

### Slow Performance / Timeouts
```
Solution:
1. Reduce maxTokens (e.g., 128 instead of 256)
2. Use CPU backend temporarily: preferredBackend = PreferredBackend.cpu
3. Wait longer (first model load takes 30+ seconds)
4. Close other apps to free RAM
5. Reduce context size if inference is very slow
```

### Build Errors on iOS
```
Solution:
1. Run: cd ios && pod install --repo-update && cd ..
2. Delete ios/Pods directory and rebuild
3. Ensure Podfile has: use_frameworks! :linkage => :static
4. Check minimum iOS version is 16.0
5. Try: flutter clean && flutter pub get
```

### Memory Errors on macOS
```
Solution:
1. Add to macos/Podfile post_install block (see setup)
2. Ensure Release.entitlements has memory keys
3. Restart Xcode and Flutter if error persists
```

### Out of Memory Crashes
```
Solution:
1. Use smaller model (Gemma 3 1B instead of 2B)
2. Reduce maxTokens to 128
3. Close other running apps
4. Clear app cache
5. Consider using different backend or CPU-only
```

## Architecture

### How It Works

```
User Question
    ↓
[ChatScreen] → User enters text
    ↓
[ChatProvider.sendMessage()]
    ↓
[GemmaLLMService.generateAnswer()]
    ├─ 1. Retrieve relevant PDF chunks (RAG)
    ├─ 2. Build context from chunks
    ├─ 3. Create prompt for Gemma
    └─ 4. Generate response with streaming
    ↓
[Flutter Gemma]
    ├─ Create chat session
    ├─ Add message
    └─ Stream responses via generateChatResponseAsync()
    ↓
[UI Updates in Real-Time]
    ↓
Response saved to local database
```

### File Structure

| File | Purpose |
|------|---------|
| `lib/services/gemma_llm_service.dart` | Gemma integration + RAG |
| `lib/main.dart` | Initializes FlutterGemma |
| `lib/providers/chat_provider.dart` | Chat business logic |
| `lib/screens/chat_screen.dart` | Chat UI |

## API Reference

### GemmaLLMService

```dart
class GemmaLLMService {
  // Lifecycle
  Future<void> initialize()           // Download model and init
  Future<void> dispose()              // Cleanup
  bool get isInitialized              // Check status
  
  // Generation
  Future<String> generateAnswer({
    required String question,
    required List<DocumentChunk> allChunks,
    Function(String)? onToken,         // Stream callback
  })
}
```

### Flutter Gemma Core APIs Used

```dart
// Install model (automatic, called once)
await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
  .fromNetwork(url)
  .install();

// Get model instance
final model = await FlutterGemma.getActiveModel(
  maxTokens: 256,
  preferredBackend: PreferredBackend.gpu,
);

// Create chat session
final chat = await model.createChat();

// Add message
await chat.addQueryChunk(Message.text(
  text: 'Your prompt',
  isUser: true,
));

// Stream responses
final responses = chat.generateChatResponseAsync();
await for (final response in responses) {
  if (response is TextResponse) {
    print(response.token);
  }
}

// Cleanup
await chat.close();
await model.close();
```

## Advanced: Using Different Models

To use a different Gemma model:

1. Update `gemma_llm_service.dart`:
```dart
// Change the model URL:
'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma-3-1b-it.task'

// Or use ModelType for pre-configured models:
// ModelType.gemmaIt    - Gemma models
// ModelType.qwen       - Qwen models
// ModelType.deepSeek   - DeepSeek models
// etc.
```

2. Test with the new model
3. Adjust `maxTokens` and `contextSize` if needed

## Models Available via flutter_gemma

- Gemma family (2B, 1B, 270M)
- Gemma3n (multimodal with vision)
- Qwen (0.6B, 1.5B, 2.5B)
- Phi-4 Mini
- DeepSeek R1
- SmolLM 135M
- FunctionGemma 270M
- FastVLM 0.5B

See [Pub.dev flutter_gemma](https://pub.dev/packages/flutter_gemma) for full list.

## Next Steps

1. ✅ Run `flutter pub get`
2. ✅ Complete platform-specific setup (iOS/Android)
3. ✅ Build and run: `flutter run`
4. ✅ Wait for model download on first run
5. ✅ Start chatting with your documents!

## Support & Resources

- [flutter_gemma Package](https://pub.dev/packages/flutter_gemma)
- [Google Gemma Homepage](https://ai.google.dev/gemma)
- [Hugging Face Models](https://huggingface.co/google)
- [MediaPipe GenAI](https://mediapipe.dev/solutions/generative_ai)

---

**Version:** 1.0  
**Last Updated:** February 2026  
**flutter_gemma:** 0.12.3+  
**Dart:** 3.3+

#### iOS
No additional setup required. FFI is automatically enabled.

**Build:**
```bash
flutter build ios
```

#### Android
Update `android/app/build.gradle`:

```gradle
android {
    ...
    defaultConfig {
        ...
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
    }
    
    packagingOptions {
        pickFirst 'lib/x86/libc++_shared.so'
        pickFirst 'lib/x86_64/libc++_shared.so'
        pickFirst 'lib/armeabi-v7a/libc++_shared.so'
        pickFirst 'lib/arm64-v8a/libc++_shared.so'
    }
}
```

**Build:**
```bash
flutter build apk
```

#### macOS/Linux/Windows
Should work out-of-the-box with FFI support.

### 4. Run the App

```bash
flutter run
```

On first run, the app will:
1. Initialize the Gemma model
2. Download the model if not present (~2-3 GB)
3. Load the model into memory
4. Ready for inference

## Model Information

### Supported Models
- **Gemma 2B Instruct** (Recommended for most devices)
  - Size: ~2 GB (4-bit quantized)
  - RAM: 4 GB minimum
  - Speed: ~15-30 seconds per response on mid-range devices

- **Gemma 7B Instruct** (For high-end devices)
  - Size: ~7 GB
  - RAM: 8 GB+ recommended
  - Speed: ~30-60 seconds per response

### Model Downloads
```
Model sizes (quantized):
- Gemma 2B Q4_K_M: 1.6 GB
- Gemma 2B Q5_K_M: 1.8 GB
- Gemma 7B Q4_K_M: 4.3 GB
- Gemma 7B Q5_K_M: 5.2 GB
```

Download from: https://huggingface.co/google

## Usage

### Basic Usage

```dart
import 'package:pdf_chatbot_offline/services/gemma_llm_service.dart';

// Initialize
final gemmaService = GemmaLLMService();
await gemmaService.initialize();

// Generate answer with RAG
final answer = await gemmaService.generateAnswer(
  question: "What is the main topic?",
  allChunks: documentChunks,
  onToken: (token) {
    // Update UI with streaming tokens
    print(token);
  },
);

// Cleanup
await gemmaService.dispose();
```

### Chat Provider Integration

The `ChatProvider` automatically uses Gemma for generating responses:

```dart
// Send message (automatically uses Gemma)
await context.read<ChatProvider>().sendMessage("Ask your question");

// The response streams in real-time
Consumer<ChatProvider>(
  builder: (context, provider, child) {
    return ListView.builder(
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        return ChatMessageTile(message: provider.messages[index]);
      },
    );
  },
)
```

## Configuration

### Adjust Performance Settings

Edit [gemma_llm_service.dart](lib/services/gemma_llm_service.dart):

```dart
class GemmaLLMService {
  static const int contextSize = 1024;    // Reduce for low-end devices
  static const int maxTokens = 256;       // Reduce for faster responses
  static const double temperature = 0.7;  // 0-1: Lower = more focused
  static const int topK = 40;             // Top-K sampling
  static const double topP = 0.95;        // Nucleus sampling
}
```

### Recommended Settings by Device

**Low-end devices (2-4 GB RAM):**
```dart
contextSize = 512;
maxTokens = 128;
// Use Gemma 2B model only
```

**Mid-range devices (4-6 GB RAM):**
```dart
contextSize = 1024;
maxTokens = 256;
// Use Gemma 2B model
```

**High-end devices (8 GB+ RAM):**
```dart
contextSize = 2048;
maxTokens = 512;
// Can use Gemma 7B model
```

## Troubleshooting

### "Model not found" Error
```
Solution:
1. Check that model file exists in Documents/models/
2. Verify file name matches: gemma-2b-it.gguf
3. Check file permissions
4. Try: flutter clean && flutter pub get
```

### "Failed to load native library"
```
Solution:
1. Ensure platform-specific CMake/build setup is complete
2. For Android: Check NDK is installed (API 21+)
3. For iOS: Ensure Xcode 13.3+
4. Run: flutter clean && flutter pub get
```

### Slow Performance / Out of Memory
```
Solution:
1. Reduce contextSize (e.g., 512 instead of 2048)
2. Reduce maxTokens (e.g., 128 instead of 256)
3. Use smaller model (Gemma 2B instead of 7B)
4. Close other apps to free RAM
5. Clear app cache
```

### Model Download Fails
```
Solution:
1. Check internet connection is stable
2. Try manual download from Hugging Face
3. Place model in Documents/models/ manually
4. Restart app
```

### TypeError or Runtime Errors
```
Solution:
1. Run: flutter clean
2. Run: flutter pub get
3. Delete build folders: rm -rf build/ .dart_tool/
4. Rebuild: flutter run
```

## Performance Statistics

### Response Generation Time (Approximate)
- Gemma 2B on Snapdragon 888: 15-20 seconds
- Gemma 2B on A14 Bionic: 10-15 seconds
- Gemma 2B on M1 Mac: 5-10 seconds
- Gemma 7B on high-end device: 30-60 seconds

### Memory Usage
- Gemma 2B model: ~3-4 GB RAM
- Gemma 7B model: ~7-8 GB RAM
- Embeddings cache: ~100-200 MB

### Storage Requirements
- Gemma 2B model file: ~2-3 GB
- App + dependencies: ~500 MB
- Total: ~3 GB minimum

## File Structure

```
lib/
├── services/
│   ├── gemma_llm_service.dart    # Main Gemma implementation
│   ├── database_service.dart      # Document storage
│   └── ...
├── providers/
│   ├── chat_provider.dart         # Uses Gemma service
│   └── document_provider.dart
├── screens/
│   ├── chat_screen.dart           # Chat UI
│   └── home_screen.dart
└── main.dart                       # Initializes Gemma
```

## API Reference

### GemmaLLMService

```dart
class GemmaLLMService {
  // Lifecycle
  Future<void> initialize()                    // Load model and initialize
  Future<void> dispose()                       // Cleanup resources
  bool get isInitialized                       // Check if initialized
  
  // Generation
  Future<String> generateAnswer({
    required String question,
    required List<DocumentChunk> allChunks,
    Function(String)? onToken,                 // Stream callback
  })
}
```

## Advanced: Custom Models

To use a different Gemma model:

1. Download from [Hugging Face](https://huggingface.co/google)
2. Place in Documents/models/ with expected name
3. Update in `gemma_llm_service.dart`:
   ```dart
   final modelPath = '${modelDir.path}/your-model-name.gguf';
   ```

## Next Steps

1. ✅ Run `flutter pub get` to install dependencies
2. ✅ Build and run: `flutter run`
3. ✅ Wait for model to download on first run (5-30 minutes)
4. ✅ Start chatting with your documents!

## Support & Resources

- [Flutter Gemma Package](https://pub.dev/packages/flutter_gemma)
- [Google Gemma Models](https://ai.google.dev/gemma)
- [Hugging Face Gemma Models](https://huggingface.co/google)
- [Project Documentation](./README.md)

---

**Version:** 1.0  
**Last Updated:** February 2026  
**Framework:** Flutter 3.3+  
**Dart:** 3.3+
