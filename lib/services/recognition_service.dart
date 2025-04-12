import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

class RecognitionService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _processedText = '';
  String _translatedText = '';
  bool _isProcessing = false;
  bool _ollamaAvailable = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  String get processedText => _processedText;
  String get translatedText => _translatedText;
  bool get isProcessing => _isProcessing;
  bool get ollamaAvailable => _ollamaAvailable;

  RecognitionService() {
    _initializeSpeech();
    _checkOllamaAvailability();
  }

  Future<void> _initializeSpeech() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech recognition status: $status'),
      );
      notifyListeners();
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<void> _checkOllamaAvailability() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:11434/api/tags'));
      _ollamaAvailable = response.statusCode == 200;
    } catch (e) {
      _ollamaAvailable = false;
      print('Ollama server is not available: $e');
    }
    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      await _initializeSpeech();
    }

    if (_isInitialized && !_isListening) {
      try {
        _isListening = await _speech.listen(
          localeId: 'ja-JP',
          onResult: (result) {
            _recognizedText = result.recognizedWords;
            notifyListeners();
          },
        );
        notifyListeners();
      } catch (e) {
        print('Error starting speech recognition: $e');
        _isListening = false;
        notifyListeners();
      }
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
      
      if (_recognizedText.isNotEmpty) {
        await processText();
      }
    }
  }

  Future<void> processText() async {
    if (_recognizedText.isEmpty || !_ollamaAvailable) return;

    _isProcessing = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'gemma3:4b',
          'prompt': '以下の逐語録テキストを読みやすい日本語文に修正してください。話者が途中で言い直した部分や脱線した部分は取り除き、一つの自然な文章（または段落）に再構成してください。出力は修正後の文章のみを返してください。\n\n「$_recognizedText」'
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('response')) {
          _processedText = jsonResponse['response'] as String;
        } else {
          _processedText = 'テキスト処理中にエラーが発生しました。Ollamaサーバーのレスポンス形式が予期しないものでした。';
        }
      } else {
        _processedText = 'テキスト処理中にエラーが発生しました。ステータスコード: ${response.statusCode}';
      }
    } catch (e) {
      _processedText = 'テキスト処理中にエラーが発生しました: $e';
      print('Error processing text: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> translateText() async {
    if (_processedText.isEmpty || !_ollamaAvailable) return;

    _isProcessing = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'gemma3:4b',
          'prompt': '以下の日本語文を英語に翻訳してください。翻訳後の英文のみを出力してください。\n\n「$_processedText」'
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('response')) {
          _translatedText = jsonResponse['response'] as String;
        } else {
          _translatedText = 'テキスト翻訳中にエラーが発生しました。Ollamaサーバーのレスポンス形式が予期しないものでした。';
        }
      } else {
        _translatedText = 'テキスト翻訳中にエラーが発生しました。ステータスコード: ${response.statusCode}';
      }
    } catch (e) {
      _translatedText = 'テキスト翻訳中にエラーが発生しました: $e';
      print('Error translating text: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void reset() {
    _recognizedText = '';
    _processedText = '';
    _translatedText = '';
    notifyListeners();
  }
}