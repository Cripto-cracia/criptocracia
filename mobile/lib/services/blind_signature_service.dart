import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';

/// RSA Blind Signature Service implementing David Chaum's blind signature scheme
/// Used for anonymous voting where the election authority can sign votes
/// without seeing the actual vote content
class BlindSignatureService {
  static const int _keySize = 2048; // RSA key size in bits
  static const int _publicExponent = 65537; // Standard RSA public exponent

  /// Generate RSA key pair for blind signature operations
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateKeyPair() {
    final keyGen = RSAKeyGenerator();
    final secureRandom = _getSecureRandom();
    
    keyGen.init(ParametersWithRandom(
      RSAKeyGeneratorParameters(
        BigInt.from(_publicExponent),
        _keySize,
        64, // certainty for prime generation
      ),
      secureRandom,
    ));

    final keyPair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      keyPair.publicKey as RSAPublicKey,
      keyPair.privateKey as RSAPrivateKey,
    );
  }

  /// Convert RSA public key to PEM format for transmission
  static String publicKeyToPem(RSAPublicKey publicKey) {
    final modulus = _bigIntToBytes(publicKey.modulus!);
    final exponent = _bigIntToBytes(publicKey.exponent!);
    
    // Simple encoding for demonstration - in production use proper ASN.1/DER encoding
    final keyData = base64Encode([
      ...modulus,
      0xFF, // separator
      ...exponent,
    ]);
    
    return '-----BEGIN PUBLIC KEY-----\n$keyData\n-----END PUBLIC KEY-----';
  }

  /// Parse RSA public key from PEM format
  static RSAPublicKey publicKeyFromPem(String pemKey) {
    final keyData = pemKey
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .trim();
    
    final bytes = base64Decode(keyData);
    final separatorIndex = bytes.indexOf(0xFF);
    
    if (separatorIndex == -1) {
      throw FormatException('Invalid PEM key format');
    }
    
    final modulusBytes = bytes.sublist(0, separatorIndex);
    final exponentBytes = bytes.sublist(separatorIndex + 1);
    
    final modulus = _bytesToBigInt(modulusBytes);
    final exponent = _bytesToBigInt(exponentBytes);
    
    return RSAPublicKey(modulus, exponent);
  }

  /// Blind a message for signing (voter side)
  /// Returns BlindingResult containing blinded message and blinding factor
  static BlindingResult blindMessage(Uint8List message, RSAPublicKey publicKey) {
    final hashedMessage = _hashMessage(message);
    final messageInt = _bytesToBigInt(hashedMessage);
    
    // Generate random blinding factor
    final random = _getSecureRandom();
    final blindingFactor = _generateBlindingFactor(publicKey.modulus!, random);
    
    // Blind the message: m' = m * r^e mod n
    final blindedMessage = (messageInt * blindingFactor.modPow(publicKey.exponent!, publicKey.modulus!)) % publicKey.modulus!;
    
    debugPrint('🎭 Message blinded successfully');
    debugPrint('📏 Blinded message size: ${blindedMessage.bitLength} bits');
    
    return BlindingResult(
      blindedMessage: _bigIntToBytes(blindedMessage),
      blindingFactor: _bigIntToBytes(blindingFactor),
      originalMessageHash: hashedMessage,
    );
  }

  /// Sign a blinded message (election authority side)
  /// The authority signs without seeing the actual message content
  static Uint8List signBlindedMessage(Uint8List blindedMessage, RSAPrivateKey privateKey) {
    final blindedMessageInt = _bytesToBigInt(blindedMessage);
    
    // Sign the blinded message: s' = (m')^d mod n
    final blindedSignature = blindedMessageInt.modPow(privateKey.privateExponent!, privateKey.modulus!);
    
    debugPrint('✍️ Blinded message signed by authority');
    debugPrint('📏 Blinded signature size: ${blindedSignature.bitLength} bits');
    
    return _bigIntToBytes(blindedSignature);
  }

  /// Unblind a signature (voter side)
  /// Removes the blinding factor to get the actual signature
  static Uint8List unblindSignature(
    Uint8List blindedSignature,
    Uint8List blindingFactor,
    RSAPublicKey publicKey,
  ) {
    final blindedSignatureInt = _bytesToBigInt(blindedSignature);
    final blindingFactorInt = _bytesToBigInt(blindingFactor);
    
    // Unblind the signature: s = s' * r^(-1) mod n
    final blindingFactorInverse = blindingFactorInt.modInverse(publicKey.modulus!);
    final unblindedSignature = (blindedSignatureInt * blindingFactorInverse) % publicKey.modulus!;
    
    debugPrint('🎭 Signature unblinded successfully');
    debugPrint('📏 Unblinded signature size: ${unblindedSignature.bitLength} bits');
    
    return _bigIntToBytes(unblindedSignature);
  }

  /// Verify an unblinded signature (anyone can verify)
  /// Verifies that the signature is valid for the original message
  static bool verifySignature(
    Uint8List message,
    Uint8List signature,
    RSAPublicKey publicKey,
  ) {
    try {
      final hashedMessage = _hashMessage(message);
      final hashedMessageInt = _bytesToBigInt(hashedMessage);
      final signatureInt = _bytesToBigInt(signature);
      
      // Verify signature: m = s^e mod n
      final verifiedMessage = signatureInt.modPow(publicKey.exponent!, publicKey.modulus!);
      
      final isValid = verifiedMessage == hashedMessageInt;
      
      debugPrint('✅ Signature verification: ${isValid ? 'VALID' : 'INVALID'}');
      
      return isValid;
    } catch (e) {
      debugPrint('❌ Signature verification failed: $e');
      return false;
    }
  }

  /// Create a complete voting token for a candidate
  static VotingToken createVotingToken({
    required String electionId,
    required int candidateId,
    required String voterId, // Could be npub or voter nonce
  }) {
    final voteData = VoteData(
      electionId: electionId,
      candidateId: candidateId,
      voterId: voterId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    final serializedVote = voteData.serialize();
    
    return VotingToken(
      voteData: voteData,
      serializedData: serializedVote,
    );
  }

  /// Hash a message using SHA-256
  static Uint8List _hashMessage(Uint8List message) {
    final digest = sha256.convert(message);
    return Uint8List.fromList(digest.bytes);
  }

  /// Generate a random blinding factor coprime to n
  static BigInt _generateBlindingFactor(BigInt modulus, SecureRandom random) {
    BigInt blindingFactor;
    do {
      blindingFactor = _generateRandomBigInt(modulus.bitLength - 1, random);
    } while (blindingFactor.gcd(modulus) != BigInt.one || blindingFactor <= BigInt.one);
    
    return blindingFactor;
  }

  /// Generate a random BigInt of specified bit length
  static BigInt _generateRandomBigInt(int bitLength, SecureRandom random) {
    final bytes = Uint8List((bitLength + 7) ~/ 8);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextUint8();
    }
    
    // Ensure the number has the correct bit length
    if (bitLength % 8 != 0) {
      bytes[0] &= (1 << (bitLength % 8)) - 1;
    }
    
    return _bytesToBigInt(bytes);
  }

  /// Convert BigInt to byte array
  static Uint8List _bigIntToBytes(BigInt bigInt) {
    if (bigInt == BigInt.zero) return Uint8List.fromList([0]);
    
    final bytes = <int>[];
    var temp = bigInt;
    
    while (temp > BigInt.zero) {
      bytes.insert(0, (temp & BigInt.from(0xFF)).toInt());
      temp = temp >> 8;
    }
    
    return Uint8List.fromList(bytes);
  }

  /// Convert byte array to BigInt
  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }

  /// Get a secure random number generator
  static SecureRandom _getSecureRandom() {
    final secureRandom = SecureRandom('Fortuna');
    final seedSource = Random.secure();
    final seeds = List.generate(32, (i) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}

/// Result of blinding operation containing blinded message and blinding factor
class BlindingResult {
  final Uint8List blindedMessage;
  final Uint8List blindingFactor;
  final Uint8List originalMessageHash;

  BlindingResult({
    required this.blindedMessage,
    required this.blindingFactor,
    required this.originalMessageHash,
  });

  /// Convert to JSON for transmission
  Map<String, dynamic> toJson() {
    return {
      'blinded_message': base64Encode(blindedMessage),
      'blinding_factor': base64Encode(blindingFactor),
      'original_message_hash': base64Encode(originalMessageHash),
    };
  }

  /// Create from JSON
  factory BlindingResult.fromJson(Map<String, dynamic> json) {
    return BlindingResult(
      blindedMessage: base64Decode(json['blinded_message']),
      blindingFactor: base64Decode(json['blinding_factor']),
      originalMessageHash: base64Decode(json['original_message_hash']),
    );
  }
}

/// Vote data structure for serialization
class VoteData {
  final String electionId;
  final int candidateId;
  final String voterId;
  final int timestamp;

  VoteData({
    required this.electionId,
    required this.candidateId,
    required this.voterId,
    required this.timestamp,
  });

  /// Serialize vote data to bytes for signing
  Uint8List serialize() {
    final data = '$electionId:$candidateId:$voterId:$timestamp';
    return Uint8List.fromList(data.codeUnits);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'election_id': electionId,
      'candidate_id': candidateId,
      'voter_id': voterId,
      'timestamp': timestamp,
    };
  }

  /// Create from JSON
  factory VoteData.fromJson(Map<String, dynamic> json) {
    return VoteData(
      electionId: json['election_id'],
      candidateId: json['candidate_id'],
      voterId: json['voter_id'],
      timestamp: json['timestamp'],
    );
  }
}

/// Complete voting token with vote data and serialized form
class VotingToken {
  final VoteData voteData;
  final Uint8List serializedData;

  VotingToken({
    required this.voteData,
    required this.serializedData,
  });

  /// Convert to JSON for transmission
  Map<String, dynamic> toJson() {
    return {
      'vote_data': voteData.toJson(),
      'serialized_data': base64Encode(serializedData),
    };
  }

  /// Create from JSON
  factory VotingToken.fromJson(Map<String, dynamic> json) {
    return VotingToken(
      voteData: VoteData.fromJson(json['vote_data']),
      serializedData: base64Decode(json['serialized_data']),
    );
  }
}