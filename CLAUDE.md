# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands
- `flutter run -d macos` - Run the app on macOS
- `flutter test` - Run all tests
- `flutter test test/widget_test.dart` - Run a specific test
- `flutter analyze` - Run the Dart analyzer
- `flutter pub get` - Get dependencies

## Dependencies
- Use `speech_to_text` package for speech recognition
- Use Ollama with Gemma 3 (4B) for text processing
- Use standard HTTP package for API communication

## Code Style Guidelines
- **Imports**: Use relative imports for project files, package imports for external dependencies
- **Formatting**: Follow Dart conventions with 2-space indentation
- **Types**: Use strong typing and null safety features
- **Naming**: camelCase for variables/methods, PascalCase for classes
- **Architecture**: Follow a modular approach with separation between UI, speech recognition, and LLM services
- **Error Handling**: Use try-catch blocks with specific error messages and graceful UI feedback
- **Comments**: Document complex logic and public APIs with meaningful comments