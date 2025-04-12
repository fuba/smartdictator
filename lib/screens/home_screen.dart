import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/recognition_service.dart';
import '../widgets/record_button.dart';
import '../widgets/text_display.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recognitionService = Provider.of<RecognitionService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Dictator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => recognitionService.reset(),
            tooltip: 'リセット',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const RecordButton(),
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
                    const Text('音声認識結果:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextDisplay(
                      text: recognitionService.recognizedText,
                      isEmpty: recognitionService.recognizedText.isEmpty,
                      emptyText: '録音ボタンを押して話すと、ここに音声認識結果が表示されます',
                    ),
                    const SizedBox(height: 16),
                    const Text('修正後テキスト:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextDisplay(
                      text: recognitionService.processedText,
                      isEmpty: recognitionService.processedText.isEmpty,
                      emptyText: '音声認識後、LLMによってテキストが整形され、ここに表示されます',
                      isProcessing: recognitionService.isProcessing && recognitionService.translatedText.isEmpty,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('英訳結果:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.translate, size: 16),
                          label: const Text('英訳'),
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
                      emptyText: '翻訳ボタンを押すと、修正後テキストが英語に翻訳されてここに表示されます',
                      isProcessing: recognitionService.isProcessing && recognitionService.translatedText.isNotEmpty,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}