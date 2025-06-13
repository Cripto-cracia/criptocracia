import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/election.dart';

/// Service for managing the locally selected election
/// Provides persistence across app restarts and individual field access
class SelectedElectionService {
  // Storage keys for individual fields
  static const String _selectedElectionKey = 'selected_election_full';
  static const String _selectedElectionIdKey = 'selected_election_id';
  static const String _selectedElectionNameKey = 'selected_election_name';
  static const String _selectedElectionStartTimeKey = 'selected_election_start_time';
  static const String _selectedElectionEndTimeKey = 'selected_election_end_time';
  static const String _selectedElectionStatusKey = 'selected_election_status';
  static const String _selectedElectionRsaPubKeyKey = 'selected_election_rsa_pub_key';
  static const String _selectedElectionCandidatesKey = 'selected_election_candidates';

  /// Store the selected election with all individual fields
  static Future<void> setSelectedElection(Election election) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Store complete election as JSON
    final electionJson = jsonEncode(election.toJson());
    await prefs.setString(_selectedElectionKey, electionJson);
    
    // Store individual fields for quick access
    await prefs.setString(_selectedElectionIdKey, election.id);
    await prefs.setString(_selectedElectionNameKey, election.name);
    await prefs.setInt(_selectedElectionStartTimeKey, election.startTime.millisecondsSinceEpoch);
    await prefs.setInt(_selectedElectionEndTimeKey, election.endTime.millisecondsSinceEpoch);
    await prefs.setString(_selectedElectionStatusKey, election.status);
    await prefs.setString(_selectedElectionRsaPubKeyKey, election.rsaPubKey);
    
    // Store candidates as JSON array
    final candidatesJson = jsonEncode(election.candidates.map((c) => c.toJson()).toList());
    await prefs.setString(_selectedElectionCandidatesKey, candidatesJson);
  }

  /// Retrieve the complete selected election
  static Future<Election?> getSelectedElection() async {
    final prefs = await SharedPreferences.getInstance();
    final electionJson = prefs.getString(_selectedElectionKey);
    
    if (electionJson == null) return null;
    
    try {
      final electionMap = jsonDecode(electionJson) as Map<String, dynamic>;
      return Election.fromJson(electionMap);
    } catch (e) {
      // If parsing fails, clear the corrupted data
      await clearSelectedElection();
      return null;
    }
  }

  /// Get selected election ID
  static Future<String?> getSelectedElectionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedElectionIdKey);
  }

  /// Get selected election name
  static Future<String?> getSelectedElectionName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedElectionNameKey);
  }

  /// Get selected election start time
  static Future<DateTime?> getSelectedElectionStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_selectedElectionStartTimeKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// Get selected election end time
  static Future<DateTime?> getSelectedElectionEndTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_selectedElectionEndTimeKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// Get selected election status
  static Future<String?> getSelectedElectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedElectionStatusKey);
  }

  /// Get selected election RSA public key
  static Future<String?> getSelectedElectionRsaPubKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedElectionRsaPubKeyKey);
  }

  /// Get selected election candidates
  static Future<List<Candidate>?> getSelectedElectionCandidates() async {
    final prefs = await SharedPreferences.getInstance();
    final candidatesJson = prefs.getString(_selectedElectionCandidatesKey);
    
    if (candidatesJson == null) return null;
    
    try {
      final candidatesList = jsonDecode(candidatesJson) as List;
      return candidatesList.map((c) => Candidate.fromJson(c as Map<String, dynamic>)).toList();
    } catch (e) {
      return null;
    }
  }

  /// Check if an election is currently selected
  static Future<bool> hasSelectedElection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_selectedElectionKey);
  }

  /// Clear the selected election
  static Future<void> clearSelectedElection() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove all election-related keys
    await prefs.remove(_selectedElectionKey);
    await prefs.remove(_selectedElectionIdKey);
    await prefs.remove(_selectedElectionNameKey);
    await prefs.remove(_selectedElectionStartTimeKey);
    await prefs.remove(_selectedElectionEndTimeKey);
    await prefs.remove(_selectedElectionStatusKey);
    await prefs.remove(_selectedElectionRsaPubKeyKey);
    await prefs.remove(_selectedElectionCandidatesKey);
  }

  /// Update the status of the selected election
  /// Useful when receiving real-time status updates via WebSocket
  static Future<void> updateSelectedElectionStatus(String newStatus) async {
    final selectedElection = await getSelectedElection();
    if (selectedElection == null) return;

    // Create updated election with new status
    final updatedElection = Election(
      id: selectedElection.id,
      name: selectedElection.name,
      startTime: selectedElection.startTime,
      endTime: selectedElection.endTime,
      candidates: selectedElection.candidates,
      status: newStatus,
      rsaPubKey: selectedElection.rsaPubKey,
    );

    // Store the updated election
    await setSelectedElection(updatedElection);
  }

  /// Check if a given election is the currently selected one
  static Future<bool> isElectionSelected(String electionId) async {
    final selectedId = await getSelectedElectionId();
    return selectedId == electionId;
  }
}