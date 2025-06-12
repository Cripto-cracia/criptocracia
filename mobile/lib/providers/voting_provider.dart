import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/election.dart';
import '../models/voter.dart';
import '../services/nostr_service.dart';
import '../config/app_config.dart';

enum VotingStep implements Comparable<VotingStep> {
  initial(0),
  generateNonce(1),
  sendBlindedNonce(2),
  waitForSignature(3),
  castVote(4),
  complete(5);

  const VotingStep(this.value);
  final int value;

  @override
  int compareTo(VotingStep other) => value.compareTo(other.value);

  bool operator >=(VotingStep other) => value >= other.value;
  bool operator <=(VotingStep other) => value <= other.value;
}

class VotingProvider with ChangeNotifier {
  final NostrService _nostrService = NostrService();
  late Voter _voter;
  
  Election? _election;
  Candidate? _candidate;
  VotingStep _currentStep = VotingStep.initial;
  bool _isLoading = false;
  String? _error;
  
  Uint8List? _blindedNonce;
  Uint8List? _blindSignature;
  Uint8List? _signature;
  
  Election? get election => _election;
  Candidate? get candidate => _candidate;
  VotingStep get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  void initializeVoting(Election election, Candidate candidate) {
    _election = election;
    _candidate = candidate;
    _voter = Voter();
    _currentStep = VotingStep.initial;
    _error = null;
    notifyListeners();
  }
  
  Future<void> startVoting() async {
    if (!AppConfig.isConfigured) {
      _error = 'App not configured. Please provide relay URL and EC public key.';
      notifyListeners();
      return;
    }
    
    if (_election == null || _candidate == null) {
      _error = 'Election or candidate not selected.';
      notifyListeners();
      return;
    }
    
    try {
      await _connectToNostr();
      await _generateAndBlindNonce();
      await _sendBlindedNonce();
      await _waitForBlindSignature();
      await _castVote();
      _completeVoting();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> _connectToNostr() async {
    await _nostrService.connect(AppConfig.relayUrl);
  }
  
  Future<void> _generateAndBlindNonce() async {
    _setCurrentStep(VotingStep.generateNonce, isLoading: true);
    
    // Generate fresh nonce
    _voter.generateNonce();
    
    try {
      // TODO: Implement actual RSA blinding
      // For now, we'll use the hashed nonce as a placeholder
      _blindedNonce = _voter.hashedNonce;
      
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate processing
      _setCurrentStep(VotingStep.generateNonce, isLoading: false);
    } catch (e) {
      throw Exception('Failed to generate and blind nonce: $e');
    }
  }
  
  Future<void> _sendBlindedNonce() async {
    _setCurrentStep(VotingStep.sendBlindedNonce, isLoading: true);
    
    if (_blindedNonce == null) {
      throw Exception('Blinded nonce not generated');
    }
    
    try {
      await _nostrService.sendBlindedNonce(
        AppConfig.ecPublicKey,
        _blindedNonce!,
      );
      
      _setCurrentStep(VotingStep.sendBlindedNonce, isLoading: false);
    } catch (e) {
      throw Exception('Failed to send blinded nonce: $e');
    }
  }
  
  Future<void> _waitForBlindSignature() async {
    _setCurrentStep(VotingStep.waitForSignature, isLoading: true);
    
    try {
      // Wait for blind signature with timeout
      final signature = await _nostrService.waitForBlindSignature();
      
      if (signature == null) {
        throw Exception('Timeout waiting for blind signature');
      }
      
      _blindSignature = signature;
      
      // TODO: Implement actual RSA unblinding
      // For now, we'll use the blind signature as the final signature
      _signature = _blindSignature;
      
      _setCurrentStep(VotingStep.waitForSignature, isLoading: false);
    } catch (e) {
      throw Exception('Failed to receive blind signature: $e');
    }
  }
  
  Future<void> _castVote() async {
    _setCurrentStep(VotingStep.castVote, isLoading: true);
    
    if (_signature == null || _election == null || _candidate == null) {
      throw Exception('Missing required data for vote casting');
    }
    
    try {
      await _nostrService.castVote(
        _election!.id,
        _candidate!.id,
        _signature!,
      );
      
      _setCurrentStep(VotingStep.castVote, isLoading: false);
    } catch (e) {
      throw Exception('Failed to cast vote: $e');
    }
  }
  
  void _completeVoting() {
    _currentStep = VotingStep.complete;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
  
  void _setCurrentStep(VotingStep step, {required bool isLoading}) {
    _currentStep = step;
    _isLoading = isLoading;
    _error = null;
    notifyListeners();
  }
  
  Future<void> retryCurrentStep() async {
    _error = null;
    notifyListeners();
    
    try {
      switch (_currentStep) {
        case VotingStep.generateNonce:
          await _generateAndBlindNonce();
          break;
        case VotingStep.sendBlindedNonce:
          await _sendBlindedNonce();
          break;
        case VotingStep.waitForSignature:
          await _waitForBlindSignature();
          break;
        case VotingStep.castVote:
          await _castVote();
          break;
        default:
          await startVoting();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _nostrService.disconnect();
    super.dispose();
  }
}