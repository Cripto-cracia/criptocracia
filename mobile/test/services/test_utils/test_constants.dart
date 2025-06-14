import 'dart:typed_data';

/// Test constants and configuration for RSA blind signature testing
class TestConstants {
  // Test election data
  static const String testElectionId = 'test-election-12345';
  static const String testElectionName = 'Test Election 2024';
  static const String testElectionDescription = 'A test election for unit testing';
  
  // Test candidate data
  static const int testCandidateId = 42;
  static const String testCandidateName = 'Test Candidate';
  
  // Test voter data
  static const String testVoterId = 'npub1234567890abcdef';
  static const String testVoterNpub = 'npub1test567890abcdef123456';
  static const String testVoterNonce = 'abcdef1234567890';
  
  // Test session data
  static const String testSessionId = 'test-session-12345';
  static const String testSessionId2 = 'test-session-67890';
  
  // Cryptographic test parameters
  static const int rsaKeySize = 2048;
  static const int rsaExponent = 65537;
  static const int weakKeySize = 1024;
  static const int minSecureKeySize = 2048;
  
  // Test message samples
  static const List<String> testMessages = [
    'Hello, World!',
    'Test message for blind signature verification',
    'Vote for candidate 123 in election ABC',
    'Short msg',
    'A very long message that exceeds typical lengths to test RSA operations',
    '', // Empty message edge case
    '🗳️ Unicode vote message 🔐',
    'Special chars: !@#\$%^&*()[]{}|\\:";\'<>?,./`~',
  ];
  
  // Performance test configuration
  static const Map<String, dynamic> performanceConfig = {
    'keyGenerationTimeoutMs': 15000,
    'signatureOperationTimeoutMs': 2000,
    'maxMemoryUsageMB': 100,
    'batchTestSize': 10,
    'performanceIterations': 5,
  };
  
  // Security test configuration
  static const Map<String, dynamic> securityConfig = {
    'minBlindingFactorBits': 2040,
    'maxTimingVarianceMs': 50,
    'randomnessTestSampleSize': 1000,
    'unlinkabilityTestCount': 100,
  };
  
  // Test timeouts
  static const Duration defaultTestTimeout = Duration(seconds: 30);
  static const Duration keyGenerationTimeout = Duration(seconds: 15);
  static const Duration performanceTestTimeout = Duration(minutes: 2);
  
  // Error test data
  static const Map<String, String> errorTestCases = {
    'invalidPem': 'invalid-pem-data',
    'malformedJson': '{"invalid": json}',
    'emptyString': '',
    'nullValue': 'null',
  };
  
  // Base64 test vectors
  static const Map<String, String> base64TestVectors = {
    'hello': 'SGVsbG8sIFdvcmxkIQ==',
    'empty': '',
    'binary': 'AQIDBAUGBwgJCgsMDQ4PEA==',
  };
  
  /// Get test message by index
  static String getTestMessage(int index) {
    return testMessages[index % testMessages.length];
  }
  
  /// Get test data of specified size
  static List<int> getTestData(int size) {
    return List.generate(size, (i) => i % 256);
  }

  /// Get test message bytes by index
  static Uint8List getTestMessageBytes(int index) {
    final message = getTestMessage(index);
    return Uint8List.fromList(message.codeUnits);
  }
  
  /// Generate test election data
  static Map<String, dynamic> getTestElectionData() {
    return {
      'id': testElectionId,
      'name': testElectionName,
      'description': testElectionDescription,
      'start_time': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'end_time': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'status': 'in-progress',
      'total_votes': 0,
    };
  }
  
  /// Generate test candidate data
  static Map<String, dynamic> getTestCandidateData() {
    return {
      'id': testCandidateId,
      'name': testCandidateName,
    };
  }
  
  /// Generate test voter data
  static Map<String, dynamic> getTestVoterData() {
    return {
      'voter_id': testVoterId,
      'npub': testVoterNpub,
      'nonce': testVoterNonce,
    };
  }
}