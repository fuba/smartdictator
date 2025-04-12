import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/recognition_service.dart';

class RecordButton extends StatelessWidget {
  const RecordButton({super.key});

  @override
  Widget build(BuildContext context) {
    final recognitionService = Provider.of<RecognitionService>(context);
    final isListening = recognitionService.isListening;
    final isProcessing = recognitionService.isProcessing;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: (_) {
              if (!isListening && !isProcessing && recognitionService.isInitialized) {
                recognitionService.startListening();
              }
            },
            onTapUp: (_) {
              if (isListening) {
                recognitionService.stopListening();
              }
            },
            onTapCancel: () {
              if (isListening) {
                recognitionService.stopListening();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isListening ? 100 : 80,
              height: isListening ? 100 : 80,
              decoration: BoxDecoration(
                color: isListening ? Colors.redAccent : Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: isListening ? 50 : 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isListening ? '録音中... タップを離すと終了' : '押して話す',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isListening ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (!recognitionService.isInitialized)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                '音声認識を初期化中...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}