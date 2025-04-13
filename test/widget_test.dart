import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartdictator/models/prompt_settings.dart';
import 'package:smartdictator/screens/home_screen.dart';
import 'package:smartdictator/services/recognition_service.dart';
import 'package:smartdictator/services/settings_service.dart';

void main() {
  testWidgets('HomeScreen has necessary UI elements',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final settingsService = MockSettingsService();
    final recognitionService = MockRecognitionService();
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settingsService),
          ChangeNotifierProvider<RecognitionService>.value(value: recognitionService),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Verify that the app contains the main UI elements
    expect(find.text('Smart Dictator'), findsOneWidget);
    expect(find.text('押しながら話す'), findsOneWidget);
    expect(find.text('音声認識結果:'), findsOneWidget);
    expect(find.text('修正後テキスト:'), findsOneWidget);
    expect(find.text('翻訳:'), findsOneWidget);

    // Verify the record button
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });
}

class MockSettingsService extends ChangeNotifier implements SettingsService {
  @override
  PromptSettings get promptSettings => PromptSettings();

  @override
  Future<void> resetPromptsToDefaults() async {}

  @override
  Future<void> updatePromptSettings({String? processingPrompt, String? translationPrompt}) async {}
}

class MockRecognitionService extends ChangeNotifier
    implements RecognitionService {
  @override
  bool get isInitialized => true;

  @override
  bool get isListening => false;

  @override
  bool get isProcessing => false;

  @override
  bool get ollamaAvailable => true;

  @override
  String get processedText => '';

  @override
  String get recognizedText => '';

  @override
  String get translatedText => '';

  @override
  Future<void> processText() async {}

  @override
  void reset() {}

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> translateText() async {}

  @override
  Future<void> checkOllamaServer() async {}

  @override
  Future<void> regenerateProcessedText() async {}

  @override
  Future<void> regenerateTranslation() async {}

  @override
  Future<void> reinitializeSpeech() async {}

  @override
  List<TranslationLanguage> get availableLanguages => [
        TranslationLanguage('英語', 'en-US', 'English'),
      ];

  @override
  bool get isSpeaking => false;

  @override
  int get remainingSeconds => 60;

  @override
  TranslationLanguage get selectedLanguage => 
      TranslationLanguage('英語', 'en-US', 'English');

  @override
  void setTranslationLanguage(TranslationLanguage language) {}

  @override
  Future<void> speak(String text, {String? languageCode}) async {}

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> updateProcessedText(String newText) async {}

  @override
  Future<void> updateRecognizedText(String newText) async {}

  @override
  void updateTranslatedText(String newText) {}
}
