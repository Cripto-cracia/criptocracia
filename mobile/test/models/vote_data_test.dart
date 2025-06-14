import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:criptocracia/services/blind_signature_service.dart';
import '../services/test_utils/test_constants.dart';

void main() {
  group('VoteData', () {
    late VoteData testVoteData;
    
    setUp(() {
      testVoteData = VoteData(
        electionId: TestConstants.testElectionId,
        candidateId: TestConstants.testCandidateId,
        voterId: TestConstants.testVoterId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    });
    
    group('Creation and Basic Properties', () {
      test('should create vote data with correct properties', () {
        expect(testVoteData.electionId, equals(TestConstants.testElectionId));
        expect(testVoteData.candidateId, equals(TestConstants.testCandidateId));
        expect(testVoteData.voterId, equals(TestConstants.testVoterId));
        expect(testVoteData.timestamp, isA<int>());
        expect(testVoteData.timestamp, greaterThan(0));
      });
      
      test('should handle different data types correctly', () {
        final voteData = VoteData(
          electionId: 'election-999',
          candidateId: 0, // Zero candidate ID
          voterId: 'npub1very-long-voter-id-with-special-chars-@#\$%',
          timestamp: 1234567890,
        );
        
        expect(voteData.electionId, equals('election-999'));
        expect(voteData.candidateId, equals(0));
        expect(voteData.voterId, equals('npub1very-long-voter-id-with-special-chars-@#\$%'));
        expect(voteData.timestamp, equals(1234567890));
      });
      
      test('should handle negative candidate ID', () {
        final voteData = VoteData(
          electionId: TestConstants.testElectionId,
          candidateId: -1,
          voterId: TestConstants.testVoterId,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        
        expect(voteData.candidateId, equals(-1));
      });
      
      test('should handle large timestamp values', () {
        final largeTimestamp = DateTime(2099, 12, 31).millisecondsSinceEpoch;
        final voteData = VoteData(
          electionId: TestConstants.testElectionId,
          candidateId: TestConstants.testCandidateId,
          voterId: TestConstants.testVoterId,
          timestamp: largeTimestamp,
        );
        
        expect(voteData.timestamp, equals(largeTimestamp));
      });
    });
    
    group('Serialization', () {
      test('should serialize to expected byte format', () {
        final voteData = VoteData(
          electionId: 'test-election',
          candidateId: 123,
          voterId: 'test-voter',
          timestamp: 1234567890,
        );
        
        final serialized = voteData.serialize();
        final expectedString = 'test-election:123:test-voter:1234567890';
        final expectedBytes = Uint8List.fromList(expectedString.codeUnits);
        
        expect(serialized, equals(expectedBytes));
      });
      
      test('should serialize consistently', () {
        final serialized1 = testVoteData.serialize();
        final serialized2 = testVoteData.serialize();
        
        expect(serialized1, equals(serialized2));
      });
      
      test('should produce different serialization for different data', () {
        final voteData1 = VoteData(
          electionId: 'election-1',
          candidateId: 1,
          voterId: 'voter-1',
          timestamp: 1000000001,
        );
        
        final voteData2 = VoteData(
          electionId: 'election-2',
          candidateId: 2,
          voterId: 'voter-2',
          timestamp: 1000000002,
        );
        
        expect(voteData1.serialize(), isNot(equals(voteData2.serialize())));
      });
      
      test('should handle special characters in serialization', () {
        final voteData = VoteData(
          electionId: 'election-with-special:chars',
          candidateId: 42,
          voterId: 'voter-with-émojis-🗳️',
          timestamp: 1234567890,
        );
        
        final serialized = voteData.serialize();
        final serializedString = String.fromCharCodes(serialized);
        
        expect(serializedString, contains('election-with-special:chars'));
        expect(serializedString, contains('voter-with-émojis-🗳️'));
        expect(serializedString, contains('42'));
        expect(serializedString, contains('1234567890'));
      });
      
      test('should handle empty strings in serialization', () {
        final voteData = VoteData(
          electionId: '',
          candidateId: 0,
          voterId: '',
          timestamp: 0,
        );
        
        final serialized = voteData.serialize();
        final expectedString = ':0::0';
        final expectedBytes = Uint8List.fromList(expectedString.codeUnits);
        
        expect(serialized, equals(expectedBytes));
      });
      
      test('should produce deterministic serialization', () {
        final voteData1 = VoteData(
          electionId: 'consistent-test',
          candidateId: 999,
          voterId: 'consistent-voter',
          timestamp: 1234567890,
        );
        
        final voteData2 = VoteData(
          electionId: 'consistent-test',
          candidateId: 999,
          voterId: 'consistent-voter',
          timestamp: 1234567890,
        );
        
        expect(voteData1.serialize(), equals(voteData2.serialize()));
      });
    });
    
    group('JSON Serialization and Deserialization', () {
      test('should serialize to JSON correctly', () {
        final json = testVoteData.toJson();
        
        expect(json, isA<Map<String, dynamic>>());
        expect(json['election_id'], equals(testVoteData.electionId));
        expect(json['candidate_id'], equals(testVoteData.candidateId));
        expect(json['voter_id'], equals(testVoteData.voterId));
        expect(json['timestamp'], equals(testVoteData.timestamp));
      });
      
      test('should deserialize from JSON correctly', () {
        final json = testVoteData.toJson();
        final deserializedVoteData = VoteData.fromJson(json);
        
        expect(deserializedVoteData.electionId, equals(testVoteData.electionId));
        expect(deserializedVoteData.candidateId, equals(testVoteData.candidateId));
        expect(deserializedVoteData.voterId, equals(testVoteData.voterId));
        expect(deserializedVoteData.timestamp, equals(testVoteData.timestamp));
      });
      
      test('should perform JSON round-trip correctly', () {
        final json = testVoteData.toJson();
        final deserializedVoteData = VoteData.fromJson(json);
        final secondJson = deserializedVoteData.toJson();
        
        expect(secondJson, equals(json));
      });
      
      test('should handle JSON with various data types', () {
        final testCases = [
          {
            'election_id': 'test-123',
            'candidate_id': 42,
            'voter_id': 'npub1234',
            'timestamp': 1234567890,
          },
          {
            'election_id': '',
            'candidate_id': 0,
            'voter_id': '',
            'timestamp': 0,
          },
          {
            'election_id': 'election-with-unicode-🗳️',
            'candidate_id': -1,
            'voter_id': 'voter-with-émojis-🔐',
            'timestamp': 9223372036854775807, // Max int64
          },
        ];
        
        for (final testCase in testCases) {
          final voteData = VoteData.fromJson(testCase);
          final serializedJson = voteData.toJson();
          
          expect(serializedJson['election_id'], equals(testCase['election_id']));
          expect(serializedJson['candidate_id'], equals(testCase['candidate_id']));
          expect(serializedJson['voter_id'], equals(testCase['voter_id']));
          expect(serializedJson['timestamp'], equals(testCase['timestamp']));
        }
      });
      
      test('should maintain serialization consistency between JSON and binary', () {
        final json = testVoteData.toJson();
        final deserializedVoteData = VoteData.fromJson(json);
        
        expect(deserializedVoteData.serialize(), equals(testVoteData.serialize()));
      });
    });
    
    group('Edge Cases and Validation', () {
      test('should handle very long election IDs', () {
        final longElectionId = 'a' * 1000;
        final voteData = VoteData(
          electionId: longElectionId,
          candidateId: TestConstants.testCandidateId,
          voterId: TestConstants.testVoterId,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        
        expect(voteData.electionId, equals(longElectionId));
        expect(voteData.serialize().length, greaterThan(1000));
      });
      
      test('should handle very long voter IDs', () {
        final longVoterId = 'npub1${'a' * 1000}';
        final voteData = VoteData(
          electionId: TestConstants.testElectionId,
          candidateId: TestConstants.testCandidateId,
          voterId: longVoterId,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        
        expect(voteData.voterId, equals(longVoterId));
        expect(voteData.serialize().length, greaterThan(1000));
      });
      
      test('should handle maximum integer values', () {
        final maxTimestamp = 9223372036854775807; // Max int64
        final voteData = VoteData(
          electionId: TestConstants.testElectionId,
          candidateId: 2147483647, // Max int32
          voterId: TestConstants.testVoterId,
          timestamp: maxTimestamp,
        );
        
        expect(voteData.candidateId, equals(2147483647));
        expect(voteData.timestamp, equals(maxTimestamp));
        
        // Should serialize and deserialize correctly
        final json = voteData.toJson();
        final deserializedVoteData = VoteData.fromJson(json);
        expect(deserializedVoteData.candidateId, equals(2147483647));
        expect(deserializedVoteData.timestamp, equals(maxTimestamp));
      });
      
      test('should handle colon characters in data fields', () {
        // Test with colons in data fields (which are used as separators)
        final voteData = VoteData(
          electionId: 'election:with:colons',
          candidateId: 42,
          voterId: 'voter:with:colons',
          timestamp: 1234567890,
        );
        
        final serialized = voteData.serialize();
        final serializedString = String.fromCharCodes(serialized);
        
        // Should contain all colons (including separators)
        expect(serializedString.split(':').length, equals(8)); // 7 colons total = 8 parts
        expect(serializedString, equals('election:with:colons:42:voter:with:colons:1234567890'));
      });
      
      test('should handle newline and tab characters', () {
        final voteData = VoteData(
          electionId: 'election\nwith\nnewlines',
          candidateId: 42,
          voterId: 'voter\twith\ttabs',
          timestamp: 1234567890,
        );
        
        final serialized = voteData.serialize();
        final serializedString = String.fromCharCodes(serialized);
        
        expect(serializedString, contains('\n'));
        expect(serializedString, contains('\t'));
        
        // Should round-trip correctly through JSON
        final json = voteData.toJson();
        final deserializedVoteData = VoteData.fromJson(json);
        expect(deserializedVoteData.electionId, equals('election\nwith\nnewlines'));
        expect(deserializedVoteData.voterId, equals('voter\twith\ttabs'));
      });
    });
    
    group('Integration with BlindSignatureService', () {
      test('should work correctly in voting token creation', () {
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testVoteData.electionId,
          candidateId: testVoteData.candidateId,
          voterId: testVoteData.voterId,
        );
        
        expect(votingToken.voteData.electionId, equals(testVoteData.electionId));
        expect(votingToken.voteData.candidateId, equals(testVoteData.candidateId));
        expect(votingToken.voteData.voterId, equals(testVoteData.voterId));
        expect(votingToken.serializedData, equals(votingToken.voteData.serialize()));
      });
      
      test('should maintain consistency through blind signature workflow', () {
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: 'workflow-test',
          candidateId: 123,
          voterId: 'workflow-voter',
        );
        
        // Verify the vote data serializes consistently
        final originalSerialized = votingToken.voteData.serialize();
        expect(votingToken.serializedData, equals(originalSerialized));
        
        // Serialize to JSON and back
        final json = votingToken.voteData.toJson();
        final deserializedVoteData = VoteData.fromJson(json);
        expect(deserializedVoteData.serialize(), equals(originalSerialized));
      });
    });
  });
}