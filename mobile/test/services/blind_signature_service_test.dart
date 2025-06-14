import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:criptocracia/services/blind_signature_service.dart';

void main() {
  group('BlindSignatureService', () {
    late AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> testKeyPair;
    late RSAPublicKey publicKey;
    late RSAPrivateKey privateKey;
    late Uint8List testMessage;

    setUpAll(() async {
      // Generate a test key pair for use in all tests
      testKeyPair = await BlindSignatureService.generateKeyPair();
      publicKey = testKeyPair.publicKey;
      privateKey = testKeyPair.privateKey;
      testMessage = Uint8List.fromList('Hello, World! This is a test message.'.codeUnits);
    });

    group('Key Generation', () {
      test('should generate valid RSA key pairs asynchronously', () async {
        final keyPair = await BlindSignatureService.generateKeyPair();
        
        expect(keyPair.publicKey, isA<RSAPublicKey>());
        expect(keyPair.privateKey, isA<RSAPrivateKey>());
        expect(keyPair.publicKey.modulus, isNotNull);
        expect(keyPair.publicKey.exponent, isNotNull);
        expect(keyPair.privateKey.modulus, isNotNull);
        expect(keyPair.privateKey.privateExponent, isNotNull);
      });

      test('should generate keys with minimum 2048-bit length', () async {
        final keyPair = await BlindSignatureService.generateKeyPair();
        
        expect(keyPair.publicKey.modulus!.bitLength, greaterThanOrEqualTo(2048));
        expect(keyPair.privateKey.modulus!.bitLength, greaterThanOrEqualTo(2048));
      });

      test('should generate different keys on multiple calls', () async {
        final keyPair1 = await BlindSignatureService.generateKeyPair();
        final keyPair2 = await BlindSignatureService.generateKeyPair();
        
        expect(keyPair1.publicKey.modulus, isNot(equals(keyPair2.publicKey.modulus)));
        expect(keyPair1.privateKey.privateExponent, isNot(equals(keyPair2.privateKey.privateExponent)));
      });

      test('should have consistent modulus between public and private keys', () async {
        final keyPair = await BlindSignatureService.generateKeyPair();
        
        expect(keyPair.publicKey.modulus, equals(keyPair.privateKey.modulus));
      });
    });

    group('PEM Format Conversion', () {
      test('should convert public key to valid PEM format', () {
        final pemKey = BlindSignatureService.publicKeyToPem(publicKey);
        
        expect(pemKey, contains('-----BEGIN RSA PUBLIC KEY-----'));
        expect(pemKey, contains('-----END RSA PUBLIC KEY-----'));
        expect(pemKey.split('\n').length, greaterThan(2));
      });

      test('should parse public key from PEM format', () {
        final pemKey = BlindSignatureService.publicKeyToPem(publicKey);
        final parsedKey = BlindSignatureService.publicKeyFromPem(pemKey);
        
        expect(parsedKey.modulus, equals(publicKey.modulus));
        expect(parsedKey.exponent, equals(publicKey.exponent));
      });

      test('should perform PEM round-trip conversion correctly', () {
        final originalPem = BlindSignatureService.publicKeyToPem(publicKey);
        final parsedKey = BlindSignatureService.publicKeyFromPem(originalPem);
        final roundTripPem = BlindSignatureService.publicKeyToPem(parsedKey);
        
        expect(roundTripPem, equals(originalPem));
      });

      test('should throw FormatException for invalid PEM', () {
        expect(
          () => BlindSignatureService.publicKeyFromPem('invalid-pem'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('DER Format Conversion', () {
      test('should convert public key to DER bytes', () {
        final derBytes = BlindSignatureService.publicKeyToDer(publicKey);
        
        expect(derBytes, isA<Uint8List>());
        expect(derBytes.length, greaterThan(0));
      });

      test('should parse public key from DER bytes', () {
        final derBytes = BlindSignatureService.publicKeyToDer(publicKey);
        final parsedKey = BlindSignatureService.publicKeyFromDer(derBytes);
        
        expect(parsedKey.modulus, equals(publicKey.modulus));
        expect(parsedKey.exponent, equals(publicKey.exponent));
      });

      test('should perform DER round-trip conversion correctly', () {
        final originalDer = BlindSignatureService.publicKeyToDer(publicKey);
        final parsedKey = BlindSignatureService.publicKeyFromDer(originalDer);
        final roundTripDer = BlindSignatureService.publicKeyToDer(parsedKey);
        
        expect(roundTripDer, equals(originalDer));
      });

      test('should throw FormatException for invalid DER', () {
        final invalidDer = Uint8List.fromList([1, 2, 3, 4, 5]);
        
        expect(
          () => BlindSignatureService.publicKeyFromDer(invalidDer),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('PEM/DER Conversion Compatibility', () {
      test('should produce consistent results between PEM and DER', () {
        final pemKey = BlindSignatureService.publicKeyToPem(publicKey);
        final derBytes = BlindSignatureService.publicKeyToDer(publicKey);
        
        final keyFromPem = BlindSignatureService.publicKeyFromPem(pemKey);
        final keyFromDer = BlindSignatureService.publicKeyFromDer(derBytes);
        
        expect(keyFromPem.modulus, equals(keyFromDer.modulus));
        expect(keyFromPem.exponent, equals(keyFromDer.exponent));
      });
    });

    group('Blind Signature Operations', () {
      test('should blind a message successfully', () {
        final blindingResult = BlindSignatureService.blindMessage(testMessage, publicKey);
        
        expect(blindingResult.blindedMessage, isA<Uint8List>());
        expect(blindingResult.blindingFactor, isA<Uint8List>());
        expect(blindingResult.originalMessageHash, isA<Uint8List>());
        expect(blindingResult.blindedMessage.length, greaterThan(0));
        expect(blindingResult.blindingFactor.length, greaterThan(0));
      });

      test('should produce different blinded messages for same input', () {
        final result1 = BlindSignatureService.blindMessage(testMessage, publicKey);
        final result2 = BlindSignatureService.blindMessage(testMessage, publicKey);
        
        // Blinded messages should be different due to random blinding factor
        expect(result1.blindedMessage, isNot(equals(result2.blindedMessage)));
        expect(result1.blindingFactor, isNot(equals(result2.blindingFactor)));
        
        // But original message hash should be the same
        expect(result1.originalMessageHash, equals(result2.originalMessageHash));
      });

      test('should sign blinded message', () {
        final blindingResult = BlindSignatureService.blindMessage(testMessage, publicKey);
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          privateKey,
        );
        
        expect(blindedSignature, isA<Uint8List>());
        expect(blindedSignature.length, greaterThan(0));
      });

      test('should unblind signature correctly', () {
        final blindingResult = BlindSignatureService.blindMessage(testMessage, publicKey);
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          privateKey,
        );
        
        final unblindedSignature = BlindSignatureService.unblindSignature(
          blindedSignature,
          blindingResult.blindingFactor,
          publicKey,
        );
        
        expect(unblindedSignature, isA<Uint8List>());
        expect(unblindedSignature.length, greaterThan(0));
      });

      test('should verify unblinded signature', () {
        final blindingResult = BlindSignatureService.blindMessage(testMessage, publicKey);
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          privateKey,
        );
        final unblindedSignature = BlindSignatureService.unblindSignature(
          blindedSignature,
          blindingResult.blindingFactor,
          publicKey,
        );
        
        final isValid = BlindSignatureService.verifySignature(
          testMessage,
          unblindedSignature,
          publicKey,
        );
        
        expect(isValid, isTrue);
      });

      test('should complete full blind signature workflow', () {
        // 1. Blind the message
        final blindingResult = BlindSignatureService.blindMessage(testMessage, publicKey);
        
        // 2. Authority signs the blinded message
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          privateKey,
        );
        
        // 3. Voter unblinds the signature
        final unblindedSignature = BlindSignatureService.unblindSignature(
          blindedSignature,
          blindingResult.blindingFactor,
          publicKey,
        );
        
        // 4. Anyone can verify the signature
        final isValid = BlindSignatureService.verifySignature(
          testMessage,
          unblindedSignature,
          publicKey,
        );
        
        expect(isValid, isTrue);
      });

      test('should fail verification with wrong message', () {
        final blindingResult = BlindSignatureService.blindMessage(testMessage, publicKey);
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          privateKey,
        );
        final unblindedSignature = BlindSignatureService.unblindSignature(
          blindedSignature,
          blindingResult.blindingFactor,
          publicKey,
        );
        
        final wrongMessage = Uint8List.fromList('Wrong message'.codeUnits);
        final isValid = BlindSignatureService.verifySignature(
          wrongMessage,
          unblindedSignature,
          publicKey,
        );
        
        expect(isValid, isFalse);
      });

      test('should fail verification with wrong signature', () {
        final wrongSignature = Uint8List.fromList(List.generate(256, (i) => i % 256));
        
        final isValid = BlindSignatureService.verifySignature(
          testMessage,
          wrongSignature,
          publicKey,
        );
        
        expect(isValid, isFalse);
      });
    });

    group('Input Validation', () {
      test('should throw ArgumentError for null message', () {
        expect(
          () => BlindSignatureService.blindMessage(Uint8List(0), publicKey),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for null public key', () {
        expect(
          () => BlindSignatureService.blindMessage(testMessage, null as dynamic),
          throwsA(isA<Error>()),
        );
      });

      test('should throw ArgumentError for weak RSA key', () async {
        // Create a weak 1024-bit key for testing
        final weakKeyGen = RSAKeyGenerator();
        final secureRandom = SecureRandom('Fortuna');
        secureRandom.seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => i))));
        
        weakKeyGen.init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64),
          secureRandom,
        ));
        
        final weakKeyPair = weakKeyGen.generateKeyPair();
        final weakPublicKey = weakKeyPair.publicKey as RSAPublicKey;
        
        expect(
          () => BlindSignatureService.blindMessage(testMessage, weakPublicKey),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Voting Token Creation', () {
      test('should create voting token with valid data', () {
        final token = BlindSignatureService.createVotingToken(
          electionId: 'test-election-123',
          candidateId: 42,
          voterId: 'npub1234567890',
        );
        
        expect(token.voteData.electionId, equals('test-election-123'));
        expect(token.voteData.candidateId, equals(42));
        expect(token.voteData.voterId, equals('npub1234567890'));
        expect(token.voteData.timestamp, isA<int>());
        expect(token.serializedData, isA<Uint8List>());
      });

      test('should serialize and deserialize voting token', () {
        final originalToken = BlindSignatureService.createVotingToken(
          electionId: 'test-election-456',
          candidateId: 99,
          voterId: 'npub9876543210',
        );
        
        final json = originalToken.toJson();
        final deserializedToken = VotingToken.fromJson(json);
        
        expect(deserializedToken.voteData.electionId, equals(originalToken.voteData.electionId));
        expect(deserializedToken.voteData.candidateId, equals(originalToken.voteData.candidateId));
        expect(deserializedToken.voteData.voterId, equals(originalToken.voteData.voterId));
        expect(deserializedToken.voteData.timestamp, equals(originalToken.voteData.timestamp));
        expect(deserializedToken.serializedData, equals(originalToken.serializedData));
      });
    });

    group('BlindingResult Serialization', () {
      test('should serialize and deserialize BlindingResult', () {
        final blindingResult = BlindSignatureService.blindMessage(testMessage, publicKey);
        
        final json = blindingResult.toJson();
        final deserializedResult = BlindingResult.fromJson(json);
        
        expect(deserializedResult.blindedMessage, equals(blindingResult.blindedMessage));
        expect(deserializedResult.blindingFactor, equals(blindingResult.blindingFactor));
        expect(deserializedResult.originalMessageHash, equals(blindingResult.originalMessageHash));
      });
    });

    group('Performance Tests', () {
      test('should complete key generation within reasonable time', () async {
        // Skip performance test in CI or low-power environments to avoid flaky failures
        const isCi = bool.fromEnvironment('CI', defaultValue: false);
        const isSlowDevice = bool.fromEnvironment('SLOW_DEVICE', defaultValue: false);
        if (isCi || isSlowDevice) {
          return; // Skip test in CI or on slow devices
        }
        
        final stopwatch = Stopwatch()..start();
        await BlindSignatureService.generateKeyPair();
        stopwatch.stop();
        
        // RSA 2048-bit key generation can take up to 30 seconds on slower real devices
        // This accounts for low-power processors, thermal throttling, and background tasks
        expect(stopwatch.elapsedMilliseconds, lessThan(30000));
      }, timeout: const Timeout(Duration(seconds: 35)));

      test('should complete blind signature operations efficiently', () {
        // Skip performance test in CI or low-power environments to avoid flaky failures
        const isCi = bool.fromEnvironment('CI', defaultValue: false);
        const isSlowDevice = bool.fromEnvironment('SLOW_DEVICE', defaultValue: false);
        const skipTiming = bool.fromEnvironment('SKIP_TIMING', defaultValue: false);
        
        if (isCi || isSlowDevice) {
          return; // Skip test in CI or on slow devices
        }
        
        final stopwatch = Stopwatch()..start();
        
        final blindingResult = BlindSignatureService.blindMessage(testMessage, publicKey);
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          privateKey,
        );
        final unblindedSignature = BlindSignatureService.unblindSignature(
          blindedSignature,
          blindingResult.blindingFactor,
          publicKey,
        );
        final isValid = BlindSignatureService.verifySignature(
          testMessage,
          unblindedSignature,
          publicKey,
        );
        
        stopwatch.stop();
        
        // Always verify functional correctness
        expect(isValid, isTrue);
        
        // Only check timing if not explicitly skipped (for emulators or very slow environments)
        if (!skipTiming) {
          // Relaxed timeout for slower environments - increased from 1s to 10s
          // This accounts for emulators, slower CI environments, and resource contention
          expect(stopwatch.elapsedMilliseconds, lessThan(10000));
        }
      });
    });
  });
}