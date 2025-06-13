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
  
  void generateNonce() {
    final random = Random.secure();
    _nonce = Uint8List(16); // 128-bit nonce
    
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
      'nonce_hex': nonceHex,
      'hashed_nonce_hex': hashedNonceHex,
    };
  }

  /// Create from JSON
  factory Voter.fromJson(Map<String, dynamic> json) {
    final nonce = base64Decode(json['nonce']);
    return Voter.fromNonce(nonce);
  }
}