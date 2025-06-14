import 'package:pointycastle/export.dart';

/// Mock RSA key pairs for consistent testing
class MockKeyPairs {
  // Pre-generated test key pair for deterministic testing
  static final BigInt _testModulus = BigInt.parse(
    '249168708513463056221708540635081681620688489798235985535029639737966327738692'
    '470150965492508794993243699675247061698346256830895194609559887171737633647357'
    '841055962949953522095061915134701485506569976733906031138577775862394846119723'
    '45893050901062081456139174124073092949577072568965806966642467654213096031193',
  );
  
  static final BigInt _testExponent = BigInt.from(65537);
  
  static final BigInt _testPrivateExponent = BigInt.parse(
    '191434537486716317664565249500908306513699150159380668458308470635360737464977'
    '245399663973450320383186671784385145165958497813977259853301346707181615963364'
    '783165901734537993635647774966985503838503528329851993928983845072273468061852'
    '01851506325094179693951536142655488881516891451063628745701043074273193489',
  );

  /// Get a test RSA key pair for deterministic testing
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> getTestKeyPair() {
    final publicKey = RSAPublicKey(_testModulus, _testExponent);
    final privateKey = RSAPrivateKey(_testModulus, _testPrivateExponent, null, null);
    
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(publicKey, privateKey);
  }

  /// Get a second test key pair for multi-key testing
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> getSecondTestKeyPair() {
    // Different modulus for second key pair
    final secondModulus = BigInt.parse(
      '182745928374659283746592837465928374659283746592837465928374659283746592837465'
      '928374659283746592837465928374659283746592837465928374659283746592837465928374'
      '659283746592837465928374659283746592837465928374659283746592837465928374659283'
      '74659283746592837465928374659283746592837465928374659283746592837465928374659',
    );
    
    final secondPrivateExponent = BigInt.parse(
      '123456789012345678901234567890123456789012345678901234567890123456789012345678'
      '901234567890123456789012345678901234567890123456789012345678901234567890123456'
      '789012345678901234567890123456789012345678901234567890123456789012345678901234'
      '567890123456789012345678901234567890123456789012345678901234567890123456789',
    );
    
    final publicKey = RSAPublicKey(secondModulus, _testExponent);
    final privateKey = RSAPrivateKey(secondModulus, secondPrivateExponent, null, null);
    
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(publicKey, privateKey);
  }

  /// Get a weak 1024-bit key pair for security testing
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> getWeakKeyPair() {
    // Smaller modulus for weak key testing
    final weakModulus = BigInt.parse(
      '123456789012345678901234567890123456789012345678901234567890123456789012345678'
      '901234567890123456789012345678901234567890123456789012345678901234567890123456'
      '789012345678901234567890123456789012345678901234567890123456789012345678901234'
      '567890123456789012345678901234567890123456789012345678901234567890123456789',
    );
    
    final weakPrivateExponent = BigInt.parse(
      '987654321098765432109876543210987654321098765432109876543210987654321098765432'
      '109876543210987654321098765432109876543210987654321098765432109876543210987654'
      '321098765432109876543210987654321098765432109876543210987654321098765432109876'
      '543210987654321098765432109876543210987654321098765432109876543210987654321',
    );
    
    final publicKey = RSAPublicKey(weakModulus, _testExponent);
    final privateKey = RSAPrivateKey(weakModulus, weakPrivateExponent, null, null);
    
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(publicKey, privateKey);
  }

  /// Generate multiple key pairs for batch testing
  static List<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>> getMultipleKeyPairs(int count) {
    final keyPairs = <AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>>[];
    
    // Add pre-defined key pairs
    keyPairs.add(getTestKeyPair());
    if (count > 1) keyPairs.add(getSecondTestKeyPair());
    
    // Generate additional key pairs if needed
    for (int i = 2; i < count; i++) {
      // Create variations by modifying the modulus slightly
      final baseModulus = _testModulus;
      final variedModulus = baseModulus + BigInt.from(i * 1000000);
      final variedPrivateExponent = _testPrivateExponent + BigInt.from(i * 500000);
      
      final publicKey = RSAPublicKey(variedModulus, _testExponent);
      final privateKey = RSAPrivateKey(variedModulus, variedPrivateExponent, null, null);
      
      keyPairs.add(AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(publicKey, privateKey));
    }
    
    return keyPairs;
  }

  /// Test data for key validation
  static Map<String, dynamic> getKeyValidationData() {
    return {
      'validModulusBitLength': 2048,
      'validExponent': 65537,
      'minSecureKeySize': 2048,
      'weakKeySize': 1024,
      'testMessages': [
        'Hello, World!',
        'Test message for RSA operations',
        'Short',
        'A very long message that tests the limits of RSA encryption and signing operations to ensure proper handling of various message sizes and content types.',
      ],
    };
  }

  /// Performance testing configurations
  static Map<String, dynamic> getPerformanceTestConfig() {
    return {
      'keyGenerationTimeout': 15000, // 15 seconds
      'signatureOperationTimeout': 2000, // 2 seconds
      'maxMemoryUsageMB': 100,
      'batchTestSize': 10,
      'performanceIterations': 5,
    };
  }

  /// Security test configurations
  static Map<String, dynamic> getSecurityTestConfig() {
    return {
      'minBlindingFactorBits': 2040, // Should be close to modulus size
      'maxTimingVarianceMs': 50, // Max acceptable timing variance
      'randomnessTestSampleSize': 1000,
      'unlinkabilityTestCount': 100,
    };
  }
}