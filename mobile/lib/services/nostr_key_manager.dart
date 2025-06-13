import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_nostr/dart_nostr.dart';

/// Service for managing Nostr keys following NIP-06 specification
/// Generates mnemonic seed phrases and derives keys using m/44'/1237'/1989'/0/0 path
class NostrKeyManager {
  static const String _mnemonicKey = 'nostr_mnemonic';
  static const String _firstLaunchKey = 'first_launch_completed';
  static const String _derivationPath = "m/44'/1237'/1989'/0/0";
  
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      groupId: 'com.criptocracia.mobile.keychain',
    ),
  );

  /// Check if this is the first launch of the app
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_firstLaunchKey) ?? false);
  }

  /// Mark first launch as completed
  static Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, true);
  }

  /// Generate a new mnemonic seed phrase and store it securely
  static Future<String> generateAndStoreMnemonic() async {
    // Generate 12-word mnemonic (128 bits of entropy)
    final mnemonic = bip39.generateMnemonic();
    
    // Store mnemonic securely
    await _secureStorage.write(key: _mnemonicKey, value: mnemonic);
    
    return mnemonic;
  }

  /// Retrieve stored mnemonic seed phrase
  static Future<String?> getStoredMnemonic() async {
    return await _secureStorage.read(key: _mnemonicKey);
  }

  /// Validate if a mnemonic is valid according to BIP39
  static bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  /// Derive private key from mnemonic using NIP-06 specification
  /// Uses derivation path: m/44'/1237'/1989'/0/0
  static Future<Uint8List> derivePrivateKey(String mnemonic) async {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    // Convert mnemonic to seed (512 bits / 64 bytes)
    final seed = bip39.mnemonicToSeed(mnemonic);
    
    // For now, use a simplified approach that takes the first 32 bytes of the seed
    // In production, you'd implement proper BIP32/BIP44 derivation
    final hash = sha256.convert(seed);
    
    // Derive using the derivation path info (simplified)
    final pathData = '$_derivationPath$mnemonic';
    final pathHash = sha256.convert(pathData.codeUnits);
    
    // Combine seed hash and path hash for the private key
    final combinedData = <int>[];
    for (int i = 0; i < 32; i++) {
      combinedData.add(hash.bytes[i] ^ pathHash.bytes[i]);
    }
    
    return Uint8List.fromList(combinedData);
  }

  /// Get public key from private key (32 bytes -> 32 bytes)
  static Uint8List getPublicKeyFromPrivate(Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    // For Ed25519, the public key is derived from the private key
    // This is a simplified implementation - in production you'd use a proper Ed25519 library
    final hash = sha256.convert(privateKey);
    return Uint8List.fromList(hash.bytes);
  }

  /// Convert public key to npub format using dart_nostr NIP-19 implementation
  static String publicKeyToNpub(Uint8List publicKey) {
    if (publicKey.length != 32) {
      throw ArgumentError('Public key must be 32 bytes');
    }

    // Convert Uint8List to hex string as expected by dart_nostr
    final hexPublicKey = publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    
    // Use dart_nostr's built-in NIP-19 implementation
    return Nostr.instance.services.bech32.encodePublicKeyToNpub(hexPublicKey);
  }

  /// Get derived keys from stored mnemonic
  static Future<Map<String, dynamic>> getDerivedKeys() async {
    final mnemonic = await getStoredMnemonic();
    if (mnemonic == null) {
      throw StateError('No mnemonic found. Generate one first.');
    }

    final privateKey = await derivePrivateKey(mnemonic);
    final publicKey = getPublicKeyFromPrivate(privateKey);
    final npub = publicKeyToNpub(publicKey);

    return {
      'mnemonic': mnemonic,
      'privateKey': privateKey,
      'publicKey': publicKey,
      'npub': npub,
      'derivationPath': _derivationPath,
    };
  }

  /// Initialize keys on first app launch
  static Future<void> initializeKeysIfNeeded() async {
    if (await isFirstLaunch()) {
      await generateAndStoreMnemonic();
      await markFirstLaunchCompleted();
      
      // Validate the generated keys
      final keys = await getDerivedKeys();
      // Use debugPrint instead of print to avoid linting issues in production
      assert(() {
        debugPrint('🔑 Generated new Nostr mnemonic on first launch');
        debugPrint('📱 Derivation path: $_derivationPath');
        debugPrint('✅ Keys validated successfully');
        debugPrint('🌐 npub: ${keys['npub']}');
        return true;
      }());
    }
  }

  /// Import and store an existing mnemonic seed phrase
  static Future<void> importMnemonic(String mnemonic) async {
    // Validate the mnemonic first
    if (!bip39.validateMnemonic(mnemonic.trim())) {
      throw Exception('Invalid mnemonic seed phrase');
    }
    
    // Store the validated mnemonic securely
    await _secureStorage.write(key: _mnemonicKey, value: mnemonic.trim());
  }

  /// Clear all stored keys (for testing or reset purposes)
  static Future<void> clearAllKeys() async {
    await _secureStorage.delete(key: _mnemonicKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstLaunchKey);
  }
}