import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/recognition_service.dart';
import 'services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 順序が重要: SettingsServiceを先に作成
        ChangeNotifierProvider(create: (_) => SettingsService()),
        // RecognitionServiceはSettingsServiceに依存
        ChangeNotifierProxyProvider<SettingsService, RecognitionService>(
          create: (context) => RecognitionService(
              Provider.of<SettingsService>(context, listen: false)),
          update: (context, settingsService, previousRecognitionService) =>
              previousRecognitionService ?? RecognitionService(settingsService),
        ),
      ],
      child: MaterialApp(
        title: 'Smart Dictator',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        darkTheme: ThemeData.dark().copyWith(
          primaryColor: Colors.blueAccent,
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            secondary: Colors.lightBlueAccent,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
