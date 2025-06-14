import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import '../models/election.dart';
import '../models/voter.dart';
import 'blind_signature_service.dart';
import 'nostr_key_manager.dart';

/// High-level service for managing the cryptographic voting workflow
/// Handles the complete process: nonce generation → blinding → signing → unblinding → vote casting
class VotingCryptoService {
  // Secure storage instance for sensitive voting session data
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // Storage keys for voting session data
  static const String _currentVoteSessionKey = 'current_vote_session';

  /// Generate a voter nonce and create a voting session
  static Future<VotingSession> startVotingSession({
    required Election election,
    required Candidate candidate,
  }) async {
    debugPrint('🚀 Starting voting session for: ${candidate.name} in ${election.name}');

    // Generate voter nonce
    final voter = Voter.generate();
    debugPrint('🎲 Generated voter nonce: ${voter.nonceHex}');

    // Get voter's Nostr identity
    final keys = await NostrKeyManager.getDerivedKeys();
    final voterNpub = keys['npub'] as String;

    // Create voting token
    final votingToken = BlindSignatureService.createVotingToken(
      electionId: election.id,
      candidateId: candidate.id,
      voterId: voterNpub, // Use npub as voter identifier
    );

    // Parse election authority's RSA public key
    final authorityPublicKey = BlindSignatureService.publicKeyFromPem(election.rsaPubKey);

    // Blind the voting token
    final blindingResult = BlindSignatureService.blindMessage(
      votingToken.serializedData,
      authorityPublicKey,
    );

    // Create voting session
    final session = VotingSession(
      election: election,
      candidate: candidate,
      voter: voter,
      voterNpub: voterNpub,
      votingToken: votingToken,
      blindingResult: blindingResult,
      authorityPublicKey: authorityPublicKey,
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
    );

    // Store session data for recovery
    await _storeVotingSession(session);

    debugPrint('✅ Voting session created with ID: ${session.sessionId}');
    return session;
  }

  /// Get the current active voting session
  static Future<VotingSession?> getCurrentVotingSession() async {
    try {
      final sessionJson = await _secureStorage.read(key: _currentVoteSessionKey);
      
      if (sessionJson == null) return null;
      
      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
      return VotingSession.fromJson(sessionData);
    } catch (e) {
      debugPrint('❌ Error loading voting session: $e');
      return null;
    }
  }

  /// Process the blind signature received from the election authority
  static Future<VoteSignature> processBlindSignature({
    required VotingSession session,
    required Uint8List blindedSignature,
  }) async {
    debugPrint('🔓 Processing blind signature from election authority');

    // Unblind the signature
    final unblindedSignature = BlindSignatureService.unblindSignature(
      blindedSignature,
      session.blindingResult.blindingFactor,
      session.authorityPublicKey,
    );

    // Verify the signature is valid
    final isValid = BlindSignatureService.verifySignature(
      session.votingToken.serializedData,
      unblindedSignature,
      session.authorityPublicKey,
    );

    if (!isValid) {
      throw Exception('Invalid signature received from election authority');
    }

    final voteSignature = VoteSignature(
      signature: unblindedSignature,
      votingToken: session.votingToken,
      sessionId: session.sessionId,
      verifiedAt: DateTime.now(),
    );

    debugPrint('✅ Signature verified and unblinded successfully');
    return voteSignature;
  }

