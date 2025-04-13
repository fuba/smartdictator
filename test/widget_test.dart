import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartdictator/screens/home_screen.dart';
import 'package:smartdictator/services/recognition_service.dart';

void main() {
  testWidgets('HomeScreen has necessary UI elements', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MockRecognitionService(),
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Verify that the app contains the main UI elements
    expect(find.text('Smart Dictator'), findsOneWidget);
    expect(find.text('押して話す'), findsOneWidget);
    expect(find.text('音声認識結果:'), findsOneWidget);
    expect(find.text('修正後テキスト:'), findsOneWidget);
    expect(find.text('英訳結果:'), findsOneWidget);
    expect(find.text('英訳'), findsOneWidget);
    
    // Verify the record button
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });
}

class MockRecognitionService extends ChangeNotifier implements RecognitionService {
  @override
  bool get isInitialized => true;

  @override
  bool get isListening => false;

  @override
  bool get isProcessing => false;

  @override
  bool get ollamaAvailable => true;

  @override
  String get processedText => '';

  @override
  String get recognizedText => '';

  @override
  String get translatedText => '';

  @override
  Future<void> processText() async {}

  @override
  void reset() {}

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> translateText() async {}
}