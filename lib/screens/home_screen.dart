import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/recognition_service.dart';
import '../widgets/record_button.dart';
import '../widgets/text_display.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // どのテキストブロックが読み上げ中かを追跡する変数
  String _currentlySpeakingBlock = '';

  @override
  Widget build(BuildContext context) {
    final recognitionService = Provider.of<RecognitionService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Dictator'),
        actions: [
          // 設定画面へのボタンを追加
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: '設定',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => recognitionService.reset(),
            tooltip: 'テキストをリセット',
          ),
          IconButton(
            icon: const Icon(Icons.mic_off),
            onPressed: () => recognitionService.reinitializeSpeech(),
            tooltip: '音声認識を再初期化',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            if (!recognitionService.ollamaAvailable)
              const Card(
                color: Colors.amber,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'OllamaサーバーとGemma3:4bモデルが見つかりません。\n'
                    'テキスト整形と翻訳機能を使用するには、Ollamaサーバーを起動し、'
                    'Gemma3:4bモデルをインストールしてください。',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('音声認識結果:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextDisplay(
                      text: recognitionService.recognizedText,
                      isEmpty: recognitionService.recognizedText.isEmpty,
                      emptyText: '録音ボタンを押して話すと、ここに音声認識結果が表示されます',
                      onTextChanged: (newText) {
                        recognitionService.updateRecognizedText(newText);
                      },
                      onRegeneratePressed: recognitionService
                              .recognizedText.isEmpty
                          ? null
                          : () => recognitionService.regenerateProcessedText(),
                      onSpeakPressed: recognitionService.recognizedText.isEmpty
                          ? null
                          : () {
                              if (recognitionService.isSpeaking) {
                                recognitionService.stopSpeaking();
                                setState(() {
                                  _currentlySpeakingBlock = '';
                                });
                              } else {
                                setState(() {
                                  _currentlySpeakingBlock = 'recognized';
                                });
                                recognitionService.speak(
                                    recognitionService.recognizedText,
                                    languageCode: 'ja-JP');
                              }
                            },
                      isSpeaking: recognitionService.isSpeaking &&
                          _currentlySpeakingBlock == 'recognized',
                    ),
                    const SizedBox(height: 16),
                    const Text('修正後テキスト:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextDisplay(
                      text: recognitionService.processedText,
                      isEmpty: recognitionService.processedText.isEmpty,
                      emptyText: recognitionService.isProcessing &&
                              recognitionService.recognizedText.isNotEmpty
                          ? recognitionService.isListening
                              ? '録音中... あと${recognitionService.remainingSeconds}秒'
                              : '音声認識結果を処理中...'
                          : '音声認識後、LLMによってテキストが整形され、ここに表示されます',
                      isProcessing: recognitionService.isProcessing &&
                          recognitionService.translatedText.isEmpty,
                      onTextChanged: (newText) {
                        recognitionService.updateProcessedText(newText);
                      },
                      onSpeakPressed: recognitionService.processedText.isEmpty
                          ? null
                          : () {
                              if (recognitionService.isSpeaking) {
                                recognitionService.stopSpeaking();
                                setState(() {
                                  _currentlySpeakingBlock = '';
                                });
                              } else {
                                setState(() {
                                  _currentlySpeakingBlock = 'processed';
                                });
                                recognitionService.speak(
                                    recognitionService.processedText,
                                    languageCode: 'ja-JP');
                              }
                            },
                      isSpeaking: recognitionService.isSpeaking &&
                          _currentlySpeakingBlock == 'processed',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('翻訳:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        DropdownButton<TranslationLanguage>(
                          value: recognitionService.selectedLanguage,
                          onChanged: (TranslationLanguage? newLanguage) {
                            if (newLanguage != null) {
                              recognitionService
                                  .setTranslationLanguage(newLanguage);
                              if (recognitionService.processedText.isNotEmpty) {
                                recognitionService.translateText();
                              }
                            }
                          },
                          items: recognitionService.availableLanguages
                              .map<DropdownMenuItem<TranslationLanguage>>(
                                  (TranslationLanguage language) {
                            return DropdownMenuItem<TranslationLanguage>(
                              value: language,
                              child: Text(language.nameInJapanese),
                            );
                          }).toList(),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.translate, size: 16),
                          label: Text(
                              '${recognitionService.selectedLanguage.nameInJapanese}に翻訳'),
                          onPressed: recognitionService.processedText.isEmpty
                              ? null
                              : () => recognitionService.translateText(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextDisplay(
                      text: recognitionService.translatedText,
                      isEmpty: recognitionService.translatedText.isEmpty,
                      emptyText:
                          '翻訳ボタンを押すと、修正後テキストが${recognitionService.selectedLanguage.nameInJapanese}に翻訳されてここに表示されます',
                      isProcessing: recognitionService.isProcessing &&
                          recognitionService.translatedText.isNotEmpty,
                      onTextChanged: (newText) {
                        recognitionService.updateTranslatedText(newText);
                      },
                      onRegeneratePressed: recognitionService
                              .translatedText.isEmpty
                          ? null
                          : () => recognitionService.regenerateTranslation(),
                      onSpeakPressed: recognitionService.translatedText.isEmpty
                          ? null
                          : () {
                              if (recognitionService.isSpeaking) {
                                recognitionService.stopSpeaking();
                                setState(() {
                                  _currentlySpeakingBlock = '';
                                });
                              } else {
                                setState(() {
                                  _currentlySpeakingBlock = 'translated';
                                });
                                recognitionService.speak(
                                    recognitionService.translatedText,
                                    languageCode: recognitionService
                                        .selectedLanguage.code);
                              }
                            },
                      isSpeaking: recognitionService.isSpeaking &&
                          _currentlySpeakingBlock == 'translated',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const RecordButton(),
          ],
        ),
      ),
    );
  }
}
