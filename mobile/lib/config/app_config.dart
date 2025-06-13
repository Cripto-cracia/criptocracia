import 'package:flutter/foundation.dart';

class AppConfig {
  // Hardcoded configuration for mobile app
  static String relayUrl = 'wss://relay.mostro.network';
  static String ecPublicKey = '0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c';
  static bool debugMode = false;
  
  static void parseArguments(List<String> args) {
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--debug':
        case '-d':
          debugMode = true;
          break;
        case '--help':
        case '-h':
          printHelp();
          break;
      }
    }
  }
  
  static void printHelp() {
    debugPrint('''
Criptocracia Voter App

A mobile voting application using the Nostr protocol.

Configuration:
  Relay URL: $relayUrl
  EC Public Key: $ecPublicKey

Usage: flutter run -- [OPTIONS]

Options:
  -d, --debug               Enable debug mode
  -h, --help                Show this help message

Examples:
  flutter run
  flutter run -- --debug
''');
  }
  
  static bool get isConfigured {
    return relayUrl.isNotEmpty && ecPublicKey.isNotEmpty;
  }
}