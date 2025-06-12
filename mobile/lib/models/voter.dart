import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class Voter {
  late Uint8List _nonce;
  late Uint8List _hashedNonce;
  
  Voter() {
    generateNonce();
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
}