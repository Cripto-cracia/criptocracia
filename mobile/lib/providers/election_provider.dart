import 'package:flutter/material.dart';
import '../models/election.dart';
import '../services/nostr_service.dart';
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
    print('🚀 Starting election loading process...');
    
    if (!AppConfig.isConfigured) {
      _error = 'App not configured. Please provide relay URL and EC public key.';
      print('❌ App not configured');
      notifyListeners();
      return;
    }
    
    print('⚙️ App configured with relay: ${AppConfig.relayUrl}');
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('🔌 Connecting to Nostr service...');
      await _nostrService.connect(AppConfig.relayUrl);
      
      // Listen for election events
      print('👂 Starting to listen for election events...');
      final electionsStream = _nostrService.subscribeToElections();
      
      // Give a brief moment for the subscription to establish, then stop loading if no events
      Timer(const Duration(seconds: 1), () {
        if (_isLoading && _elections.isEmpty) {
          print('📭 No events received after subscription - showing no elections message');
          _isLoading = false;
          notifyListeners();
        }
      });
      
      // Listen to real-time events
      print('🔄 Listening for real-time election events...');
      
      // Set up stream subscription instead of await for to handle completion
      _eventsSubscription?.cancel(); // Cancel any existing subscription
      _eventsSubscription = electionsStream.listen(
        (event) {
          print('📨 Received event in provider: kind=${event.kind}, id=${event.id}');
          
          try {
            if (event.kind == 35000) {
              print('🗳️ Found kind 35000 event, parsing content...');
              final content = jsonDecode(event.content);
              print('📋 Parsed content: $content');
              
              final election = Election.fromJson(content);
              print('✅ Created election: ${election.name} (${election.id})');
              
              // Avoid duplicates by checking if election ID already exists
              if (!_elections.any((e) => e.id == election.id)) {
                // Add to elections list
                _elections = [..._elections, election];
                
                // Stop loading if this is the first election
                if (_isLoading) {
                  _isLoading = false;
                }
                
                notifyListeners();
                print('📝 Added election to list. Total elections: ${_elections.length}');
              } else {
                print('⚠️ Duplicate election ignored: ${election.id}');
              }
            } else {
              print('➡️ Skipping non-election event: kind=${event.kind}');
            }
          } catch (e) {
            print('❌ Error parsing election event: $e');
            print('📄 Event content was: ${event.content}');
          }
        },
        onError: (error) {
          print('🚨 Stream error in provider: $error');
          if (_isLoading) {
            _isLoading = false;
            notifyListeners();
          }
        },
        onDone: () {
          print('📡 Nostr stream completed');
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
      print('💥 Error loading elections: $e');
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
}