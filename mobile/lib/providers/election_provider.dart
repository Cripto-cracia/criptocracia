import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/election.dart';
import '../services/nostr_service.dart';
import '../services/selected_election_service.dart';
import '../config/app_config.dart';
import 'dart:convert';
import 'dart:async';

class ElectionProvider with ChangeNotifier {
  final NostrService _nostrService = NostrService();
  StreamSubscription? _eventsSubscription;
  
  List<Election> _elections = [];
  bool _isLoading = false;
  String? _error;
  
  List<Election> get elections => _elections;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> loadElections() async {
    debugPrint('🚀 Starting election loading process...');
    
    if (!AppConfig.isConfigured) {
      _error = 'App not configured. Please provide relay URL and EC public key.';
      debugPrint('❌ App not configured');
      notifyListeners();
      return;
    }
    
    debugPrint('⚙️ App configured with relay: ${AppConfig.relayUrl}');
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      debugPrint('🔌 Connecting to Nostr service...');
      await _nostrService.connect(AppConfig.relayUrl);
      
      // Listen for election events
      debugPrint('👂 Starting to listen for election events...');
      final electionsStream = _nostrService.subscribeToElections();
      
      // Give a brief moment for the subscription to establish, then stop loading if no events
      Timer(const Duration(seconds: 1), () {
        if (_isLoading && _elections.isEmpty) {
          debugPrint('📭 No events received after subscription - showing no elections message');
          _isLoading = false;
          notifyListeners();
        }
      });
      
      // Listen to real-time events
      debugPrint('🔄 Listening for real-time election events...');
      
      // Set up stream subscription instead of await for to handle completion
      _eventsSubscription?.cancel(); // Cancel any existing subscription
      _eventsSubscription = electionsStream.listen(
        (event) {
          debugPrint('📨 Received event in provider: kind=${event.kind}, id=${event.id}');
          
          try {
            if (event.kind == 35000) {
              debugPrint('🗳️ Found kind 35000 event, parsing content...');
              final content = jsonDecode(event.content);
              debugPrint('📋 Parsed content: $content');
              
              final election = Election.fromJson(content);
              debugPrint('✅ Created election: ${election.name} (${election.id})');
              
              // Update existing election or add new one
              final existingIndex = _elections.indexWhere((e) => e.id == election.id);
              if (existingIndex != -1) {
                // Update existing election (status change, candidate updates, etc.)
                _elections = [..._elections];
                _elections[existingIndex] = election;
                debugPrint('🔄 Updated existing election: ${election.name} - Status: ${election.status}');
                
                // Update selected election if this election is currently selected
                _updateSelectedElectionIfMatches(election);
              } else {
                // Add new election to the list
                _elections = [..._elections, election];
                debugPrint('📝 Added new election to list: ${election.name} - Status: ${election.status}');
              }
              
              // Stop loading if this is the first election or if we have elections
              if (_isLoading && _elections.isNotEmpty) {
                _isLoading = false;
              }
              
              notifyListeners();
              debugPrint('📊 Total elections: ${_elections.length}');
            } else {
              debugPrint('➡️ Skipping non-election event: kind=${event.kind}');
            }
          } catch (e) {
            debugPrint('❌ Error parsing election event: $e');
            debugPrint('📄 Event content was: ${event.content}');
          }
        },
        onError: (error) {
          debugPrint('🚨 Stream error in provider: $error');
          if (_isLoading) {
            _isLoading = false;
            notifyListeners();
          }
        },
        onDone: () {
          debugPrint('📡 Nostr stream completed');
          if (_isLoading) {
            _isLoading = false;
            notifyListeners();
          }
        },
      );
      
      // Keep the subscription alive - don't await for it to complete
      
    } catch (e) {
      _error = 'Failed to load elections: $e';
      _isLoading = false;
      debugPrint('💥 Error loading elections: $e');
      notifyListeners();
      
      // Try to disconnect on error
      try {
        await _nostrService.disconnect();
      } catch (_) {}
    }
  }
  
  Future<void> refreshElections() async {
    // Cancel existing subscription and clear data
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _elections = [];
    _error = null;
    await loadElections();
  }
  
  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _nostrService.disconnect();
    super.dispose();
  }
  
  Election? getElectionById(String id) {
    try {
      return _elections.firstWhere((election) => election.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Update the selected election if the updated election matches the currently selected one
  Future<void> _updateSelectedElectionIfMatches(Election updatedElection) async {
    try {
      final isSelected = await SelectedElectionService.isElectionSelected(updatedElection.id);
      if (isSelected) {
        await SelectedElectionService.setSelectedElection(updatedElection);
        debugPrint('🔄 Updated selected election storage: ${updatedElection.name} - Status: ${updatedElection.status}');
      }
    } catch (e) {
      debugPrint('❌ Error updating selected election: $e');
    }
  }

  /// Get the currently selected election from storage
  Future<Election?> getSelectedElection() async {
    return await SelectedElectionService.getSelectedElection();
  }

  /// Check if there is a selected election
  Future<bool> hasSelectedElection() async {
    return await SelectedElectionService.hasSelectedElection();
  }

  /// Clear the selected election
  Future<void> clearSelectedElection() async {
    await SelectedElectionService.clearSelectedElection();
    debugPrint('🗑️ Cleared selected election from storage');
  }
}