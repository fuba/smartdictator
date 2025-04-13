import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/recognition_service.dart';
import '../models/prompt_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _processingPromptController;
  late TextEditingController _translationPromptController;
  
  // LLM設定用のコントローラー
  late TextEditingController _ollamaEndpointController;
  late TextEditingController _ollamaModelController;
  late TextEditingController _openaiEndpointController;
  late TextEditingController _openaiModelController;
  late TextEditingController _openaiApiKeyController;
  
  bool _isProcessingPromptEdited = false;
  bool _isTranslationPromptEdited = false;
  bool _isLlmSettingsEdited = false;
  
  // OpenAI接続テスト結果
  String? _openaiTestResult;
  bool _isTestingOpenai = false;

  // 日本語入力用の現在の値を保持する変数
  String? _processingPromptCurrent;
  String? _translationPromptCurrent;

  @override
  void initState() {
    super.initState();
    
    // タブコントローラーの初期化
    _tabController = TabController(length: 2, vsync: this);
    
    // プロンプト設定のコントローラー初期化
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final promptSettings = settingsService.promptSettings;
    _processingPromptController =
        TextEditingController(text: promptSettings.processingPrompt);
    _translationPromptController =
        TextEditingController(text: promptSettings.translationPrompt);

    _processingPromptCurrent = promptSettings.processingPrompt;
    _translationPromptCurrent = promptSettings.translationPrompt;

    _processingPromptController.addListener(_onProcessingPromptChanged);
    _translationPromptController.addListener(_onTranslationPromptChanged);
    
    // LLM設定のコントローラー初期化
    final llmSettings = settingsService.llmSettings;
    _ollamaEndpointController = TextEditingController(text: llmSettings.ollamaEndpoint);
    _ollamaModelController = TextEditingController(text: llmSettings.ollamaModel);
    _openaiEndpointController = TextEditingController(text: llmSettings.openaiEndpoint);
    _openaiModelController = TextEditingController(text: llmSettings.openaiModel);
    _openaiApiKeyController = TextEditingController(text: llmSettings.openaiApiKey);
  }

  @override
  void dispose() {
    _processingPromptController.removeListener(_onProcessingPromptChanged);
    _translationPromptController.removeListener(_onTranslationPromptChanged);
    _processingPromptController.dispose();
    _translationPromptController.dispose();
    
    // LLM設定コントローラーの解放
    _ollamaEndpointController.dispose();
    _ollamaModelController.dispose();
    _openaiEndpointController.dispose();
    _openaiModelController.dispose();
    _openaiApiKeyController.dispose();
    
    // タブコントローラーの解放
    _tabController.dispose();
    
    super.dispose();
  }
  
  // LLM設定が編集されたかチェックするメソッド
  void _checkLlmSettingsEdited() {
    final llmSettings = Provider.of<SettingsService>(context, listen: false).llmSettings;
    
    setState(() {
      _isLlmSettingsEdited = 
          _ollamaEndpointController.text != llmSettings.ollamaEndpoint ||
          _ollamaModelController.text != llmSettings.ollamaModel ||
          _openaiEndpointController.text != llmSettings.openaiEndpoint ||
          _openaiModelController.text != llmSettings.openaiModel ||
          _openaiApiKeyController.text != llmSettings.openaiApiKey;
      
      // 設定が変更された場合はテスト結果をリセット
      if (_isLlmSettingsEdited) {
        _openaiTestResult = null;
      }
    });
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
        if (currentValue != null && currentValue.length < value.length) {
          final suffix = value.substring(currentValue.length);
          if (suffix.length > 1 && value == "$currentValue$suffix") {
            // 重複を検出したら前回の値に戻す
            controller.text = currentValue;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: currentValue.length),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'プロンプト設定'),
            Tab(text: 'LLM設定'),
          ],
        ),
        actions: [
          // 変更をリセットするボタン
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('設定のリセット'),
                  content: const Text('すべての設定をデフォルト値に戻しますか？'),
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
                        final recognitionService = Provider.of<RecognitionService>(
                            context, 
                            listen: false);
                        
                        // 設定をリセット
                        settingsService.resetAllToDefaults();
                        
                        // コントローラーの内容を更新
                        _updateAllControllers(settingsService);
                        
                        // LLMを再初期化
                        recognitionService.reinitializeLlm();
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('すべての設定をデフォルト値に戻しました')),
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
          return TabBarView(
            controller: _tabController,
            children: [
              // プロンプト設定タブ
              _buildPromptSettingsTab(settingsService),
              
              // LLM設定タブ
              _buildLlmSettingsTab(settingsService),
            ],
          );
        },
      ),
    );
  }
  
  // コントローラーの内容を設定に合わせて更新するヘルパーメソッド
  void _updateAllControllers(SettingsService settingsService) {
    // プロンプト設定のコントローラーを更新
    _processingPromptController.text = settingsService.promptSettings.processingPrompt;
    _translationPromptController.text = settingsService.promptSettings.translationPrompt;
    
    // LLM設定のコントローラーを更新
    _ollamaEndpointController.text = settingsService.llmSettings.ollamaEndpoint;
    _ollamaModelController.text = settingsService.llmSettings.ollamaModel;
    _openaiEndpointController.text = settingsService.llmSettings.openaiEndpoint;
    _openaiModelController.text = settingsService.llmSettings.openaiModel;
    _openaiApiKeyController.text = settingsService.llmSettings.openaiApiKey;
    
    // 編集フラグとテスト結果をリセット
    setState(() {
      _isProcessingPromptEdited = false;
      _isTranslationPromptEdited = false;
      _isLlmSettingsEdited = false;
      _openaiTestResult = null;
    });
  }
  
  // プロンプト設定タブの内容
  Widget _buildPromptSettingsTab(SettingsService settingsService) {
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
  }
  
  // LLM設定タブの内容
  Widget _buildLlmSettingsTab(SettingsService settingsService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // プロバイダー選択
          const Text('LLMプロバイダー',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<LlmProvider>(
            segments: const [
              ButtonSegment<LlmProvider>(
                value: LlmProvider.ollama,
                label: Text('Ollama'),
                icon: Icon(Icons.computer),
              ),
              ButtonSegment<LlmProvider>(
                value: LlmProvider.openai,
                label: Text('OpenAI'),
                icon: Icon(Icons.cloud),
              ),
            ],
            selected: {settingsService.llmSettings.provider},
            onSelectionChanged: (newSelection) {
              setState(() {
                _isLlmSettingsEdited = true;
              });
              settingsService.updateLlmSettings(
                provider: newSelection.first,
              );
            },
          ),
          const SizedBox(height: 24),
          
          // 選択されたプロバイダーに応じた設定UI
          if (settingsService.llmSettings.provider == LlmProvider.ollama)
            _buildOllamaSettings(settingsService)
          else
            _buildOpenAISettings(settingsService),
          
          const SizedBox(height: 24),
          
          // LLM設定を保存するボタン
          if (_isLlmSettingsEdited)
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('LLM設定を保存'),
              onPressed: () {
                final recognitionService = Provider.of<RecognitionService>(
                  context, 
                  listen: false
                );
                
                // LLM設定を更新
                settingsService.updateLlmSettings(
                  ollamaEndpoint: _ollamaEndpointController.text,
                  ollamaModel: _ollamaModelController.text,
                  openaiEndpoint: _openaiEndpointController.text,
                  openaiModel: _openaiModelController.text,
                  openaiApiKey: _openaiApiKeyController.text,
                );
                
                // LLMを再初期化
                recognitionService.reinitializeLlm();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('LLM設定を保存しました')),
                );
                
                setState(() {
                  _isLlmSettingsEdited = false;
                });
              },
            ),
          
          // 現在のLLM状態を表示
          const SizedBox(height: 32),
          Consumer<RecognitionService>(
            builder: (context, recognitionService, child) {
              return Card(
                color: recognitionService.llmAvailable
                    ? Colors.green.withAlpha(50)
                    : Colors.red.withAlpha(50),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '現在のLLM接続状態',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: recognitionService.llmAvailable
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('プロバイダー: ${recognitionService.currentLlmProvider}'),
                      Text('モデル: ${recognitionService.currentLlmModel}'),
                      Text(
                        '状態: ${recognitionService.llmAvailable ? "利用可能" : "利用不可"}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: recognitionService.llmAvailable
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!recognitionService.llmAvailable)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('接続を再試行'),
                          onPressed: () => recognitionService.reinitializeLlm(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Ollama設定UI
  Widget _buildOllamaSettings(SettingsService settingsService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ollama設定',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        // Ollamaエンドポイント
        TextField(
          controller: _ollamaEndpointController,
          decoration: const InputDecoration(
            labelText: 'Ollamaエンドポイント',
            hintText: 'http://localhost:11434',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _checkLlmSettingsEdited(),
        ),
        const SizedBox(height: 16),
        
        // Ollamaモデル
        TextField(
          controller: _ollamaModelController,
          decoration: const InputDecoration(
            labelText: 'Ollamaモデル',
            hintText: 'gemma3:4b',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _checkLlmSettingsEdited(),
        ),
      ],
    );
  }
  
  // OpenAI設定UI
  Widget _buildOpenAISettings(SettingsService settingsService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('OpenAI設定',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        // OpenAIエンドポイント
        TextField(
          controller: _openaiEndpointController,
          decoration: const InputDecoration(
            labelText: 'OpenAIエンドポイント',
            hintText: 'https://api.openai.com/v1',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _checkLlmSettingsEdited(),
        ),
        const SizedBox(height: 16),
        
        // OpenAIモデル
        TextField(
          controller: _openaiModelController,
          decoration: const InputDecoration(
            labelText: 'OpenAIモデル',
            hintText: 'gpt-3.5-turbo',
            helperText: 'gpt-3.5-turbo, gpt-4、または互換モデル',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _checkLlmSettingsEdited(),
        ),
        const SizedBox(height: 16),
        
        // OpenAI APIキー
        TextField(
          controller: _openaiApiKeyController,
          decoration: const InputDecoration(
            labelText: 'OpenAI APIキー',
            hintText: 'sk-...',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          onChanged: (_) => _checkLlmSettingsEdited(),
        ),
        
        const SizedBox(height: 24),
        
        // APIテストボタンとテスト結果
        ElevatedButton.icon(
          icon: _isTestingOpenai 
            ? const SizedBox(
                width: 16, 
                height: 16, 
                child: CircularProgressIndicator(strokeWidth: 2)
              )
            : const Icon(Icons.bug_report),
          label: const Text('OpenAI API接続テスト'),
          onPressed: _isTestingOpenai 
            ? null 
            : () async {
                final recognitionService = Provider.of<RecognitionService>(
                  context, 
                  listen: false
                );
                
                // 一時的に設定を適用
                if (_isLlmSettingsEdited) {
                  final settingsService = Provider.of<SettingsService>(
                    context, 
                    listen: false
                  );
                  
                  settingsService.updateLlmSettings(
                    provider: LlmProvider.openai,
                    openaiEndpoint: _openaiEndpointController.text,
                    openaiModel: _openaiModelController.text,
                    openaiApiKey: _openaiApiKeyController.text,
                  );
                }
                
                setState(() {
                  _isTestingOpenai = true;
                  _openaiTestResult = null;
                });
                
                // テスト実行
                String result = await recognitionService.testOpenAI();
                
                setState(() {
                  _openaiTestResult = result;
                  _isTestingOpenai = false;
                });
              },
        ),
        
        if (_openaiTestResult != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _openaiTestResult!.contains('成功') 
                ? const Color.fromRGBO(0, 160, 0, 0.12)
                : const Color.fromRGBO(160, 0, 0, 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _openaiTestResult!,
              style: TextStyle(
                color: _openaiTestResult!.contains('成功')
                  ? Colors.green.shade900
                  : Colors.red.shade900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
