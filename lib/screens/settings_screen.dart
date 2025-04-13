import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../models/prompt_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _processingPromptController;
  late TextEditingController _translationPromptController;
  bool _isProcessingPromptEdited = false;
  bool _isTranslationPromptEdited = false;
  
  // 日本語入力用の現在の値を保持する変数
  String? _processingPromptCurrent;
  String? _translationPromptCurrent;

  @override
  void initState() {
    super.initState();
    // 初期化時に現在の設定値をコントローラーに設定
    final settings =
        Provider.of<SettingsService>(context, listen: false).promptSettings;
    _processingPromptController =
        TextEditingController(text: settings.processingPrompt);
    _translationPromptController =
        TextEditingController(text: settings.translationPrompt);
    
    _processingPromptCurrent = settings.processingPrompt;
    _translationPromptCurrent = settings.translationPrompt;

    _processingPromptController.addListener(_onProcessingPromptChanged);
    _translationPromptController.addListener(_onTranslationPromptChanged);
  }

  @override
  void dispose() {
    _processingPromptController.removeListener(_onProcessingPromptChanged);
    _translationPromptController.removeListener(_onTranslationPromptChanged);
    _processingPromptController.dispose();
    _translationPromptController.dispose();
    super.dispose();
  }

  void _onProcessingPromptChanged() {
    final settings =
        Provider.of<SettingsService>(context, listen: false).promptSettings;
    setState(() {
      _isProcessingPromptEdited =
          _processingPromptController.text != settings.processingPrompt;
    });
  }

  void _onTranslationPromptChanged() {
    final settings =
        Provider.of<SettingsService>(context, listen: false).promptSettings;
    setState(() {
      _isTranslationPromptEdited =
          _translationPromptController.text != settings.translationPrompt;
    });
  }

  // 日本語入力に対応したTextFieldウィジェット
  Widget _buildJapaneseTextField({
    required TextEditingController controller,
    required int maxLines,
    required String hintText,
    required bool isEdited,
    required VoidCallback onResetPressed,
  }) {
    String? currentValue;
    if (controller == _processingPromptController) {
      currentValue = _processingPromptCurrent;
    } else if (controller == _translationPromptController) {
      currentValue = _translationPromptCurrent;
    }

    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (value) {
        // 日本語入力時の重複を検出して修正
        if (currentValue != null && currentValue!.length < value.length) {
          final suffix = value.substring(currentValue!.length);
          if (suffix.length > 1 && value == "$currentValue$suffix") {
            // 重複を検出したら前回の値に戻す
            controller.text = currentValue!;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: currentValue!.length),
            );
            return;
          }
        }
        
        // 現在の値を更新
        if (controller == _processingPromptController) {
          _processingPromptCurrent = value;
        } else if (controller == _translationPromptController) {
          _translationPromptCurrent = value;
        }
      },
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hintText,
        suffixIcon: isEdited
            ? IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'デフォルトに戻す',
                onPressed: () {
                  onResetPressed();
                  // リセット後の値を保存
                  if (controller == _processingPromptController) {
                    _processingPromptCurrent = controller.text;
                  } else if (controller == _translationPromptController) {
                    _translationPromptCurrent = controller.text;
                  }
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          // 変更をリセットするボタン
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('設定のリセット'),
                  content: const Text('プロンプト設定をデフォルト値に戻しますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () {
                        final settingsService = Provider.of<SettingsService>(
                            context,
                            listen: false);
                        settingsService.resetPromptsToDefaults();
                        _processingPromptController.text =
                            settingsService.promptSettings.processingPrompt;
                        _translationPromptController.text =
                            settingsService.promptSettings.translationPrompt;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('設定をデフォルト値に戻しました')),
                        );
                      },
                      child: const Text('リセット'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<SettingsService>(
        builder: (context, settingsService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 変数の説明
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('プロンプトで使用できる変数',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text(':text: - 処理または翻訳するテキスト'),
                        Text(':lang: - 翻訳先の言語（翻訳プロンプトのみ）'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // テキスト整形のプロンプト設定
                const Text('テキスト整形用プロンプト',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildJapaneseTextField(
                  controller: _processingPromptController,
                  maxLines: 6,
                  hintText: 'テキスト整形用のプロンプトを入力してください。',
                  isEdited: _isProcessingPromptEdited,
                  onResetPressed: () {
                    _processingPromptController.text =
                        PromptSettings.defaultProcessingPrompt;
                  },
                ),
                const SizedBox(height: 16),
                if (_isProcessingPromptEdited)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('テキスト整形プロンプトを保存'),
                    onPressed: () {
                      settingsService.updatePromptSettings(
                        processingPrompt: _processingPromptController.text,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('テキスト整形プロンプトを保存しました')),
                      );
                      setState(() {
                        _isProcessingPromptEdited = false;
                      });
                    },
                  ),
                const SizedBox(height: 32),

                // 翻訳用のプロンプト設定
                const Text('翻訳用プロンプト',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildJapaneseTextField(
                  controller: _translationPromptController,
                  maxLines: 6,
                  hintText: '翻訳用のプロンプトを入力してください。',
                  isEdited: _isTranslationPromptEdited,
                  onResetPressed: () {
                    _translationPromptController.text =
                        PromptSettings.defaultTranslationPrompt;
                  },
                ),
                const SizedBox(height: 16),
                if (_isTranslationPromptEdited)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('翻訳プロンプトを保存'),
                    onPressed: () {
                      settingsService.updatePromptSettings(
                        translationPrompt: _translationPromptController.text,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('翻訳プロンプトを保存しました')),
                      );
                      setState(() {
                        _isTranslationPromptEdited = false;
                      });
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
