import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prompt_settings.dart';

class SettingsService extends ChangeNotifier {
  // 保存に使用するキー
  static const String _promptSettingsKey = 'promptSettings';

  // プロンプト設定
  late PromptSettings _promptSettings;
  PromptSettings get promptSettings => _promptSettings;

  // コンストラクタ - 初期化時に設定を読み込む
  SettingsService() {
    _promptSettings = PromptSettings(); // デフォルト値で初期化
    _loadSettings(); // 保存されている設定があれば読み込む
  }

  // 設定をSharedPreferencesから読み込む
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedSettings = prefs.getString(_promptSettingsKey);

      if (savedSettings != null) {
        final Map<String, dynamic> jsonMap = json.decode(savedSettings);
        _promptSettings = PromptSettings.fromJson(jsonMap);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('設定の読み込み中にエラーが発生しました: $e');
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

  // プロンプト設定をデフォルトにリセット
  Future<void> resetPromptsToDefaults() async {
    _promptSettings.resetToDefaults();
    await _saveSettings();
    notifyListeners();
  }

  // 設定をSharedPreferencesに保存
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _promptSettingsKey, json.encode(_promptSettings.toJson()));
    } catch (e) {
      debugPrint('設定の保存中にエラーが発生しました: $e');
    }
  }
}
