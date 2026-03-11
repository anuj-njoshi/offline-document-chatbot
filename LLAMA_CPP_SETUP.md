# llama_cpp_dart Integration Guide

## Setup Instructions

### iOS Setup
1. Update `ios/Podfile` to include build settings:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'NDEBUG',
      ]
    end
  end
end
```

2. Build the project with FFI support:
```bash
flutter pub get
flutter build ios --no-codesign
```

### Android Setup
1. Ensure `android/app/build.gradle` includes:
```gradle
android {
    ...
    packagingOptions {
        pickFirst 'lib/x86/libc++_shared.so'
        pickFirst 'lib/x86_64/libc++_shared.so'
        pickFirst 'lib/armeabi-v7a/libc++_shared.so'
        pickFirst 'lib/arm64-v8a/libc++_shared.so'
    }
}
```

2. Build the project:
```bash
flutter pub get
flutter build apk
```

### macOS/Windows/Linux
Should work out-of-the-box with FFI support.

## Model File Configuration

### Supported Models
Use GGML-format models compatible with llama.cpp:
- **ggml-gpt4all-j-v1.3-groovy.bin** (easiest, ~3.5GB)
- **ggml-model-q4_0.bin** (better quality, ~7GB)
- **mistral-7b-instruct.Q4_K_M.gguf** (~5GB)

Download from:
- https://huggingface.co/TheBloke (recommended)
- https://gpt4all.io/models/

### Manual Model Setup
If automatic download fails, manually place model in:
```
iOS/Android: Documents/models/ggml-gpt4all-j-v1.3-groovy.bin
macOS: ~/Documents/[AppName]/models/ggml-gpt4all-j-v1.3-groovy.bin
```

## Usage Example

```dart
// Initialize service
final llmService = RealLLMService();
await llmService.initialize(); // Downloads/loads model

// Generate answer with streaming
final answer = await llmService.generateAnswer(
  question: "What is the main topic?",
  allChunks: documentChunks,
  onToken: (token) {
    // Update UI with streaming tokens
    setState(() => response += token);
  },
);
```

## Troubleshooting

### "Model not found" Error
- Check permissions in app sandbox
- Manually place model file in correct directory
- Run: `flutter clean && flutter pub get`

### Native Compilation Error
- Ensure C++ compiler is installed
- For Android: Use NDK version 21+
- For iOS: Xcode 13.3+

### Slow Performance
- Reduce `context_size` from 2048 to 512-1024
- Reduce `numThreads` if high CPU usage
- Use quantized models (q4, q5) instead of full models

### Memory Issues
- Use smaller model variant
- Reduce `maxTokens` from 512 to 256
- Clear cache between requests: `_model.clear_kv_cache()`

## Important Notes
- First initialize() call will download model (~3.5GB) - takes 5-30 minutes
- Requires device with 4GB+ RAM for smooth operation
- Model inference takes 15-60 seconds per response (device dependent)
- Use quantized models for faster inference

## Recommended Settings for Devices

**Low-end devices (2GB RAM):**
```dart
contextSize = 512;
maxTokens = 128;
numThreads = 2;
// Use q4 quantized models
```

**Mid-range devices (4GB RAM):**
```dart
contextSize = 1024;
maxTokens = 256;
numThreads = 4;
// Can use q5 models
```

**High-end devices (8GB+ RAM):**
```dart
contextSize = 2048;
maxTokens = 512;
numThreads = 6;
// Can use full-size or q8 models
```

## Alternative Wrapper (Optional)

If you want a cleaner async wrapper around llama_cpp_dart:

```dart
class LlamaWrapper {
  late Llama _llama;
  
  Future<void> initialize(String modelPath) async {
    _llama = Llama(
      model: modelPath,
      n_ctx: 2048,
      n_threads: 4,
    );
  }
  
  Future<String> inferenceAsync(String prompt) async {
    // Run in isolate to prevent UI freeze
    return await compute(_runInference, {
      'llama': _llama,
      'prompt': prompt,
    });
  }
  
  static String _runInference(Map<String, dynamic> data) {
    final llama = data['llama'] as Llama;
    final prompt = data['prompt'] as String;
    return llama.generate(prompt: prompt, nPredict: 512);
  }
}
```

## Next Steps
1. Run `flutter pub get`
2. Update your app configuration (see platform setup above)
3. Build and test: `flutter run`
4. Monitor logs for initialization progress
