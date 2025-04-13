import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prompt_settings.dart';

class SettingsService extends ChangeNotifier {
  // 保存に使用するキー
  static const String _promptSettingsKey = 'promptSettings';
  static const String _llmSettingsKey = 'llmSettings';
  
  // 設定の非同期読み込みを追跡するためのCompleter
  Completer<void>? _loadingComplete;

  // プロンプト設定
  late PromptSettings _promptSettings;
  PromptSettings get promptSettings => _promptSettings;

  // LLM設定
  late LlmSettings _llmSettings;
  LlmSettings get llmSettings => _llmSettings;

  // コンストラクタ - 初期化時に設定を読み込む
  SettingsService() {
    _promptSettings = PromptSettings(); // デフォルト値で初期化
    _llmSettings = LlmSettings(); // デフォルト値で初期化
    _loadSettings(); // 保存されている設定があれば読み込む
  }
  
  // 設定の初期化が完了したことを確認するためのFuture
  Future<void> get initialized => _loadingComplete?.future ?? Future.value();

  // 設定をSharedPreferencesから読み込む
  Future<void> _loadSettings() async {
    _loadingComplete = Completer<void>();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // プロンプト設定の読み込み
      final String? savedPromptSettings = prefs.getString(_promptSettingsKey);
      if (savedPromptSettings != null) {
        final Map<String, dynamic> jsonMap = json.decode(savedPromptSettings);
        _promptSettings = PromptSettings.fromJson(jsonMap);
      }

      // LLM設定の読み込み
      final String? savedLlmSettings = prefs.getString(_llmSettingsKey);
      if (savedLlmSettings != null) {
        final Map<String, dynamic> jsonMap = json.decode(savedLlmSettings);
        _llmSettings = LlmSettings.fromJson(jsonMap);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('設定の読み込み中にエラーが発生しました: $e');
    } finally {
      _loadingComplete?.complete();
    }
  }

  // プロンプト設定を更新して保存
  Future<void> updatePromptSettings({
    String? processingPrompt,
    String? translationPrompt,
  }) async {
    if (processingPrompt != null) {
      _promptSettings.processingPrompt = processingPrompt;
    }

    if (translationPrompt != null) {
      _promptSettings.translationPrompt = translationPrompt;
    }

    await _saveSettings();
    notifyListeners();
  }

  // LLM設定を更新して保存
  Future<void> updateLlmSettings({
    LlmProvider? provider,
    String? ollamaEndpoint,
    String? ollamaModel,
    String? openaiEndpoint,
    String? openaiModel,
    String? openaiApiKey,
  }) async {
    if (provider != null) {
      _llmSettings.provider = provider;
    }

    if (ollamaEndpoint != null) {
      _llmSettings.ollamaEndpoint = ollamaEndpoint;
    }

    if (ollamaModel != null) {
      _llmSettings.ollamaModel = ollamaModel;
    }

    if (openaiEndpoint != null) {
      _llmSettings.openaiEndpoint = openaiEndpoint;
    }

    if (openaiModel != null) {
      _llmSettings.openaiModel = openaiModel;
    }

    if (openaiApiKey != null) {
      _llmSettings.openaiApiKey = openaiApiKey;
    }

    await _saveSettings();
    notifyListeners();
  }

  // プロンプト設定をデフォルトにリセット
  Future<void> resetPromptsToDefaults() async {
    _promptSettings.resetToDefaults();
    await _saveSettings();
    notifyListeners();
  }

  // LLM設定をデフォルトにリセット
  Future<void> resetLlmToDefaults() async {
    _llmSettings.resetToDefaults();
    await _saveSettings();
    notifyListeners();
  }

  // すべての設定をデフォルトにリセット
  Future<void> resetAllToDefaults() async {
    _promptSettings.resetToDefaults();
    _llmSettings.resetToDefaults();
    await _saveSettings();
    notifyListeners();
  }

  // 設定をSharedPreferencesに保存
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // プロンプト設定の保存
      await prefs.setString(
          _promptSettingsKey, json.encode(_promptSettings.toJson()));
      
      // LLM設定の保存
      await prefs.setString(
          _llmSettingsKey, json.encode(_llmSettings.toJson()));
    } catch (e) {
      debugPrint('設定の保存中にエラーが発生しました: $e');
    }
  }
}
