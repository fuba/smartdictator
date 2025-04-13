import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/recognition_service.dart';

// StatefulWidgetに変更
class RecordButton extends StatefulWidget {
  const RecordButton({super.key});

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  // ボタンが押されているかの状態を追加
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Provider.ofをbuildメソッド内で使用
    final recognitionService = Provider.of<RecognitionService>(context);
    final isListening = recognitionService.isListening;
    final isProcessing = recognitionService.isProcessing;
    final isInitialized = recognitionService.isInitialized; // isInitializedも取得
    final remainingSeconds = recognitionService.remainingSeconds; // 残り時間を取得

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: (_) {
              if (!isListening && !isProcessing && isInitialized) {
                // 押された状態をtrueに
                setState(() {
                  _isPressed = true;
                });
                // 録音開始
                recognitionService.startListening();
              }
            },
            onTapUp: (_) {
              // 押された状態をfalseに
              setState(() {
                _isPressed = false;
              });
              if (isListening) {
                // 離されたら録音停止と処理開始
                recognitionService.stopListening();
              }
            },
            onTapCancel: () {
              // 押された状態をfalseに
              setState(() {
                _isPressed = false;
              });
              if (isListening) {
                // キャンセル時も録音停止
                recognitionService.stopListening();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                // _isPressed状態に応じて色を変更
                color: _isPressed
                    ? Colors.lightBlueAccent // 押されている時の色
                    : isListening
                        ? Colors.redAccent
                        : isProcessing
                            ? Colors.orange
                            : !isInitialized
                                ? Colors.grey
                                : Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isProcessing)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  Icon(
                    // _isPressed状態もアイコン表示に反映させる（任意）
                    (isListening || _isPressed)
                        ? Icons.mic
                        : isProcessing
                            ? Icons.hourglass_top
                            : Icons.mic_none,
                    color: Colors.white,
                    size: 40,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isListening
                ? '録音中... あと${remainingSeconds}秒 (指を離すと終了)' // 残り時間表示を追加
                : isProcessing
                    ? '処理中...'
                    : !isInitialized // isInitializedを使用
                        ? '初期化中/権限を確認'
                        : '押しながら話す',
            style: TextStyle(
              fontSize: 16,
              fontWeight: (isListening || isProcessing)
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isProcessing
                  ? Colors.orange
                  : (isListening ? Colors.red : Colors.black),
            ),
          ),
          // isInitializedを使用
          if (!isInitialized)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                children: [
                  const Text(
                    '音声認識の初期化が必要です',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // 再初期化を試みる
                      await recognitionService.reinitializeSpeech();

                      // isInitializedを再評価
                      if (!recognitionService.isInitialized && mounted) {
                        // mountedチェックを追加
                        // ignore: use_build_context_synchronously
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('音声認識の初期化が必要です'),
                            content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('音声認識を使用するには、以下の手順で権限を許可してください：'),
                                SizedBox(height: 16),
                                Text('1. システム設定 > プライバシーとセキュリティ > マイク を開く'),
                                Text('2. 「smartdictator」アプリを許可する'),
                                SizedBox(height: 8),
                                Text('3. システム設定 > プライバシーとセキュリティ > 音声認識 を開く'),
                                Text('4. 「smartdictator」アプリを許可する'),
                                SizedBox(height: 16),
                                Text('※ アプリが表示されない場合は、一度アプリを閉じて再起動してください。'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: const Text('マイク権限を確認/リクエスト'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
