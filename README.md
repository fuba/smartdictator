# Smart Dictator

音声認識とテキスト処理のためのクロスプラットフォームアプリケーション

## 概要

Smart Dictatorは、音声をテキストに変換し（音声認識）、その出力を自然な日本語に整形して、必要に応じて複数の言語に翻訳するFlutterアプリケーションです。
Ollamaを使用する場合、すべての処理はローカル環境で行われ、オフラインでの使用が可能です。

## 機能

- 日本語音声のリアルタイム認識
- 言い直しや冗長表現の除去（LLMによる自動整形）
- 日本語テキストの多言語翻訳（英語、フランス語、スペイン語、ドイツ語、イタリア語、中国語、韓国語）
- テキスト読み上げ機能
- 編集可能なテキスト領域
- シンプルで使いやすいインターフェース
- 複数のLLMプロバイダーをサポート：
  - Ollama（デフォルト、オフライン動作）
  - OpenAI API（オンライン動作）

## 対応プラットフォーム

- macOS 10.14以降
- iOS 11.0以降
- Android 6.0以降

## 前提条件

- Ollamaを使用する場合：
  - [Ollama](https://ollama.com/)がインストールされていること
  - 任意のLLMモデル（デフォルトはGemma 3 4B）がOllamaでインストールされていること
- OpenAI APIを使用する場合：
  - 有効なOpenAI APIキー
- デバイスのマイク使用権限
- インターネット接続（OpenAI使用時またはモデルダウンロード時）

## セットアップ

1. リポジトリをクローン
   ```
   git clone https://github.com/your-username/smartdictator.git
   cd smartdictator
   ```

2. 依存関係をインストール
   ```
   flutter pub get
   ```

3. アプリを実行
   ```
   flutter run -d macos  # macOS向け
   flutter run -d ios    # iOS向け
   flutter run -d android  # Android向け
   ```

### Ollamaを使用する場合（デフォルト）

4. Ollamaをインストール（まだの場合）
   ```
   brew install ollama  # macOS
   ```
   
   他のプラットフォームについては[Ollamaの公式サイト](https://ollama.com/)を参照

5. 使用したいLLMモデルをダウンロード（例：Gemma 3 4B）
   ```
   ollama pull gemma3:4b
   ```

6. Ollamaサーバーを起動
   ```
   ollama serve
   ```

### OpenAI APIを使用する場合

4. アプリの設定画面でOpenAI APIの設定を行う
   - エンドポイント（デフォルト: https://api.openai.com/v1）
   - モデル名（デフォルト: gpt-4o-mini）
   - APIキー

## 使用方法

1. アプリを起動
2. 「押して話す」ボタンを長押しして日本語で話す
3. ボタンを離すと音声認識結果が表示され、自動的にテキスト整形が行われる
4. 翻訳言語を選択し、「翻訳」ボタンをクリックして翻訳
5. 各テキスト領域の右側にあるボタンで：
   - テキストを読み上げる
   - テキストを編集する
   - 処理/翻訳をやり直す
   - テキストをクリップボードにコピーする

## 設定

設定画面では以下のカスタマイズが可能です：
- LLMプロバイダー（OllamaまたはOpenAI）
- エンドポイントとモデル設定
- テキスト処理と翻訳のためのカスタムプロンプト

## ライセンス

[MIT License](LICENSE)