import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:ollama/ollama.dart';
import '../models/prompt_settings.dart';
import '../services/settings_service.dart';

class RecognitionService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  late Ollama _ollama;
  bool _openaiInitialized = false;
  final FlutterTts _flutterTts = FlutterTts();
  final SettingsService _settingsService;

  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _processedText = '';
  String _translatedText = '';
  bool _isProcessing = false;
  bool _llmAvailable = false;
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
  bool get llmAvailable => _llmAvailable;
  int get remainingSeconds => _remainingSeconds; // 残り時間を公開
  TranslationLanguage get selectedLanguage => _selectedLanguage;
  bool get isSpeaking => _isSpeaking;

  // 現在使用中のLLMプロバイダーの情報を返す
  String get currentLlmProvider =>
      _settingsService.llmSettings.provider == LlmProvider.ollama
          ? 'Ollama'
          : 'OpenAI';

  // 現在使用中のLLMモデル名を返す
  String get currentLlmModel =>
      _settingsService.llmSettings.provider == LlmProvider.ollama
          ? _settingsService.llmSettings.ollamaModel
          : _settingsService.llmSettings.openaiModel;

  RecognitionService(this._settingsService) {
    _selectedLanguage = availableLanguages[0]; // 英語をデフォルトとして選択
    // 設定サービスの初期化が完了してから他の初期化を行う
    _initialize();
  }

  Future<void> _initialize() async {
    // 設定サービスの初期化完了を待機
    await _settingsService.initialized;
    // 設定が確実に読み込まれた後にLLMなどを初期化
    await _initializeLlm();
    await _initializeSpeech();
    await _initializeTts();
  }

  // OpenAI APIを使用してChatCompletionを実行する
  Future<Map<String, dynamic>?> _callOpenAIChatAPI({
    required String prompt,
    int? maxTokens,
  }) async {
    final settings = _settingsService.llmSettings;
    if (settings.openaiApiKey.isEmpty) {
      debugPrint('OpenAI API key is empty');
      return null;
    }

    final apiKey = settings.openaiApiKey;
    final endpoint = settings.openaiEndpoint;
    final model = settings.openaiModel;

    try {
      // OpenAI APIのエンドポイントURI
      final uri = Uri.parse('$endpoint/chat/completions');

      // リクエストヘッダー
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      // リクエストボディ
      final Map<String, dynamic> requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
      };

      // オプションパラメータの追加
      if (maxTokens != null) {
        requestBody['max_tokens'] = maxTokens;
      }

      // APIリクエスト送信
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final errorBody = response.body;
        // HTMLエラーレスポンスの検出
        if (errorBody.contains('<!DOCTYPE html>') ||
            errorBody.contains('<html>') ||
            errorBody.contains('</html>')) {
          debugPrint(
              'OpenAI API error: HTMLレスポンスが返されました。エンドポイントURLが正しいか確認してください。');
          return null;
        }

        // JSONエラーレスポンスの解析を試みる
        try {
          final errorJson = jsonDecode(errorBody);
          final errorMessage =
              errorJson['error']?['message'] ?? 'Unknown error';
          debugPrint('OpenAI API error: $errorMessage');
        } catch (e) {
          debugPrint(
              'OpenAI API error: ステータスコード ${response.statusCode}, レスポンス: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      debugPrint('OpenAI API request error: $e');
      return null;
    }
  }

  // LLMの初期化
  Future<void> _initializeLlm() async {
    try {
      final llmSettings = _settingsService.llmSettings;
      debugPrint('LLM provider initializing: ${llmSettings.provider}');

      // Ollamaの初期化
      _ollama = Ollama(baseUrl: Uri.parse(llmSettings.ollamaEndpoint));

      if (llmSettings.provider == LlmProvider.openai &&
          llmSettings.openaiApiKey.isNotEmpty) {
        // OpenAIの初期化 - APIキーとエンドポイントがあれば初期化とみなす
        _openaiInitialized = true;
        debugPrint(
            'OpenAI initialized with endpoint: ${llmSettings.openaiEndpoint}');
        debugPrint('OpenAI model set to: ${llmSettings.openaiModel}');
      } else {
        _openaiInitialized = false;
        if (llmSettings.provider == LlmProvider.openai) {
          debugPrint('OpenAI API key is empty - not initializing OpenAI');
        }
      }

      await _checkLlmAvailability();
    } catch (e) {
      debugPrint('LLMの初期化中にエラーが発生しました: $e');
      _llmAvailable = false;
    }

    notifyListeners();
  }

  // LLMの再初期化
  Future<void> reinitializeLlm() async {
    _llmAvailable = false;
    notifyListeners();
    await _initializeLlm();
  }

  // OpenAI APIの動作テスト（設定画面から手動で呼び出せるように）
  Future<String> testOpenAI() async {
    if (_settingsService.llmSettings.provider != LlmProvider.openai ||
        _settingsService.llmSettings.openaiApiKey.isEmpty) {
      return 'OpenAI APIが設定されていません';
    }

    try {
      final settings = _settingsService.llmSettings;
      final apiKey = settings.openaiApiKey;
      final endpoint = settings.openaiEndpoint;
      final model = settings.openaiModel;

      // OpenAI APIのエンドポイントURI
      final uri = Uri.parse('$endpoint/chat/completions');

      // リクエストヘッダー
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      // リクエストボディ (response_formatを削除)
      final body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'Hello'}
        ],
        'max_tokens': 10,
      });

      // APIリクエスト送信
      final response = await http.post(
        uri,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return 'OpenAI API接続テスト成功！モデル: $model';
      } else {
        final errorBody = response.body;
        // HTMLエラーレスポンスの検出
        if (errorBody.contains('<!DOCTYPE html>') ||
            errorBody.contains('<html>') ||
            errorBody.contains('</html>')) {
          return 'OpenAI API接続エラー: HTMLレスポンスが返されました。エンドポイントURLが正しいか確認してください。';
        }

        // JSONエラーレスポンスの解析を試みる
        try {
          final errorJson = jsonDecode(errorBody);
          final errorMessage =
              errorJson['error']?['message'] ?? 'Unknown error';
          return 'OpenAI API接続エラー: $errorMessage';
        } catch (e) {
          return 'OpenAI API接続エラー: $e\n\nレスポンス: ${response.body}';
        }
      }
    } catch (e) {
      // エラーメッセージをそのまま返すようにして選択可能にする
      return '$e';
    }
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

  Future<void> _checkLlmAvailability() async {
    final llmSettings = _settingsService.llmSettings;

    try {
      if (llmSettings.provider == LlmProvider.ollama) {
        // Ollamaの利用可能性をチェック
        final response = await http
            .get(Uri.parse('${llmSettings.ollamaEndpoint}/v1/models'));

        if (response.statusCode == 200) {
          final models = jsonDecode(response.body);
          _llmAvailable = models.isNotEmpty;
          debugPrint('Ollama server is available with models: $models');
        } else {
          _llmAvailable = false;
          debugPrint(
              'Ollama server is not available. Status code: ${response.statusCode}');
        }
      } else if (llmSettings.provider == LlmProvider.openai) {
        // OpenAIの利用可能性をチェック
        if (_openaiInitialized && llmSettings.openaiApiKey.isNotEmpty) {
          try {
            // 簡単なリクエストを実行して接続をテスト
            final result = await _callOpenAIChatAPI(
              prompt: 'test',
              maxTokens: 5,
            );

            _llmAvailable = result != null;
            if (_llmAvailable) {
              debugPrint('OpenAI API is available');
            } else {
              debugPrint('OpenAI API test request failed');
            }
          } catch (e) {
            _llmAvailable = false;
            debugPrint('OpenAI API is not available: $e');
          }
        } else {
          _llmAvailable = false;
          debugPrint('OpenAI API configuration is incomplete');
        }
      }
    } catch (e) {
      _llmAvailable = false;
      debugPrint('Error checking LLM availability: $e');
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
      debugPrint(
          'Speech recognition not initialized. Please grant permissions');
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
    if (_recognizedText.isEmpty || !_llmAvailable) return;

    _isProcessing = true;
    notifyListeners();

    try {
      // SettingsServiceのプロンプト設定を使用
      final promptText = _settingsService.promptSettings
          .applyProcessingPrompt(_recognizedText);
      final llmSettings = _settingsService.llmSettings;

      _processedText = '';
      debugPrint('OpenAI Intialized: $_openaiInitialized');

      if (llmSettings.provider == LlmProvider.ollama) {
        // Ollamaを使用
        final stream = _ollama.generate(
          promptText,
          model: llmSettings.ollamaModel,
        );

        await for (final chunk in stream) {
          _processedText += chunk.toString();
        }
      } else if (llmSettings.provider == LlmProvider.openai &&
          _openaiInitialized) {
        // OpenAIを使用
        final result = await _callOpenAIChatAPI(
          prompt: promptText,
        );

        debugPrint(result.toString());

        if (result != null &&
            result['choices'] != null &&
            result['choices'].isNotEmpty) {
          // OpenAI API レスポンスから内容を抽出
          final firstChoice = result['choices'][0];
          final content = firstChoice['message']?['content'];

          debugPrint(content.toString());

          if (content != null) {
            // APIから返されるのはすでに文字列としてデコードされているため、
            // 追加のJSONデコードはスキップし、テキストを直接使用する
            _processedText = content.toString();
          }
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('<!DOCTYPE html>') ||
          errorStr.contains('<html>') ||
          errorStr.contains('</html>')) {
        _processedText =
            'テキスト処理中にエラーが発生しました: HTMLレスポンスが返されました。エンドポイントURLが正しいか確認してください。';
        debugPrint('Error processing text: HTMLレスポンスが返されました');
      } else {
        _processedText = 'テキスト処理中にエラーが発生しました: $e';
        debugPrint('Error processing text: $e');
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> translateText() async {
    if (_processedText.isEmpty || !_llmAvailable) return;

    _isProcessing = true;
    notifyListeners();

    try {
      // SettingsServiceのプロンプト設定を使用
      final promptText = _settingsService.promptSettings.applyTranslationPrompt(
          _processedText, _selectedLanguage.nameInJapanese);
      final llmSettings = _settingsService.llmSettings;

      _translatedText = '';

      if (llmSettings.provider == LlmProvider.ollama) {
        // Ollamaを使用
        final stream = _ollama.generate(
          promptText,
          model: llmSettings.ollamaModel,
        );

        await for (final chunk in stream) {
          _translatedText += chunk.toString();
        }
      } else if (llmSettings.provider == LlmProvider.openai &&
          _openaiInitialized) {
        // OpenAIを使用
        final result = await _callOpenAIChatAPI(
          prompt: promptText,
        );

        if (result != null &&
            result['choices'] != null &&
            result['choices'].isNotEmpty) {
          // OpenAI API レスポンスから内容を抽出
          final firstChoice = result['choices'][0];
          final content = firstChoice['message']?['content'];

          if (content != null) {
            // APIから返されるのはすでに文字列としてデコードされているため、
            // 追加のJSONデコードはスキップし、テキストを直接使用する
            _translatedText = content.toString();
          }
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('<!DOCTYPE html>') ||
          errorStr.contains('<html>') ||
          errorStr.contains('</html>')) {
        _translatedText =
            'テキスト翻訳中にエラーが発生しました: HTMLレスポンスが返されました。エンドポイントURLが正しいか確認してください。';
        debugPrint('Error translating text: HTMLレスポンスが返されました');
      } else {
        _translatedText = 'テキスト翻訳中にエラーが発生しました: $e';
        debugPrint('Error translating text: $e');
      }
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
    if (_llmAvailable && newText.isNotEmpty) {
      await processText();
    }
  }

  Future<void> updateProcessedText(String newText) async {
    // 変更がない場合は何もしない
    if (_processedText == newText) return;

    _processedText = newText;
    notifyListeners();

    // テキストが変更された場合、常に自動的に翻訳を実行
    if (_llmAvailable && newText.isNotEmpty) {
      await translateText();
    }
  }

  void updateTranslatedText(String newText) {
    _translatedText = newText;
    notifyListeners();
  }

  Future<void> regenerateProcessedText() async {
    if (_recognizedText.isEmpty || !_llmAvailable) return;
    await processText();
  }

  Future<void> regenerateTranslation() async {
    if (_processedText.isEmpty || !_llmAvailable) return;
    await translateText();
  }
}

class TranslationLanguage {
  final String nameInJapanese;
  final String code;
  final String nameInEnglish;

  TranslationLanguage(this.nameInJapanese, this.code, this.nameInEnglish);
}
