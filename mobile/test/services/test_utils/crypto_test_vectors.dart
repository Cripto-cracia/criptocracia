import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:criptocracia/services/blind_signature_service.dart';

/// Cryptographic test vectors and utilities for testing
class CryptoTestVectors {
  // Test RSA key pair components (for deterministic testing)
  static final BigInt testModulus = BigInt.parse(
    '24916870851346305622170854063508168162068848979823598553502963973796632773869'
    '24701509654925087949932436996752470616983462568308951946095598871717376336473'
    '57841055962949953522095061915134701485506569976733906031138577775862394846119'
    '72345893050901062081456139174124073092949577072568965806966642467654213096031'
    '93',
  );
  
  static final BigInt testExponent = BigInt.from(65537);
  
  static final BigInt testPrivateExponent = BigInt.parse(
    '19143453748671631766456524950090830651369915015938066845830847063536073746497'
    '72453996639734503203831866717843851451659584978139772598533013467071816159633'
    '64783165901734537993635647774966985503838503528329851993928983845072273468061'
    '85201851506325094179693951536142655488881516891451063628745701043074273193489',
  );

  /// Generate a deterministic test key pair for consistent testing
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> getTestKeyPair() {
    final publicKey = RSAPublicKey(testModulus, testExponent);
    final privateKey = RSAPrivateKey(testModulus, testPrivateExponent, null, null);
    
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(publicKey, privateKey);
  }

  /// Standard test messages for blind signature testing
  static const List<String> testMessages = [
    'Hello, World!',
    'This is a test message for blind signature verification.',
    'Vote for candidate 123 in election ABC',
    'Short msg',
    'A very long message that exceeds typical lengths to test how the blind signature service handles larger inputs and ensures proper cryptographic operations across various message sizes and content types.',
    '', // Empty message edge case
    '🗳️ Unicode vote message with emojis 🔐',
    'Special chars: !@#\$%^&*()[]{}|\\:";\'<>?,./`~',
  ];

  /// Test election and candidate data
  static const String testElectionId = 'test-election-12345';
  static const int testCandidateId = 42;
  static const String testVoterId = 'npub1234567890abcdef';

  /// Get test message as Uint8List
  static Uint8List getTestMessage([int index = 0]) {
    final message = testMessages[index % testMessages.length];
    return Uint8List.fromList(message.codeUnits);
  }

  /// Generate multiple test messages for batch testing
  static List<Uint8List> getTestMessages() {
    return testMessages.map((msg) => Uint8List.fromList(msg.codeUnits)).toList();
  }

  /// Test known good blind signature workflow
  static BlindSignatureTestVector createTestVector() {
    final keyPair = getTestKeyPair();
    final message = getTestMessage(1); // Use second test message
    
    final blindingResult = BlindSignatureService.blindMessage(message, keyPair.publicKey);
    final blindedSignature = BlindSignatureService.signBlindedMessage(
      blindingResult.blindedMessage,
      keyPair.privateKey,
    );
    final unblindedSignature = BlindSignatureService.unblindSignature(
      blindedSignature,
      blindingResult.blindingFactor,
      keyPair.publicKey,
    );
    
    return BlindSignatureTestVector(
      keyPair: keyPair,
      originalMessage: message,
      blindingResult: blindingResult,
      blindedSignature: blindedSignature,
      unblindedSignature: unblindedSignature,
    );
  }

  /// Test edge cases and boundary conditions
  static Map<String, dynamic> getEdgeCases() {
    return {
      'emptyMessage': Uint8List(0),
      'singleByte': Uint8List.fromList([42]),
      'maxSingleByteValue': Uint8List.fromList([255]),
      'allZeros': Uint8List.fromList(List.filled(32, 0)),
      'allOnes': Uint8List.fromList(List.filled(32, 255)),
      'randomPattern': Uint8List.fromList([
        0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
        0xFE, 0xED, 0xFA, 0xCE, 0xB0, 0x0B, 0x1E, 0x55,
      ]),
    };
  }

  /// Performance test data with various sizes
  static Map<String, Uint8List> getPerformanceTestData() {
    return {
      'small_16B': Uint8List.fromList(List.generate(16, (i) => i % 256)),
      'medium_1KB': Uint8List.fromList(List.generate(1024, (i) => i % 256)),
      'large_64KB': Uint8List.fromList(List.generate(65536, (i) => i % 256)),
      'xlarge_1MB': Uint8List.fromList(List.generate(1048576, (i) => i % 256)),
    };
  }

  /// Validate RSA key pair mathematical properties
  static bool validateKeyPair(AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> keyPair) {
    final publicKey = keyPair.publicKey;
    final privateKey = keyPair.privateKey;
    
    // Check that public and private keys have the same modulus
    if (publicKey.modulus != privateKey.modulus) {
      return false;
    }
    
    // Check that e * d ≡ 1 (mod φ(n)) by testing with a small message
    try {
      final testMsg = BigInt.from(12345);
      final encrypted = testMsg.modPow(publicKey.exponent!, publicKey.modulus!);
      final decrypted = encrypted.modPow(privateKey.privateExponent!, privateKey.modulus!);
      return decrypted == testMsg;
    } catch (e) {
      return false;
    }
  }

  /// Security validation checks
  static Map<String, bool> validateSecurityProperties(
    AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> keyPair,
  ) {
    final publicKey = keyPair.publicKey;
    final privateKey = keyPair.privateKey;
    
    return {
      'minimumKeySize': publicKey.modulus!.bitLength >= 2048,
      'standardExponent': publicKey.exponent == BigInt.from(65537),
      'modulusIsOdd': publicKey.modulus!.isOdd,
      'privateExponentExists': privateKey.privateExponent != null,
      'keysAreConsistent': validateKeyPair(keyPair),
    };
  }
}

/// Container for a complete blind signature test vector
class BlindSignatureTestVector {
  final AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> keyPair;
  final Uint8List originalMessage;
  final BlindingResult blindingResult;
  final Uint8List blindedSignature;
  final Uint8List unblindedSignature;

  BlindSignatureTestVector({
    required this.keyPair,
    required this.originalMessage,
    required this.blindingResult,
    required this.blindedSignature,
    required this.unblindedSignature,
  });

  /// Verify that this test vector is mathematically correct
  bool verify() {
    return BlindSignatureService.verifySignature(
      originalMessage,
      unblindedSignature,
      keyPair.publicKey,
    );
  }
}