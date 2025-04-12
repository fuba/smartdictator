import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:ollama/ollama.dart';

class RecognitionService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final Ollama _ollama = Ollama();
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
      print('Initializing speech recognition...');
      
      // 権限チェックを明示的に行う
      bool hasSpeechPermission = await _speech.hasPermission;
      print('Initial permission check: $hasSpeechPermission');
      
      print('Speech availability before initialize: ${await _speech.initialize()}');
      
      _isInitialized = await _speech.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech recognition status: $status'),
        debugLogging: true,
      );
      
      print('Speech recognition initialized: $_isInitialized');
      
      // 詳細なデバッグ情報を表示
      final locales = await _speech.locales();
      print('Available locales: ${locales.map((e) => e.localeId).join(', ')}');
      print('Has permission after initialize: ${await _speech.hasPermission}');
      
      notifyListeners();
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<void> _checkOllamaAvailability() async {
    try {
      await _ollama.models();
      _ollamaAvailable = true;
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

    if (!_isInitialized) {
      // 音声認識が初期化できない場合は、権限が必要なことを通知
      print('Speech recognition not initialized. Please grant permissions.');
      return;
    }

    if (!_isListening) {
      try {
        // 日本語ロケールが利用可能か確認
        final locales = await _speech.locales();
        final hasJapanese = locales.any((locale) => 
            locale.localeId.toLowerCase().contains('ja') || 
            locale.localeId.toLowerCase().contains('japanese'));
        
        final localeId = hasJapanese ? 'ja-JP' : '';
        print('Using locale: ${localeId.isEmpty ? "Default" : localeId}');
        
        _isListening = await _speech.listen(
          localeId: localeId,
          onResult: (result) {
            print('Recognition result: ${result.recognizedWords}');
            _recognizedText = result.recognizedWords;
            notifyListeners();
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
        );
        print('Listening started: $_isListening');
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
      final promptText = '以下の逐語録テキストを読みやすい日本語文に修正してください。話者が途中で言い直した部分や脱線した部分は取り除き、一つの自然な文章（または段落）に再構成してください。出力は修正後の文章のみを返してください。\n\n「$_recognizedText」';
      
      final response = await _ollama.generate(
        model: 'gemma3:4b',
        prompt: promptText,
      );

      _processedText = response.response;
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
      final promptText = '以下の日本語文を英語に翻訳してください。翻訳後の英文のみを出力してください。\n\n「$_processedText」';
      
      final response = await _ollama.generate(
        model: 'gemma3:4b',
        prompt: promptText,
      );

      _translatedText = response.response;
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
  
  Future<void> reinitializeSpeech() async {
    _isInitialized = false;
    notifyListeners();
    await _initializeSpeech();
    await _checkOllamaAvailability();
  }
}