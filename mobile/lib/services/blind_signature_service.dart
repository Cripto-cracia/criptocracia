import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'package:basic_utils/basic_utils.dart';

/// RSA Blind Signature Service implementing David Chaum's blind signature scheme
/// Used for anonymous voting where the election authority can sign votes
/// without seeing the actual vote content
/// 
/// Performance optimizations:
/// - Cached key conversions between PointyCastle and basic_utils
/// - Optimized BigInt to bytes conversions
/// - Cached SecureRandom with periodic re-seeding
/// - Efficient DER encoding/decoding
class BlindSignatureService {
  static const int _keySize = 2048; // RSA key size in bits
  static const int _publicExponent = 65537; // Standard RSA public exponent
  
  // Performance optimization: Cache for key conversions and computed values
  static final Map<String, RSAPublicKey> _basicUtilsKeyCache = {};
  static final Map<String, RSAPublicKey> _pointyCastleKeyCache = {};
  static final Map<String, int> _modulusBitLengthCache = {};
  static SecureRandom? _cachedSecureRandom;
  static DateTime? _lastRandomSeed;
  
  // Cache size limits to prevent memory leaks
  static const int _maxCacheSize = 100;

  /// Generate RSA key pair for blind signature operations asynchronously
  /// Runs in a separate isolate to prevent blocking the UI thread
  static Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>> generateKeyPair() {
    return compute(_generatePair, null);
  }

