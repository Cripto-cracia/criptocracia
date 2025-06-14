import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class Voter {
  late Uint8List _nonce;
  late Uint8List _hashedNonce;
  
  Voter() {
    generateNonce();
  }

  /// Create a new voter with generated nonce
  Voter.generate() {
    generateNonce();
  }

  /// Create a voter from existing nonce data
  Voter.fromNonce(this._nonce) {
    _hashedNonce = Uint8List.fromList(sha256.convert(_nonce).bytes);
  }

  /// Internal constructor for direct field assignment
  Voter._internal();
  
  void generateNonce() {
    final random = Random.secure();
    _nonce = Uint8List(32); // 256-bit nonce
    
    for (int i = 0; i < _nonce.length; i++) {
      _nonce[i] = random.nextInt(256);
    }
    
    _hashedNonce = Uint8List.fromList(sha256.convert(_nonce).bytes);
  }
  
  Uint8List get nonce => _nonce;
  Uint8List get hashedNonce => _hashedNonce;
  
  String get nonceHex => _nonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  String get hashedNonceHex => _hashedNonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'nonce': base64Encode(_nonce),
      'hashed_nonce': base64Encode(_hashedNonce),
    };
  }

  /// Create from JSON with hash validation
  factory Voter.fromJson(Map<String, dynamic> json) {
    final nonce = base64Decode(json['nonce']);
    final storedHashedNonce = base64Decode(json['hashed_nonce']);
    
    // Compute expected hash for validation
    final computedHash = Uint8List.fromList(sha256.convert(nonce).bytes);
    
    // Validate integrity
    if (!_bytesEqual(storedHashedNonce, computedHash)) {
      throw FormatException('Hash validation failed: stored hash does not match computed hash');
    }
    
    // Create voter with validated data
    final voter = Voter._internal();
    voter._nonce = nonce;
    voter._hashedNonce = storedHashedNonce; // Reuse validated hash
    return voter;
  }

  /// Compare two Uint8List for equality
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}