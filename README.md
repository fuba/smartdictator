# Smart Dictator

macOS用の日本語音声認識・テキスト処理アプリケーション

## 概要

Smart Dictatorは、音声をテキストに変換し（音声認識）、その出力を自然な日本語に整形して、必要に応じて英語に翻訳するFlutterアプリケーションです。
すべての処理はローカル環境で行われ、オフラインでの使用が可能です。

## 機能

- 日本語音声のリアルタイム認識
- 言い直しや冗長表現の除去（LLMによる自動整形）
- 日本語テキストの多言語翻訳
- シンプルで使いやすいインターフェース
- 複数のLLMプロバイダーをサポート：
  - Ollama（デフォルト）
  - OpenAI API

## 前提条件

- macOS 10.14以降
- Ollamaを使用する場合：
  - [Ollama](https://ollama.com/)がインストールされていること
  - 任意のLLMモデル（デフォルトはGemma 3 4B）がOllamaでインストールされていること
- OpenAI APIを使用する場合：
  - 有効なOpenAI APIキー

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
   flutter run -d macos
   ```

### Ollamaを使用する場合（デフォルト）

4. Ollamaをインストール（まだの場合）
   ```
   brew install ollama
   ```

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
   - モデル名（例: gpt-3.5-turbo）
   - APIキー

## 使用方法

1. アプリを起動
2. 「押して話す」ボタンを長押しして日本語で話す
3. ボタンを離すと音声認識結果が表示され、自動的にテキスト整形が行われる
4. 必要に応じて「英訳」ボタンをクリックして英語に翻訳
5. 各テキスト領域の右側にあるコピーボタンでテキストをクリップボードにコピー可能

## ライセンス

[MIT License](LICENSE)