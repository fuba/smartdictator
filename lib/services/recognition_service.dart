import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:ollama/ollama.dart';
import '../services/settings_service.dart';

class RecognitionService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final Ollama _ollama = Ollama();
  final FlutterTts _flutterTts = FlutterTts();
  final SettingsService _settingsService;

  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _processedText = '';
  String _translatedText = '';
  bool _isProcessing = false;
  bool _ollamaAvailable = false;
  bool _isSpeaking = false;

  // 録音時間の制限とカウントダウン用の変数
  static const int maxRecordingSeconds = 60; // 最大録音時間（秒）
  int _remainingSeconds = maxRecordingSeconds;
  Timer? _recordingTimer;

  // 翻訳言語の設定
  final List<TranslationLanguage> availableLanguages = [
    TranslationLanguage('英語', 'en-US', 'English'),
    TranslationLanguage('フランス語', 'fr-FR', 'French'),
    TranslationLanguage('スペイン語', 'es-ES', 'Spanish'),
    TranslationLanguage('ドイツ語', 'de-DE', 'German'),
    TranslationLanguage('イタリア語', 'it-IT', 'Italian'),
    TranslationLanguage('中国語', 'zh-CN', 'Chinese'),
    TranslationLanguage('韓国語', 'ko-KR', 'Korean'),
  ];
  late TranslationLanguage _selectedLanguage;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  String get processedText => _processedText;
  String get translatedText => _translatedText;
  bool get isProcessing => _isProcessing;
  bool get ollamaAvailable => _ollamaAvailable;
  int get remainingSeconds => _remainingSeconds; // 残り時間を公開
  TranslationLanguage get selectedLanguage => _selectedLanguage;
  bool get isSpeaking => _isSpeaking;

  RecognitionService(this._settingsService) {
    _selectedLanguage = availableLanguages[0]; // 英語をデフォルトとして選択
    _initializeSpeech();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('ja-JP'); // デフォルト言語を日本語に設定
    await _flutterTts.setSpeechRate(0.5); // 読み上げ速度を設定
    await _flutterTts.setVolume(1.0); // 音量を設定
    await _flutterTts.setPitch(1.0); // 音の高さを設定

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _flutterTts.setErrorHandler((message) {
      _isSpeaking = false;
      notifyListeners();
      debugPrint('TTS Error: $message');
    });
  }

  Future<void> speak(String text, {String? languageCode}) async {
    if (text.isEmpty) return;

    // 現在話している場合は停止
    if (_isSpeaking) {
      await stopSpeaking();
    }

    // 言語コードが指定されていない場合は選択された言語を使用
    final language = languageCode ?? _selectedLanguage.code;
    await _flutterTts.setLanguage(language);
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
      notifyListeners();
    }
  }

  void setTranslationLanguage(TranslationLanguage language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  Future<void> checkOllamaServer() async {
    try {
      final response =
          await http.get(Uri.parse('http://localhost:11434/v1/models'));
      if (response.statusCode == 200) {
        final models = jsonDecode(response.body);
        _ollamaAvailable = models.isNotEmpty;
        debugPrint('Ollama server is available with models: $models');
      } else {
        _ollamaAvailable = false;
        debugPrint(
            'Ollama server is not available. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _ollamaAvailable = false;
      debugPrint('Error checking Ollama server: $e');
    }
    notifyListeners();
  }

  Future<void> _initializeSpeech() async {
    try {
      debugPrint('Initializing speech recognition...');

      // 権限チェックを明示的に行う
      bool? hasSpeechPermission = await _speech.hasPermission;
      debugPrint('Initial permission check: $hasSpeechPermission');

      // 一度初期化を試行
      bool? available = await _speech.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
        debugLogging: true,
      );

      _isInitialized = available == true;
      debugPrint('Speech recognition initialized: $_isInitialized');

      if (_isInitialized) {
        // Ollamaサーバーのチェック
        await checkOllamaServer();

        // 詳細なデバッグ情報を表示
        try {
          final locales = await _speech.locales();
          debugPrint(
              'Available locales: ${locales.map((e) => e.localeId).join(', ')}');
        } catch (e) {
          debugPrint('Error getting locales: $e');
        }

        try {
          bool? hasPermission = await _speech.hasPermission;
          debugPrint('Has permission after initialize: $hasPermission');
        } catch (e) {
          debugPrint('Error checking permission: $e');
        }
      } else {
        debugPrint('Speech recognition initialization failed');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize speech recognition: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<void> startListening() async {
    debugPrint('startListening called');
    if (!_isInitialized) {
      debugPrint('Not initialized, attempting to initialize speech');
      await _initializeSpeech();
    }

    if (!_isInitialized) {
      // 音声認識が初期化できない場合は、権限が必要なことを通知
      debugPrint('Speech recognition not initialized. Please grant permissions');
      return;
    }

    if (!_isListening) {
      debugPrint('Starting listening...');
      try {
        // 残り時間をリセットしタイマーを開始
        _remainingSeconds = maxRecordingSeconds;
        _startRecordingTimer();

        // 日本語ロケールが利用可能か確認
        final locales = await _speech.locales();
        final hasJapanese = locales.any((locale) =>
            locale.localeId.toLowerCase().contains('ja') ||
            locale.localeId.toLowerCase().contains('japanese'));

        final localeId = hasJapanese ? 'ja-JP' : '';
        debugPrint('Using locale: ${localeId.isEmpty ? "Default" : localeId}');

        await _speech.listen(
          localeId: localeId,
          onResult: (result) {
            debugPrint('Recognition result: ${result.recognizedWords}');
            _recognizedText = result.recognizedWords;
            notifyListeners();
          },
          listenFor: const Duration(seconds: 120),
          pauseFor: const Duration(seconds: 5),
          cancelOnError: true,
        );

        _isListening = true;
        debugPrint('Listening started: $_isListening');
        notifyListeners();
      } catch (e) {
        debugPrint('Error starting speech recognition: $e');
        _isListening = false;
        _cancelRecordingTimer(); // エラー時にタイマーをキャンセル
        notifyListeners();
      }
    }
  }

  Future<void> stopListening() async {
    debugPrint('stopListening called');
    if (_isListening) {
      debugPrint('Stopping listening...');
      try {
        await _speech.stop();
        debugPrint('Speech stopped successfully');
      } catch (e) {
        debugPrint('Error stopping speech: $e');
      }

      _isListening = false;
      _cancelRecordingTimer(); // リスニング停止時にタイマーをキャンセル
      notifyListeners();
      debugPrint('isListening set to false');

      if (_recognizedText.isNotEmpty) {
        debugPrint('Recognized text is not empty, starting processing');
        // 処理状態を即座に更新して通知
        _isProcessing = true;
        notifyListeners();

        await processText();
      } else {
        debugPrint('Recognized text is empty, not processing');
      }
    } else {
      debugPrint('Not listening, nothing to stop');
    }
  }

  // タイマーを開始するメソッド
  void _startRecordingTimer() {
    _cancelRecordingTimer(); // 既存のタイマーがあればキャンセル

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        // 時間切れで録音を停止
        stopListening();
      }
    });
  }

  // タイマーをキャンセルするメソッド
  void _cancelRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  Future<void> processText() async {
    if (_recognizedText.isEmpty || !_ollamaAvailable) return;

    _isProcessing = true;
    notifyListeners();

    try {
      // SettingsServiceのプロンプト設定を使用
      final promptText = _settingsService.promptSettings
          .applyProcessingPrompt(_recognizedText);

      final stream = _ollama.generate(
        promptText,
        model: 'gemma3:4b',
      );

      _processedText = '';
      await for (final chunk in stream) {
        _processedText += chunk.toString();
      }
    } catch (e) {
      _processedText = 'テキスト処理中にエラーが発生しました: $e';
      debugPrint('Error processing text: $e');
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
      // SettingsServiceのプロンプト設定を使用
      final promptText = _settingsService.promptSettings.applyTranslationPrompt(
          _processedText, _selectedLanguage.nameInJapanese);

      final stream = _ollama.generate(
        promptText,
        model: 'gemma3:4b',
      );

      _translatedText = '';
      await for (final chunk in stream) {
        _translatedText += chunk.toString();
      }
    } catch (e) {
      _translatedText = 'テキスト翻訳中にエラーが発生しました: $e';
      debugPrint('Error translating text: $e');
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
    _cancelRecordingTimer(); // 再初期化時にタイマーをキャンセル
    _remainingSeconds = maxRecordingSeconds; // 残り時間をリセット
    notifyListeners();
    await _initializeSpeech();
  }

  // テキスト編集用のメソッド
  Future<void> updateRecognizedText(String newText) async {
    // 変更がない場合は何もしない
    if (_recognizedText == newText) return;

    _recognizedText = newText;
    notifyListeners();

    // テキストが変更された場合、自動的に処理を実行
    if (_ollamaAvailable && newText.isNotEmpty) {
      await processText();
    }
  }

  Future<void> updateProcessedText(String newText) async {
    // 変更がない場合は何もしない
    if (_processedText == newText) return;

    _processedText = newText;
    notifyListeners();

    // テキストが変更された場合、常に自動的に翻訳を実行
    if (_ollamaAvailable && newText.isNotEmpty) {
      await translateText();
    }
  }

  void updateTranslatedText(String newText) {
    _translatedText = newText;
    notifyListeners();
  }

  Future<void> regenerateProcessedText() async {
    if (_recognizedText.isEmpty || !_ollamaAvailable) return;
    await processText();
  }

  Future<void> regenerateTranslation() async {
    if (_processedText.isEmpty || !_ollamaAvailable) return;
    await translateText();
  }
}

class TranslationLanguage {
  final String nameInJapanese;
  final String code;
  final String nameInEnglish;

  TranslationLanguage(this.nameInJapanese, this.code, this.nameInEnglish);
}
