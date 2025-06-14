import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:criptocracia/services/voting_crypto_service.dart';
import 'package:criptocracia/services/blind_signature_service.dart';
import 'package:criptocracia/models/election.dart';
import 'package:criptocracia/models/voter.dart';

// Mock secure storage for testing
class MockSecureStorage extends FlutterSecureStorage {
  static final Map<String, String> _storage = {};

  const MockSecureStorage() : super();

  @override
  Future<void> write({required String key, required String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value != null) {
      _storage[key] = value;
    }
  }

  @override
  Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    return _storage[key];
  }

  @override
  Future<void> delete({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    _storage.clear();
  }

  static void clear() {
    _storage.clear();
  }
}

void main() {
  group('VotingCryptoService', () {
    late Election testElection;
    late Candidate testCandidate;
    late AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> authorityKeyPair;
    late String authorityPublicKeyPem;

    setUpAll(() async {
      // Generate authority key pair for testing
      authorityKeyPair = await BlindSignatureService.generateKeyPair();
      authorityPublicKeyPem = BlindSignatureService.publicKeyToPem(authorityKeyPair.publicKey);

      testCandidate = Candidate(
        id: 1,
        name: 'Test Candidate',
      );

      testElection = Election(
        id: 'test-election-123',
        name: 'Test Election',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        status: 'in-progress',
        rsaPubKey: authorityPublicKeyPem,
        candidates: [testCandidate],
      );
    });

    setUp(() {
      // Clear mock storage before each test
      MockSecureStorage.clear();
    });

    group('Voting Session Management', () {
      test('should start a voting session successfully', () async {
        // Mock the secure storage and NostrKeyManager
        // Note: This test requires proper mocking of NostrKeyManager.getDerivedKeys()
        // For now, we'll test the structure without the actual Nostr dependency
        
        // Create a mock voting session manually to test the structure
        final voter = Voter.generate();
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final blindingResult = BlindSignatureService.blindMessage(
          votingToken.serializedData,
          authorityKeyPair.publicKey,
        );
        
        final session = VotingSession(
          election: testElection,
          candidate: testCandidate,
          voter: voter,
          voterNpub: 'test-npub-123456789',
          votingToken: votingToken,
          blindingResult: blindingResult,
          authorityPublicKey: authorityKeyPair.publicKey,
          sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
          createdAt: DateTime.now(),
        );
        
        expect(session.election.id, equals(testElection.id));
        expect(session.candidate.id, equals(testCandidate.id));
        expect(session.voter, isA<Voter>());
        expect(session.votingToken, isA<VotingToken>());
        expect(session.blindingResult, isA<BlindingResult>());
        expect(session.authorityPublicKey, isA<RSAPublicKey>());
      });

      test('should serialize and deserialize voting session', () async {
        final voter = Voter.generate();
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final blindingResult = BlindSignatureService.blindMessage(
          votingToken.serializedData,
          authorityKeyPair.publicKey,
        );
        
        final originalSession = VotingSession(
          election: testElection,
          candidate: testCandidate,
          voter: voter,
          voterNpub: 'test-npub-123456789',
          votingToken: votingToken,
          blindingResult: blindingResult,
          authorityPublicKey: authorityKeyPair.publicKey,
          sessionId: 'test-session-123',
          createdAt: DateTime.now(),
        );
        
        final json = originalSession.toJson();
        final deserializedSession = VotingSession.fromJson(json);
        
        expect(deserializedSession.election.id, equals(originalSession.election.id));
        expect(deserializedSession.candidate.id, equals(originalSession.candidate.id));
        expect(deserializedSession.voter.nonceHex, equals(originalSession.voter.nonceHex));
        expect(deserializedSession.voterNpub, equals(originalSession.voterNpub));
        expect(deserializedSession.sessionId, equals(originalSession.sessionId));
        expect(deserializedSession.authorityPublicKey.modulus, equals(originalSession.authorityPublicKey.modulus));
      });

      test('should clear voting session', () async {
        await VotingCryptoService.clearVotingSession();
        final session = await VotingCryptoService.getCurrentVotingSession();
        expect(session, isNull);
      });
    });

    group('Blind Signature Processing', () {
      test('should process blind signature correctly', () async {
        final voter = Voter.generate();
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final blindingResult = BlindSignatureService.blindMessage(
          votingToken.serializedData,
          authorityKeyPair.publicKey,
        );
        
        final session = VotingSession(
          election: testElection,
          candidate: testCandidate,
          voter: voter,
          voterNpub: 'test-npub-123456789',
          votingToken: votingToken,
          blindingResult: blindingResult,
          authorityPublicKey: authorityKeyPair.publicKey,
          sessionId: 'test-session-123',
          createdAt: DateTime.now(),
        );
        
        // Simulate authority signing the blinded message
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          authorityKeyPair.privateKey,
        );
        
        // Process the blind signature
        final voteSignature = await VotingCryptoService.processBlindSignature(
          session: session,
          blindedSignature: blindedSignature,
        );
        
        expect(voteSignature, isA<VoteSignature>());
        expect(voteSignature.signature, isA<Uint8List>());
        expect(voteSignature.votingToken, equals(session.votingToken));
        expect(voteSignature.sessionId, equals(session.sessionId));
      });

      test('should reject invalid blind signature', () async {
        final voter = Voter.generate();
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final blindingResult = BlindSignatureService.blindMessage(
          votingToken.serializedData,
          authorityKeyPair.publicKey,
        );
        
        final session = VotingSession(
          election: testElection,
          candidate: testCandidate,
          voter: voter,
          voterNpub: 'test-npub-123456789',
          votingToken: votingToken,
          blindingResult: blindingResult,
          authorityPublicKey: authorityKeyPair.publicKey,
          sessionId: 'test-session-123',
          createdAt: DateTime.now(),
        );
        
        // Create an invalid signature
        final invalidSignature = Uint8List.fromList(List.generate(256, (i) => i % 256));
        
        expect(
          () => VotingCryptoService.processBlindSignature(
            session: session,
            blindedSignature: invalidSignature,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Castable Vote Preparation', () {
      test('should prepare castable vote correctly', () async {
        final voter = Voter.generate();
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final blindingResult = BlindSignatureService.blindMessage(
          votingToken.serializedData,
          authorityKeyPair.publicKey,
        );
        
        final session = VotingSession(
          election: testElection,
          candidate: testCandidate,
          voter: voter,
          voterNpub: 'test-npub-123456789',
          votingToken: votingToken,
          blindingResult: blindingResult,
          authorityPublicKey: authorityKeyPair.publicKey,
          sessionId: 'test-session-123',
          createdAt: DateTime.now(),
        );
        
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          authorityKeyPair.privateKey,
        );
        
        final voteSignature = await VotingCryptoService.processBlindSignature(
          session: session,
          blindedSignature: blindedSignature,
        );
        
        final castableVote = await VotingCryptoService.prepareCastableVote(
          session: session,
          voteSignature: voteSignature,
        );
        
        expect(castableVote, isA<CastableVote>());
        expect(castableVote.electionId, equals(testElection.id));
        expect(castableVote.candidateId, equals(testCandidate.id));
        expect(castableVote.voterNpub, equals(session.voterNpub));
        expect(castableVote.voterNonce, equals(session.voter.nonceHex));
        expect(castableVote.signature, isA<Uint8List>());
      });
    });

    group('Vote Verification', () {
      test('should verify valid cast vote', () async {
        final voter = Voter.generate();
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final blindingResult = BlindSignatureService.blindMessage(
          votingToken.serializedData,
          authorityKeyPair.publicKey,
        );
        
        final session = VotingSession(
          election: testElection,
          candidate: testCandidate,
          voter: voter,
          voterNpub: 'test-npub-123456789',
          votingToken: votingToken,
          blindingResult: blindingResult,
          authorityPublicKey: authorityKeyPair.publicKey,
          sessionId: 'test-session-123',
          createdAt: DateTime.now(),
        );
        
        final blindedSignature = BlindSignatureService.signBlindedMessage(
          blindingResult.blindedMessage,
          authorityKeyPair.privateKey,
        );
        
        final voteSignature = await VotingCryptoService.processBlindSignature(
          session: session,
          blindedSignature: blindedSignature,
        );
        
        final castableVote = await VotingCryptoService.prepareCastableVote(
          session: session,
          voteSignature: voteSignature,
        );
        
        final isValid = await VotingCryptoService.verifyCastVote(
          vote: castableVote,
          authorityPublicKey: authorityKeyPair.publicKey,
        );
        
        expect(isValid, isTrue);
      });

      test('should reject invalid cast vote', () async {
        final voter = Voter.generate();
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final invalidVote = CastableVote(
          voteData: votingToken.voteData,
          signature: Uint8List.fromList(List.generate(256, (i) => i % 256)),
          voterNpub: 'test-npub-123456789',
          voterNonce: voter.nonceHex,
          electionId: testElection.id,
          candidateId: testCandidate.id,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        
        final isValid = await VotingCryptoService.verifyCastVote(
          vote: invalidVote,
          authorityPublicKey: authorityKeyPair.publicKey,
        );
        
        expect(isValid, isFalse);
      });
    });

    group('Utility Methods', () {
      test('should format blinded message for transmission', () {
        final voter = Voter.generate();
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final blindingResult = BlindSignatureService.blindMessage(
          votingToken.serializedData,
          authorityKeyPair.publicKey,
        );
        
        final session = VotingSession(
          election: testElection,
          candidate: testCandidate,
          voter: voter,
          voterNpub: 'test-npub-123456789',
          votingToken: votingToken,
          blindingResult: blindingResult,
          authorityPublicKey: authorityKeyPair.publicKey,
          sessionId: 'test-session-123',
          createdAt: DateTime.now(),
        );
        
        final transmissionFormat = VotingCryptoService.getBlindedMessageForTransmission(session);
        
        expect(transmissionFormat, isA<String>());
        expect(transmissionFormat.length, greaterThan(0));
        
        // Should be valid base64
        expect(() => base64.decode(transmissionFormat), returnsNormally);
      });

      test('should parse blind signature response', () {
        final testSignature = Uint8List.fromList([1, 2, 3, 4, 5]);
        final base64Signature = base64.encode(testSignature);
        
        final parsedSignature = VotingCryptoService.parseBlindSignatureResponse(base64Signature);
        
        expect(parsedSignature, equals(testSignature));
      });
    });

    group('Serialization Tests', () {
      test('should serialize and deserialize VoteSignature', () {
        final testSignature = Uint8List.fromList([1, 2, 3, 4, 5]);
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final original = VoteSignature(
          signature: testSignature,
          votingToken: votingToken,
          sessionId: 'test-session-123',
          verifiedAt: DateTime.now(),
        );
        
        final json = original.toJson();
        final deserialized = VoteSignature.fromJson(json);
        
        expect(deserialized.signature, equals(original.signature));
        expect(deserialized.sessionId, equals(original.sessionId));
        expect(deserialized.votingToken.voteData.electionId, equals(original.votingToken.voteData.electionId));
      });

      test('should serialize and deserialize CastableVote', () {
        final testSignature = Uint8List.fromList([1, 2, 3, 4, 5]);
        final votingToken = BlindSignatureService.createVotingToken(
          electionId: testElection.id,
          candidateId: testCandidate.id,
          voterId: 'test-npub-123456789',
        );
        
        final original = CastableVote(
          voteData: votingToken.voteData,
          signature: testSignature,
          voterNpub: 'test-npub-123456789',
          voterNonce: 'test-nonce-hex',
          electionId: testElection.id,
          candidateId: testCandidate.id,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        
        final json = original.toJson();
        final deserialized = CastableVote.fromJson(json);
        
        expect(deserialized.signature, equals(original.signature));
        expect(deserialized.voterNpub, equals(original.voterNpub));
        expect(deserialized.voterNonce, equals(original.voterNonce));
        expect(deserialized.electionId, equals(original.electionId));
        expect(deserialized.candidateId, equals(original.candidateId));
      });
    });
  });
}