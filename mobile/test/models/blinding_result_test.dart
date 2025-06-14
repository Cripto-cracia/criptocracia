import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:criptocracia/services/blind_signature_service.dart';
import '../services/test_utils/test_constants.dart';

void main() {
  group('BlindingResult', () {
    late AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> testKeyPair;
    late Uint8List testMessage;
    late BlindingResult testBlindingResult;
    
    setUpAll(() async {
      testKeyPair = await BlindSignatureService.generateKeyPair();
      testMessage = TestConstants.getTestMessageBytes(0);
      testBlindingResult = BlindSignatureService.blindMessage(testMessage, testKeyPair.publicKey);
    });
    
    group('Creation and Basic Properties', () {
      test('should create blinding result with valid data', () {
        expect(testBlindingResult.blindedMessage, isA<Uint8List>());
        expect(testBlindingResult.blindingFactor, isA<Uint8List>());
        expect(testBlindingResult.originalMessageHash, isA<Uint8List>());
        
        expect(testBlindingResult.blindedMessage.length, greaterThan(0));
        expect(testBlindingResult.blindingFactor.length, greaterThan(0));
        expect(testBlindingResult.originalMessageHash.length, equals(32)); // SHA-256 hash length
      });
      
      test('should produce different blinded messages for same input', () {
        final result1 = BlindSignatureService.blindMessage(testMessage, testKeyPair.publicKey);
        final result2 = BlindSignatureService.blindMessage(testMessage, testKeyPair.publicKey);
        
        // Blinded messages should be different due to random blinding factor
        expect(result1.blindedMessage, isNot(equals(result2.blindedMessage)));
        expect(result1.blindingFactor, isNot(equals(result2.blindingFactor)));
        
        // But original message hash should be the same
        expect(result1.originalMessageHash, equals(result2.originalMessageHash));
      });
      
      test('should produce different results for different messages', () {
        final message1 = Uint8List.fromList('Message 1'.codeUnits);
        final message2 = Uint8List.fromList('Message 2'.codeUnits);
        
        final result1 = BlindSignatureService.blindMessage(message1, testKeyPair.publicKey);
        final result2 = BlindSignatureService.blindMessage(message2, testKeyPair.publicKey);
        
        expect(result1.blindedMessage, isNot(equals(result2.blindedMessage)));
        expect(result1.blindingFactor, isNot(equals(result2.blindingFactor)));
        expect(result1.originalMessageHash, isNot(equals(result2.originalMessageHash)));
      });
      
      test('should handle various message sizes', () {
        final messages = [
          Uint8List.fromList('A'.codeUnits), // Single character
          Uint8List.fromList('Hello, World!'.codeUnits), // Normal message
          Uint8List.fromList(('A' * 1000).codeUnits), // Long message
        ];
        
        for (final message in messages) {
          final result = BlindSignatureService.blindMessage(message, testKeyPair.publicKey);
          
          expect(result.blindedMessage.length, greaterThan(0));
          expect(result.blindingFactor.length, greaterThan(0));
          expect(result.originalMessageHash.length, equals(32));
        }
      });
    });
    
    group('Serialization and Deserialization', () {
      test('should serialize to JSON correctly', () {
        final json = testBlindingResult.toJson();
        
        expect(json, isA<Map<String, dynamic>>());
        expect(json['blinded_message'], isA<String>());
        expect(json['blinding_factor'], isA<String>());
        expect(json['original_message_hash'], isA<String>());
        
        // Verify all fields are valid base64
        expect(() => base64.decode(json['blinded_message']), returnsNormally);
        expect(() => base64.decode(json['blinding_factor']), returnsNormally);
        expect(() => base64.decode(json['original_message_hash']), returnsNormally);
      });
      
      test('should deserialize from JSON correctly', () {
        final json = testBlindingResult.toJson();
        final deserializedResult = BlindingResult.fromJson(json);
        
        expect(deserializedResult.blindedMessage, equals(testBlindingResult.blindedMessage));
        expect(deserializedResult.blindingFactor, equals(testBlindingResult.blindingFactor));
        expect(deserializedResult.originalMessageHash, equals(testBlindingResult.originalMessageHash));
      });
      
      test('should perform JSON round-trip correctly', () {
        final json = testBlindingResult.toJson();
        final deserializedResult = BlindingResult.fromJson(json);
        final secondJson = deserializedResult.toJson();
        
        expect(secondJson, equals(json));
      });
      
      test('should handle multiple serialization cycles', () {
        var currentResult = testBlindingResult;
        
        // Perform multiple serialization/deserialization cycles
        for (int i = 0; i < 5; i++) {
          final json = currentResult.toJson();
          currentResult = BlindingResult.fromJson(json);
        }
        
        expect(currentResult.blindedMessage, equals(testBlindingResult.blindedMessage));
        expect(currentResult.blindingFactor, equals(testBlindingResult.blindingFactor));
        expect(currentResult.originalMessageHash, equals(testBlindingResult.originalMessageHash));
      });
    });
    
    group('Cryptographic Properties', () {
      test('should maintain mathematical correctness after serialization', () {
        // Serialize and deserialize the blinding result
        final json = testBlindingResult.toJson();
        final deserializedResult = BlindingResult.fromJson(json);
        
        // Sign the blinded message with the deserialized data
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          deserializedResult.blindedMessage,
          testKeyPair.privateKey,
        );
        
        // Unblind the signature
        final unblindedSignature = BlindSignatureService.unblindSignature(
          blindedSignature,
          deserializedResult.blindingFactor,
          testKeyPair.publicKey,
        );
        
        // Verify the signature
        final isValid = BlindSignatureService.verifySignature(
          testMessage,
          unblindedSignature,
          testKeyPair.publicKey,
        );
        
        expect(isValid, isTrue);
      });
      
      test('should preserve original message hash integrity', () {
        final result1 = BlindSignatureService.blindMessage(testMessage, testKeyPair.publicKey);
        final result2 = BlindSignatureService.blindMessage(testMessage, testKeyPair.publicKey);
        
        // Different blinding operations on same message should have same hash
        expect(result1.originalMessageHash, equals(result2.originalMessageHash));
        
        // Hash should be deterministic for same message
        expect(result1.originalMessageHash, equals(testBlindingResult.originalMessageHash));
      });
      
      test('should ensure blinding factor uniqueness', () {
        final results = <BlindingResult>[];
        
        // Generate multiple blinding results
        for (int i = 0; i < 10; i++) {
          results.add(BlindSignatureService.blindMessage(testMessage, testKeyPair.publicKey));
        }
        
        // All blinding factors should be unique
        final blindingFactors = results.map((r) => base64.encode(r.blindingFactor)).toSet();
        expect(blindingFactors.length, equals(results.length));
        
        // All blinded messages should be unique
        final blindedMessages = results.map((r) => base64.encode(r.blindedMessage)).toSet();
        expect(blindedMessages.length, equals(results.length));
      });
      
      test('should validate blinding factor cryptographic properties', () {
        // The blinding factor should be large enough for security
        expect(testBlindingResult.blindingFactor.length, greaterThanOrEqualTo(256)); // At least 2048 bits / 8
        
        // Should not be all zeros or all ones
        final isAllZeros = testBlindingResult.blindingFactor.every((byte) => byte == 0);
        final isAllOnes = testBlindingResult.blindingFactor.every((byte) => byte == 255);
        
        expect(isAllZeros, isFalse);
        expect(isAllOnes, isFalse);
      });
    });
    
    group('Edge Cases and Error Handling', () {
      test('should handle base64 edge cases in serialization', () {
        // Create a blinding result with edge case data
        final edgeCaseMessage = Uint8List.fromList([0, 255, 128, 64, 32, 16, 8, 4, 2, 1]);
        final edgeCaseResult = BlindSignatureService.blindMessage(edgeCaseMessage, testKeyPair.publicKey);
        
        final json = edgeCaseResult.toJson();
        final deserializedResult = BlindingResult.fromJson(json);
        
        expect(deserializedResult.blindedMessage, equals(edgeCaseResult.blindedMessage));
        expect(deserializedResult.blindingFactor, equals(edgeCaseResult.blindingFactor));
        expect(deserializedResult.originalMessageHash, equals(edgeCaseResult.originalMessageHash));
      });
      
      test('should handle JSON with missing fields gracefully', () {
        // Test with incomplete JSON
        expect(
          () => BlindingResult.fromJson({}),
          throwsA(isA<Error>()),
        );
        
        expect(
          () => BlindingResult.fromJson({'blinded_message': 'test'}),
          throwsA(isA<Error>()),
        );
      });
      
      test('should handle invalid base64 in JSON', () {
        final invalidJson = {
          'blinded_message': 'invalid-base64!@#',
          'blinding_factor': 'SGVsbG8=',
          'original_message_hash': 'V29ybGQ=',
        };
        
        expect(
          () => BlindingResult.fromJson(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });
      
      test('should validate data consistency after deserialization', () {
        final json = testBlindingResult.toJson();
        final deserializedResult = BlindingResult.fromJson(json);
        
        // Verify lengths are consistent
        expect(
          deserializedResult.blindedMessage.length,
          equals(testBlindingResult.blindedMessage.length),
        );
        expect(
          deserializedResult.blindingFactor.length,
          equals(testBlindingResult.blindingFactor.length),
        );
        expect(
          deserializedResult.originalMessageHash.length,
          equals(32), // SHA-256 hash length
        );
      });
    });
    
    group('Performance and Memory Tests', () {
      test('should handle large messages efficiently', () {
        // Skip performance test in CI or low-power environments to avoid flaky failures
        const isCi = bool.fromEnvironment('CI', defaultValue: false);
        const isSlowDevice = bool.fromEnvironment('SLOW_DEVICE', defaultValue: false);
        if (isCi || isSlowDevice) {
          return; // Skip test in CI or on slow devices
        }
        
        final largeMessage = Uint8List.fromList(List.generate(100000, (i) => i % 256));
        
        final stopwatch = Stopwatch()..start();
        final result = BlindSignatureService.blindMessage(largeMessage, testKeyPair.publicKey);
        stopwatch.stop();
        
        // Increased timeout for slower environments and possible GC pauses
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete in under 5 seconds
        expect(result.blindedMessage.length, greaterThan(0));
        expect(result.originalMessageHash.length, equals(32));
      });
      
      test('should serialize large results efficiently', () {
        // Skip performance test in CI or low-power environments to avoid flaky failures
        const isCi = bool.fromEnvironment('CI', defaultValue: false);
        const isSlowDevice = bool.fromEnvironment('SLOW_DEVICE', defaultValue: false);
        if (isCi || isSlowDevice) {
          return; // Skip test in CI or on slow devices
        }
        
        final largeMessage = Uint8List.fromList(List.generate(50000, (i) => i % 256));
        final result = BlindSignatureService.blindMessage(largeMessage, testKeyPair.publicKey);
        
        final stopwatch = Stopwatch()..start();
        final json = result.toJson();
        final deserializedResult = BlindingResult.fromJson(json);
        stopwatch.stop();
        
        // Increased timeout for slower environments and possible GC pauses
        expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // Should complete in under 2 seconds
        expect(deserializedResult.blindedMessage, equals(result.blindedMessage));
      });
    });
  });
}