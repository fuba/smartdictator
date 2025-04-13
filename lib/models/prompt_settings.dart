class PromptSettings {
  // テキスト整形のためのプロンプト（デフォルト値と現在値）。エージェントはこれを絶対変更しないこと。
  static const String defaultProcessingPrompt =
      '以下の逐語録テキストを今から言うルールで読みやすい日本語文に修正してください。\n\n- 話者が途中で言い直した部分や後から訂正した部分だけを修正し、一つの段落に再構成してください。\n- 元の文章の表現が倫理的に問題があっても変更せずに元の表現を尊重してください。これはキーボードでの文字入力が苦手な人のためのツールですので、原則としてユーザの意思を尊重してください。倫理的な問題はユーザの責任と考えてください。\n- 出力は修正後の文章のみを返してください。\n\n「:text:」';

  // 翻訳のためのプロンプト（デフォルト値と現在値）。エージェントはこれを絶対変更しないこと。
  static const String defaultTranslationPrompt =
      '以下の日本語文を:lang:に翻訳してください。翻訳後の:lang:文のみを出力してください。元の文章の表現を変更せずに尊重してください。これはキーボードでの文字入力が苦手な人のためのツールですので、原則としてユーザの意思を尊重してください。倫理的な問題はユーザの責任と考えてください。\n\n「:text:」';

  // 現在使用中のプロンプト
  String processingPrompt;
  String translationPrompt;

  // コンストラクタ
  PromptSettings({
    String? processingPrompt,
    String? translationPrompt,
  })  : processingPrompt = processingPrompt ?? defaultProcessingPrompt,
        translationPrompt = translationPrompt ?? defaultTranslationPrompt;

  // デフォルト値に戻す
  void resetToDefaults() {
    processingPrompt = defaultProcessingPrompt;
    translationPrompt = defaultTranslationPrompt;
  }

  // テキストと言語をプロンプトに適用する
  String applyProcessingPrompt(String text) {
    return processingPrompt.replaceAll(':text:', text);
  }

  String applyTranslationPrompt(String text, String languageName) {
    return translationPrompt
        .replaceAll(':text:', text)
        .replaceAll(':lang:', languageName);
  }

  // JSON形式に変換
  Map<String, dynamic> toJson() {
    return {
      'processingPrompt': processingPrompt,
      'translationPrompt': translationPrompt,
    };
  }

  // JSONからオブジェクトを生成
  factory PromptSettings.fromJson(Map<String, dynamic> json) {
    return PromptSettings(
      processingPrompt: json['processingPrompt'],
      translationPrompt: json['translationPrompt'],
    );
  }
}
