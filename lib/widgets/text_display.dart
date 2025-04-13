import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextDisplay extends StatefulWidget {
  final String text;
  final bool isEmpty;
  final String emptyText;
  final bool isProcessing;
  final Function(String)? onTextChanged;
  final VoidCallback? onRegeneratePressed;
  final VoidCallback? onSpeakPressed;
  final bool isSpeaking;

  const TextDisplay({
    super.key,
    required this.text,
    required this.isEmpty,
    required this.emptyText,
    this.isProcessing = false,
    this.onTextChanged,
    this.onRegeneratePressed,
    this.onSpeakPressed,
    this.isSpeaking = false,
  });

  @override
  State<TextDisplay> createState() => _TextDisplayState();
}

class _TextDisplayState extends State<TextDisplay> {
  bool _isEditing = false;
  late final TextEditingController _controller;
  String? _current;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _current = widget.text;
  }

  @override
  void didUpdateWidget(TextDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && !_isEditing) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildJapaneseTextField() {
    return TextField(
      controller: _controller,
      maxLines: null,
      autofocus: true,
      onChanged: (value) {
        // 日本語入力時の重複を検出して修正
        if (_current != null && _current!.length < value.length) {
          final suffix = value.substring(_current!.length);
          if (suffix.length > 1 && value == "$_current$suffix") {
            // 重複を検出したら前回の値に戻す
            _controller.text = _current!;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _current!.length),
            );
            return;
          }
        }
        _current = value;
      },
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: _saveChanges,
              tooltip: '保存',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _controller.text = widget.text; // 元の値に戻す
                  _current = _controller.text;
                  _isEditing = false;
                });
              },
              tooltip: 'キャンセル',
            ),
          ],
        ),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  void _saveChanges() {
    if (widget.onTextChanged != null && _controller.text != widget.text) {
      widget.onTextChanged!(_controller.text);
    }
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isEditing
            ? const Color.fromRGBO(33, 150, 243, 0.05)
            : widget.isProcessing
                ? const Color.fromRGBO(255, 193, 7, 0.1)
                : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isEditing
              ? Colors.blue
              : widget.isProcessing
                  ? Colors.orange
                  : widget.isEmpty
                      ? const Color.fromRGBO(158, 158, 158, 0.3)
                      : Theme.of(context).primaryColor.withAlpha(127),
          width: _isEditing || widget.isProcessing ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isProcessing)
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.amber,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            )
          else
            const SizedBox(height: 3),
          const SizedBox(height: 8),
          if (widget.isEmpty)
            Text(
              widget.emptyText,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: widget.isProcessing
                    ? Colors.orange.shade700
                    : Colors.grey.shade600,
                fontSize: 14,
                fontWeight:
                    widget.isProcessing ? FontWeight.w500 : FontWeight.normal,
              ),
            )
          else if (_isEditing)
            _buildJapaneseTextField()
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.text,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (widget.onSpeakPressed != null)
                        IconButton(
                          icon: Icon(
                            widget.isSpeaking ? Icons.stop : Icons.volume_up,
                            size: 20,
                            color: widget.isSpeaking ? Colors.red : null,
                          ),
                          onPressed: widget.onSpeakPressed,
                          tooltip: widget.isSpeaking ? '停止' : '読み上げ',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (widget.onRegeneratePressed != null)
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: widget.onRegeneratePressed,
                          tooltip: '再生成',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          setState(() {
                            _controller.text = widget.text;
                            _current = widget.text;
                            _isEditing = true;
                          });
                        },
                        tooltip: '編集',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.text));
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
                ),
              ],
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
