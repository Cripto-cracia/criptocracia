import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:criptocracia/services/blind_signature_service.dart';

void main() {
  group('VotingToken', () {
    late VoteData testVoteData;
    late VotingToken testVotingToken;

    setUp(() {
      testVoteData = VoteData(
        electionId: 'test-election-123',
        candidateId: 42,
        voterId: 'npub1234567890abcdef',
        timestamp: 1234567890,
      );
      
      testVotingToken = VotingToken(
        voteData: testVoteData,
        serializedData: testVoteData.serialize(),
      );
    });

    group('VoteData', () {
      test('should create VoteData with required fields', () {
        expect(testVoteData.electionId, equals('test-election-123'));
        expect(testVoteData.candidateId, equals(42));
        expect(testVoteData.voterId, equals('npub1234567890abcdef'));
        expect(testVoteData.timestamp, equals(1234567890));
      });

      test('should serialize VoteData to bytes', () {
        final serialized = testVoteData.serialize();
        
        expect(serialized, isA<Uint8List>());
        expect(serialized.length, greaterThan(0));
        
        final expectedString = 'test-election-123:42:npub1234567890abcdef:1234567890';
        final expectedBytes = Uint8List.fromList(expectedString.codeUnits);
        
        expect(serialized, equals(expectedBytes));
      });

      test('should serialize different VoteData differently', () {
        final voteData1 = VoteData(
          electionId: 'election-1',
          candidateId: 1,
          voterId: 'voter-1',
          timestamp: 1000,
        );
        
        final voteData2 = VoteData(
          electionId: 'election-2',
          candidateId: 2,
          voterId: 'voter-2',
          timestamp: 2000,
        );
        
        expect(voteData1.serialize(), isNot(equals(voteData2.serialize())));
      });

      test('should convert VoteData to JSON', () {
        final json = testVoteData.toJson();
        
        expect(json, isA<Map<String, dynamic>>());
        expect(json['election_id'], equals('test-election-123'));
        expect(json['candidate_id'], equals(42));
        expect(json['voter_id'], equals('npub1234567890abcdef'));
        expect(json['timestamp'], equals(1234567890));
      });

      test('should create VoteData from JSON', () {
        final json = {
          'election_id': 'test-election-456',
          'candidate_id': 99,
          'voter_id': 'npub9876543210fedcba',
          'timestamp': 9876543210,
        };
        
        final voteData = VoteData.fromJson(json);
        
        expect(voteData.electionId, equals('test-election-456'));
        expect(voteData.candidateId, equals(99));
        expect(voteData.voterId, equals('npub9876543210fedcba'));
        expect(voteData.timestamp, equals(9876543210));
      });

      test('should perform JSON round-trip conversion', () {
        final originalJson = testVoteData.toJson();
        final recreatedVoteData = VoteData.fromJson(originalJson);
        final roundTripJson = recreatedVoteData.toJson();
        
        expect(roundTripJson, equals(originalJson));
        expect(recreatedVoteData.serialize(), equals(testVoteData.serialize()));
      });
    });

    group('VotingToken', () {
      test('should create VotingToken with VoteData and serialized data', () {
        expect(testVotingToken.voteData, equals(testVoteData));
        expect(testVotingToken.serializedData, equals(testVoteData.serialize()));
      });

      test('should create VotingToken using factory method', () {
        final token = BlindSignatureService.createVotingToken(
          electionId: 'factory-election-123',
          candidateId: 77,
          voterId: 'factory-voter-npub',
        );
        
        expect(token, isA<VotingToken>());
        expect(token.voteData.electionId, equals('factory-election-123'));
        expect(token.voteData.candidateId, equals(77));
        expect(token.voteData.voterId, equals('factory-voter-npub'));
        expect(token.voteData.timestamp, isA<int>());
        expect(token.serializedData, isA<Uint8List>());
      });

      test('should convert VotingToken to JSON', () {
        final json = testVotingToken.toJson();
        
        expect(json, isA<Map<String, dynamic>>());
        expect(json['vote_data'], isA<Map<String, dynamic>>());
        expect(json['serialized_data'], isA<String>());
        
        // Verify vote data
        final voteDataJson = json['vote_data'] as Map<String, dynamic>;
        expect(voteDataJson['election_id'], equals('test-election-123'));
        expect(voteDataJson['candidate_id'], equals(42));
        
        // Verify serialized data is base64 encoded
        final serializedDataB64 = json['serialized_data'] as String;
        expect(() => base64.decode(serializedDataB64), returnsNormally);
        
        final decodedData = base64.decode(serializedDataB64);
        expect(decodedData, equals(testVoteData.serialize()));
      });

      test('should create VotingToken from JSON', () {
        final json = {
          'vote_data': {
            'election_id': 'json-election-789',
            'candidate_id': 88,
            'voter_id': 'json-voter-npub',
            'timestamp': 1111111111,
          },
          'serialized_data': base64.encode(Uint8List.fromList('test-data'.codeUnits)),
        };
        
        final token = VotingToken.fromJson(json);
        
        expect(token.voteData.electionId, equals('json-election-789'));
        expect(token.voteData.candidateId, equals(88));
        expect(token.voteData.voterId, equals('json-voter-npub'));
        expect(token.voteData.timestamp, equals(1111111111));
        expect(token.serializedData, equals(Uint8List.fromList('test-data'.codeUnits)));
      });

      test('should perform JSON round-trip conversion', () {
        final originalJson = testVotingToken.toJson();
        final recreatedToken = VotingToken.fromJson(originalJson);
        final roundTripJson = recreatedToken.toJson();
        
        expect(roundTripJson, equals(originalJson));
        expect(recreatedToken.voteData.electionId, equals(testVotingToken.voteData.electionId));
        expect(recreatedToken.voteData.candidateId, equals(testVotingToken.voteData.candidateId));
        expect(recreatedToken.serializedData, equals(testVotingToken.serializedData));
      });

      test('should handle different timestamp formats', () {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final token = BlindSignatureService.createVotingToken(
          electionId: 'timestamp-test',
          candidateId: 1,
          voterId: 'timestamp-voter',
        );
        
        expect(token.voteData.timestamp, isA<int>());
        expect(token.voteData.timestamp, greaterThanOrEqualTo(currentTime - 1000));
        expect(token.voteData.timestamp, lessThanOrEqualTo(currentTime + 1000));
      });
    });

    group('Edge Cases', () {
      test('should handle empty strings', () {
        final voteData = VoteData(
          electionId: '',
          candidateId: 0,
          voterId: '',
          timestamp: 0,
        );
        
        final serialized = voteData.serialize();
        expect(serialized, equals(Uint8List.fromList(':::0'.codeUnits)));
        
        final json = voteData.toJson();
        final recreated = VoteData.fromJson(json);
        expect(recreated.serialize(), equals(serialized));
      });

      test('should handle special characters in strings', () {
        final voteData = VoteData(
          electionId: 'test-élection-123',
          candidateId: 42,
          voterId: 'npub-spëcial-chars',
          timestamp: 1234567890,
        );
        
        final serialized = voteData.serialize();
        expect(serialized.length, greaterThan(0));
        
        final json = voteData.toJson();
        final recreated = VoteData.fromJson(json);
        expect(recreated.electionId, equals('test-élection-123'));
        expect(recreated.voterId, equals('npub-spëcial-chars'));
      });

      test('should handle very large candidate IDs', () {
        final voteData = VoteData(
          electionId: 'large-id-test',
          candidateId: 999999999,
          voterId: 'large-id-voter',
          timestamp: 9999999999999,
        );
        
        final serialized = voteData.serialize();
        expect(serialized.length, greaterThan(0));
        
        final json = voteData.toJson();
        final recreated = VoteData.fromJson(json);
        expect(recreated.candidateId, equals(999999999));
        expect(recreated.timestamp, equals(9999999999999));
      });

      test('should handle negative candidate IDs', () {
        final voteData = VoteData(
          electionId: 'negative-test',
          candidateId: -1,
          voterId: 'negative-voter',
          timestamp: 1234567890,
        );
        
        final serialized = voteData.serialize();
        expect(serialized.length, greaterThan(0));
        
        final json = voteData.toJson();
        final recreated = VoteData.fromJson(json);
        expect(recreated.candidateId, equals(-1));
      });

      test('should handle long election IDs and voter IDs', () {
        final longElectionId = 'a' * 1000;
        final longVoterId = 'b' * 1000;
        
        final voteData = VoteData(
          electionId: longElectionId,
          candidateId: 1,
          voterId: longVoterId,
          timestamp: 1234567890,
        );
        
        final serialized = voteData.serialize();
        expect(serialized.length, greaterThan(2000));
        
        final json = voteData.toJson();
        final recreated = VoteData.fromJson(json);
        expect(recreated.electionId, equals(longElectionId));
        expect(recreated.voterId, equals(longVoterId));
      });
    });

    group('Performance Tests', () {
      test('should serialize and deserialize efficiently', () {
        // Skip performance test in CI or low-power environments to avoid flaky failures
        // due to GC pauses and resource constraints
        const isCi = bool.fromEnvironment('CI', defaultValue: false);
        const isSlowDevice = bool.fromEnvironment('SLOW_DEVICE', defaultValue: false);
        if (isCi || isSlowDevice) {
          return; // Skip test in CI or on slow devices
        }
        
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 1000; i++) {
          final voteData = VoteData(
            electionId: 'perf-test-$i',
            candidateId: i,
            voterId: 'perf-voter-$i',
            timestamp: 1234567890 + i,
          );
          
          final serialized = voteData.serialize();
          final json = voteData.toJson();
          final recreated = VoteData.fromJson(json);
          
          expect(recreated.serialize(), equals(serialized));
        }
        
        stopwatch.stop();
        // Increased timeout for slower environments and possible GC pauses
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete in under 5 seconds
      });

      test('should handle multiple VotingToken creations efficiently', () {
        // Skip performance test in CI or low-power environments to avoid flaky failures
        const isCi = bool.fromEnvironment('CI', defaultValue: false);
        const isSlowDevice = bool.fromEnvironment('SLOW_DEVICE', defaultValue: false);
        if (isCi || isSlowDevice) {
          return; // Skip test in CI or on slow devices
        }
        
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 100; i++) {
          final token = BlindSignatureService.createVotingToken(
            electionId: 'batch-election-$i',
            candidateId: i,
            voterId: 'batch-voter-$i',
          );
          
          final json = token.toJson();
          final recreated = VotingToken.fromJson(json);
          
          expect(recreated.voteData.candidateId, equals(i));
        }
        
        stopwatch.stop();
        // Increased timeout for slower environments and possible GC pauses
        expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // Should complete in under 2 seconds
      });
    });
  });
}