  /// Helper method for RSA key generation that runs in an isolate
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generatePair(void _) {
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

  /// Efficiently convert PointyCastle RSA public key to basic_utils format with caching
  static RSAPublicKey _toBasicUtilsKey(RSAPublicKey pointyCastleKey) {
    final cacheKey = '${pointyCastleKey.modulus}:${pointyCastleKey.exponent}';
    
    // Implement cache size limit
    if (_basicUtilsKeyCache.length >= _maxCacheSize) {
      _basicUtilsKeyCache.clear();
    }
    
    return _basicUtilsKeyCache.putIfAbsent(cacheKey, () {
      return RSAPublicKey(
        pointyCastleKey.modulus!,
        pointyCastleKey.exponent!,
      );
    });
  }
  
  /// Efficiently convert basic_utils RSA public key to PointyCastle format with caching
  static RSAPublicKey _fromBasicUtilsKey(RSAPublicKey basicUtilsKey) {
    final cacheKey = '${basicUtilsKey.modulus}:${basicUtilsKey.exponent}';
    
    // Implement cache size limit
    if (_pointyCastleKeyCache.length >= _maxCacheSize) {
      _pointyCastleKeyCache.clear();
    }
    
    return _pointyCastleKeyCache.putIfAbsent(cacheKey, () {
      return RSAPublicKey(
        basicUtilsKey.modulus!,
        basicUtilsKey.exponent!,
      );
    });
  }

  /// Convert RSA public key to proper PKCS#1 PEM format
  static String publicKeyToPem(RSAPublicKey publicKey) {
    try {
      final basicUtilsKey = _toBasicUtilsKey(publicKey);
      return CryptoUtils.encodeRSAPublicKeyToPemPkcs1(basicUtilsKey);
    } catch (e) {
      _logError('Error encoding RSA public key to PEM', e);
      throw FormatException('Failed to encode RSA public key: $e');
    }
  }

  /// Parse RSA public key from proper PKCS#1 PEM format
  static RSAPublicKey publicKeyFromPem(String pemKey) {
    try {
      final basicUtilsKey = CryptoUtils.rsaPublicKeyFromPemPkcs1(pemKey);
      return _fromBasicUtilsKey(basicUtilsKey);
    } catch (e) {
      _logError('Error parsing RSA public key from PEM', e);
      throw FormatException('Failed to parse RSA public key: $e');
    }
  }

  /// Convert RSA public key to DER format bytes (optimized)
  static Uint8List publicKeyToDer(RSAPublicKey publicKey) {
    try {
      final basicUtilsKey = _toBasicUtilsKey(publicKey);
      
      // Extract DER from PEM (optimized implementation)
      final pemKey = CryptoUtils.encodeRSAPublicKeyToPemPkcs1(basicUtilsKey);
      return _extractDerFromPem(pemKey);
    } catch (e) {
      _logError('Error encoding RSA public key to DER', e);
      throw FormatException('Failed to encode RSA public key to DER: $e');
    }
  }

  /// Parse RSA public key from DER format bytes (optimized)
  static RSAPublicKey publicKeyFromDer(Uint8List derBytes) {
    try {
      // Convert DER to PEM then decode (reliable approach)
      final pemKey = _constructPemFromDer(derBytes);
      final basicUtilsKey = CryptoUtils.rsaPublicKeyFromPemPkcs1(pemKey);
      return _fromBasicUtilsKey(basicUtilsKey);
    } catch (e) {
      _logError('Error parsing RSA public key from DER', e);
      throw FormatException('Failed to parse RSA public key from DER: $e');
    }
  }

  /// Efficiently extract DER bytes from PEM format
  static Uint8List _extractDerFromPem(String pemKey) {
    final lines = pemKey.split('\n');
    final base64Lines = lines.where((line) => 
        !line.startsWith('-----') && line.trim().isNotEmpty);
    final base64Content = base64Lines.join('');
    return base64Decode(base64Content);
  }

  /// Efficiently construct PEM from DER bytes
  static String _constructPemFromDer(Uint8List derBytes) {
    final base64Content = base64Encode(derBytes);
    final buffer = StringBuffer();
    buffer.writeln('-----BEGIN RSA PUBLIC KEY-----');
    
    // Split base64 content into 64-character lines for proper PEM format
    for (int i = 0; i < base64Content.length; i += 64) {
      final end = (i + 64 < base64Content.length) ? i + 64 : base64Content.length;
      buffer.writeln(base64Content.substring(i, end));
    }
    
    buffer.write('-----END RSA PUBLIC KEY-----');
    return buffer.toString();
  }

  /// Blind a message for signing (voter side) - optimized version
  /// Returns BlindingResult containing blinded message and blinding factor
  static BlindingResult blindMessage(Uint8List message, RSAPublicKey publicKey) {
    _validateInput(message, 'message');
    _validatePublicKey(publicKey);
    
    final hashedMessage = _hashMessage(message);
    final messageInt = _bytesToBigInt(hashedMessage);
    final modulus = publicKey.modulus!;
    final exponent = publicKey.exponent!;
    
    // Generate random blinding factor (optimized)
    final random = _getSecureRandom();
    final blindingFactor = _generateBlindingFactor(modulus, random);
    
    // Pre-compute r^e mod n for efficiency
    final blindingFactorPowE = blindingFactor.modPow(exponent, modulus);
    
    // Blind the message: m' = m * r^e mod n
    final blindedMessage = (messageInt * blindingFactorPowE) % modulus;
    
    _logInfo('Message blinded successfully', {
      'blindedMessageBits': blindedMessage.bitLength,
      'modulusBits': modulus.bitLength,
    });
    
    return BlindingResult(
      blindedMessage: _bigIntToBytes(blindedMessage),
      blindingFactor: _bigIntToBytes(blindingFactor),
      originalMessageHash: hashedMessage,
    );
  }

  /// Sign a blinded message (election authority side) - optimized version
  /// The authority signs without seeing the actual message content
  static Uint8List signBlindedMessage(Uint8List blindedMessage, RSAPrivateKey privateKey) {
    _validateInput(blindedMessage, 'blindedMessage');
    _validatePrivateKey(privateKey);
    
    final blindedMessageInt = _bytesToBigInt(blindedMessage);
    final privateExponent = privateKey.privateExponent!;
    final modulus = privateKey.modulus!;
    
    // Sign the blinded message: s' = (m')^d mod n
    final blindedSignature = blindedMessageInt.modPow(privateExponent, modulus);
    
    _logInfo('Blinded message signed by authority', {
      'signatureBits': blindedSignature.bitLength,
      'modulusBits': modulus.bitLength,
    });
    
    return _bigIntToBytes(blindedSignature);
  }

  /// Unblind a signature (voter side) - optimized version
  /// Removes the blinding factor to get the actual signature
  static Uint8List unblindSignature(
    Uint8List blindedSignature,
    Uint8List blindingFactor,
    RSAPublicKey publicKey,
  ) {
    _validateInput(blindedSignature, 'blindedSignature');
    _validateInput(blindingFactor, 'blindingFactor');
    _validatePublicKey(publicKey);
    
    final blindedSignatureInt = _bytesToBigInt(blindedSignature);
    final blindingFactorInt = _bytesToBigInt(blindingFactor);
    final modulus = publicKey.modulus!;
    
    // Unblind the signature: s = s' * r^(-1) mod n
    final blindingFactorInverse = blindingFactorInt.modInverse(modulus);
    final unblindedSignature = (blindedSignatureInt * blindingFactorInverse) % modulus;
    
    _logInfo('Signature unblinded successfully', {
      'signatureBits': unblindedSignature.bitLength,
      'modulusBits': modulus.bitLength,
    });
    
    return _bigIntToBytes(unblindedSignature);
  }

  /// Verify an unblinded signature (anyone can verify) - optimized version
  /// Verifies that the signature is valid for the original message
  static bool verifySignature(
    Uint8List message,
    Uint8List signature,
    RSAPublicKey publicKey,
  ) {
    try {
      _validateInput(message, 'message');
      _validateInput(signature, 'signature');
      _validatePublicKey(publicKey);
      
      final hashedMessage = _hashMessage(message);
      final hashedMessageInt = _bytesToBigInt(hashedMessage);
      final signatureInt = _bytesToBigInt(signature);
      final exponent = publicKey.exponent!;
      final modulus = publicKey.modulus!;
      
      // Verify signature: m = s^e mod n
      final verifiedMessage = signatureInt.modPow(exponent, modulus);
      
      final isValid = verifiedMessage == hashedMessageInt;
      
      _logInfo('Signature verification completed', {
        'isValid': isValid,
        'signatureBits': signatureInt.bitLength,
        'modulusBits': modulus.bitLength,
      });
      
      return isValid;
    } catch (e) {
      _logError('Signature verification failed', e);
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

  /// Convert BigInt to byte array (optimized)
  static Uint8List _bigIntToBytes(BigInt bigInt) {
    if (bigInt == BigInt.zero) return Uint8List.fromList([0]);
    
    // Calculate the required byte length more efficiently
    final bitLength = bigInt.bitLength;
    final byteLength = (bitLength + 7) >> 3; // Equivalent to (bitLength + 7) ~/ 8
    final bytes = Uint8List(byteLength);
    
    var temp = bigInt;
    for (int i = byteLength - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp = temp >> 8;
    }
    
    return bytes;
  }

  /// Convert byte array to BigInt (optimized)
  static BigInt _bytesToBigInt(Uint8List bytes) {
    if (bytes.isEmpty) return BigInt.zero;
    
    BigInt result = BigInt.zero;
    final length = bytes.length;
    
    // Optimize for common case of single byte
    if (length == 1) {
      return BigInt.from(bytes[0]);
    }
    
    // Use bit shifting instead of multiplication for better performance
    for (int i = 0; i < length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    
    return result;
  }

  /// Get a secure random number generator with caching and periodic re-seeding
  static SecureRandom _getSecureRandom() {
    final now = DateTime.now();
    
    // Re-seed every 10 minutes or if cache is empty
    if (_cachedSecureRandom == null || 
        _lastRandomSeed == null || 
        now.difference(_lastRandomSeed!).inMinutes >= 10) {
      
      _cachedSecureRandom = SecureRandom('Fortuna');
      final seedSource = Random.secure();
      final seeds = List.generate(32, (i) => seedSource.nextInt(256));
      _cachedSecureRandom!.seed(KeyParameter(Uint8List.fromList(seeds)));
      _lastRandomSeed = now;
      
      _logInfo('SecureRandom re-seeded', {'timestamp': now.toIso8601String()});
    }
    
    return _cachedSecureRandom!;
  }

  // Validation helper methods
  static void _validateInput(Uint8List? data, String paramName) {
    if (data == null || data.isEmpty) {
      throw ArgumentError('$paramName cannot be null or empty');
    }
  }

  static void _validatePublicKey(RSAPublicKey? publicKey) {
    if (publicKey == null) {
      throw ArgumentError('publicKey cannot be null');
    }
    if (publicKey.modulus == null || publicKey.exponent == null) {
      throw ArgumentError('publicKey modulus and exponent cannot be null');
    }
    
    // Cache bit length calculation for performance
    final modulusStr = publicKey.modulus.toString();
    final bitLength = _modulusBitLengthCache.putIfAbsent(modulusStr, () {
      return publicKey.modulus!.bitLength;
    });
    
    if (bitLength < 2048) {
      throw ArgumentError('RSA key must be at least 2048 bits for security');
    }
  }

  static void _validatePrivateKey(RSAPrivateKey? privateKey) {
    if (privateKey == null) {
      throw ArgumentError('privateKey cannot be null');
    }
    if (privateKey.modulus == null || privateKey.privateExponent == null) {
      throw ArgumentError('privateKey modulus and exponent cannot be null');
    }
    
    // Cache bit length calculation for performance
    final modulusStr = privateKey.modulus.toString();
    final bitLength = _modulusBitLengthCache.putIfAbsent(modulusStr, () {
      return privateKey.modulus!.bitLength;
    });
    
    if (bitLength < 2048) {
      throw ArgumentError('RSA key must be at least 2048 bits for security');
    }
  }

  /// Clear all caches to free memory
  static void clearCaches() {
    _basicUtilsKeyCache.clear();
    _pointyCastleKeyCache.clear();
    _modulusBitLengthCache.clear();
    _cachedSecureRandom = null;
    _lastRandomSeed = null;
  }
  
  /// Get cache statistics for monitoring
  static Map<String, int> getCacheStats() {
    return {
      'basicUtilsKeyCache': _basicUtilsKeyCache.length,
      'pointyCastleKeyCache': _pointyCastleKeyCache.length,
      'modulusBitLengthCache': _modulusBitLengthCache.length,
    };
  }

  // Logging helper methods with production-friendly levels
  static void _logInfo(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      final logData = data?.entries.map((e) => '${e.key}=${e.value}').join(', ') ?? '';
      debugPrint('ℹ️ BlindSignature: $message${logData.isNotEmpty ? ' ($logData)' : ''}');
    }
  }

  static void _logError(String message, dynamic error) {
    if (kDebugMode) {
      debugPrint('❌ BlindSignature: $message: $error');
    }
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