  /// Prepare the final vote for casting
  static Future<CastableVote> prepareCastableVote({
    required VotingSession session,
    required VoteSignature voteSignature,
  }) async {
    debugPrint('📤 Preparing vote for casting');

    // Create the complete vote package
    final castableVote = CastableVote(
      voteData: voteSignature.votingToken.voteData,
      signature: voteSignature.signature,
      voterNpub: session.voterNpub,
      voterNonce: session.voter.nonceHex,
      electionId: session.election.id,
      candidateId: session.candidate.id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    debugPrint('✅ Vote prepared for casting');
    debugPrint('📊 Vote details: Election=${castableVote.electionId}, Candidate=${castableVote.candidateId}');

    return castableVote;
  }

  /// Verify a cast vote (for public verification)
  static Future<bool> verifyCastVote({
    required CastableVote vote,
    required RSAPublicKey authorityPublicKey,
  }) async {
    try {
      // Reconstruct the vote data
      final voteData = VoteData(
        electionId: vote.electionId,
        candidateId: vote.candidateId,
        voterId: vote.voterNpub,
        timestamp: vote.voteData.timestamp, // Use original timestamp
      );

      // Verify the signature
      final isValid = BlindSignatureService.verifySignature(
        voteData.serialize(),
        vote.signature,
        authorityPublicKey,
      );

      debugPrint('🔍 Vote verification result: ${isValid ? 'VALID' : 'INVALID'}');
      return isValid;
    } catch (e) {
      debugPrint('❌ Vote verification failed: $e');
      return false;
    }
  }

  /// Clear the current voting session
  static Future<void> clearVotingSession() async {
    await _secureStorage.delete(key: _currentVoteSessionKey);
    debugPrint('🗑️ Voting session cleared from secure storage');
  }

  /// Store voting session data securely
  static Future<void> _storeVotingSession(VotingSession session) async {
    final sessionJson = jsonEncode(session.toJson());
    await _secureStorage.write(key: _currentVoteSessionKey, value: sessionJson);
    debugPrint('🔒 Voting session stored securely');
  }

  /// Get blinded message for transmission to election authority
  static String getBlindedMessageForTransmission(VotingSession session) {
    return base64.encode(session.blindingResult.blindedMessage);
  }

  /// Parse blind signature response from election authority
  static Uint8List parseBlindSignatureResponse(String base64Signature) {
    return base64.decode(base64Signature);
  }
}

/// Complete voting session containing all necessary data
class VotingSession {
  final Election election;
  final Candidate candidate;
  final Voter voter;
  final String voterNpub;
  final VotingToken votingToken;
  final BlindingResult blindingResult;
  final RSAPublicKey authorityPublicKey;
  final String sessionId;
  final DateTime createdAt;

  VotingSession({
    required this.election,
    required this.candidate,
    required this.voter,
    required this.voterNpub,
    required this.votingToken,
    required this.blindingResult,
    required this.authorityPublicKey,
    required this.sessionId,
    required this.createdAt,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'election': election.toJson(),
      'candidate': candidate.toJson(),
      'voter': voter.toJson(),
      'voter_npub': voterNpub,
      'voting_token': votingToken.toJson(),
      'blinding_result': blindingResult.toJson(),
      'authority_public_key': BlindSignatureService.publicKeyToPem(authorityPublicKey),
      'session_id': sessionId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON
  factory VotingSession.fromJson(Map<String, dynamic> json) {
    return VotingSession(
      election: Election.fromJson(json['election']),
      candidate: Candidate.fromJson(json['candidate']),
      voter: Voter.fromJson(json['voter']),
      voterNpub: json['voter_npub'],
      votingToken: VotingToken.fromJson(json['voting_token']),
      blindingResult: BlindingResult.fromJson(json['blinding_result']),
      authorityPublicKey: BlindSignatureService.publicKeyFromPem(json['authority_public_key']),
      sessionId: json['session_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
    );
  }
}

/// Vote signature after unblinding
class VoteSignature {
  final Uint8List signature;
  final VotingToken votingToken;
  final String sessionId;
  final DateTime verifiedAt;

  VoteSignature({
    required this.signature,
    required this.votingToken,
    required this.sessionId,
    required this.verifiedAt,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'signature': base64.encode(signature),
      'voting_token': votingToken.toJson(),
      'session_id': sessionId,
      'verified_at': verifiedAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON
  factory VoteSignature.fromJson(Map<String, dynamic> json) {
    return VoteSignature(
      signature: base64.decode(json['signature']),
      votingToken: VotingToken.fromJson(json['voting_token']),
      sessionId: json['session_id'],
      verifiedAt: DateTime.fromMillisecondsSinceEpoch(json['verified_at']),
    );
  }
}

/// Final vote ready for casting
class CastableVote {
  final VoteData voteData;
  final Uint8List signature;
  final String voterNpub;
  final String voterNonce;
  final String electionId;
  final int candidateId;
  final int timestamp;

  CastableVote({
    required this.voteData,
    required this.signature,
    required this.voterNpub,
    required this.voterNonce,
    required this.electionId,
    required this.candidateId,
    required this.timestamp,
  });

  /// Convert to JSON for Nostr transmission
  Map<String, dynamic> toJson() {
    return {
      'vote_data': voteData.toJson(),
      'signature': base64.encode(signature),
      'voter_npub': voterNpub,
      'voter_nonce': voterNonce,
      'election_id': electionId,
      'candidate_id': candidateId,
      'timestamp': timestamp,
    };
  }

  /// Create from JSON
  factory CastableVote.fromJson(Map<String, dynamic> json) {
    return CastableVote(
      voteData: VoteData.fromJson(json['vote_data']),
      signature: base64.decode(json['signature']),
      voterNpub: json['voter_npub'],
      voterNonce: json['voter_nonce'],
      electionId: json['election_id'],
      candidateId: json['candidate_id'],
      timestamp: json['timestamp'],
    );
  }
}