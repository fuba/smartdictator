import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextDisplay extends StatelessWidget {
  final String text;
  final bool isEmpty;
  final String emptyText;
  final bool isProcessing;

  const TextDisplay({
    super.key,
    required this.text,
    required this.isEmpty,
    required this.emptyText,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEmpty ? Colors.grey.withOpacity(0.3) : Theme.of(context).primaryColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isProcessing)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          const SizedBox(height: 8),
          isEmpty
              ? Text(
                  emptyText,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    if (!isEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('テキストをクリップボードにコピーしました'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        tooltip: 'コピー',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}