import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dart_nostr/dart_nostr.dart';

class NostrService {
  bool _connected = false;
  StreamSubscription? _eventSubscription;

  NostrService();

  Future<void> connect(String relayUrl) async {
    try {
      debugPrint('🔗 Attempting to connect to Nostr relay: $relayUrl');

      // Initialize dart_nostr with the relay
      await Nostr.instance.services.relays.init(relaysUrl: [relayUrl]);

      _connected = true;
      debugPrint('✅ Successfully connected to Nostr relay: $relayUrl');
    } catch (e) {
      _connected = false;
      debugPrint('❌ Failed to connect to Nostr relay: $e');
      throw Exception('Failed to connect to Nostr relay: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      // Cancel any active subscription
      await _eventSubscription?.cancel();
      _eventSubscription = null;

      // Close all relay connections
      await Nostr.instance.services.relays.disconnectFromRelays();

      _connected = false;
      debugPrint('Disconnected from Nostr relays');
    } catch (e) {
      debugPrint('Error disconnecting from Nostr relays: $e');
    }
  }

  String get publicKey => 'mock_public_key'; // TODO: Generate actual key pair

  Future<void> sendBlindedNonce(
    String ecPublicKey,
    Uint8List blindedNonce,
  ) async {
    if (!_connected) throw Exception('Not connected to relay');
    debugPrint('Sending blinded nonce to EC: ${base64.encode(blindedNonce)}');
  }

  Future<void> castVote(
    String electionId,
    int candidateId,
    Uint8List signature,
  ) async {
    if (!_connected) throw Exception('Not connected to relay');
    debugPrint('Casting vote for candidate $candidateId in election $electionId');
  }

  Stream<NostrEvent> subscribeToElections() {
    if (!_connected) {
      throw Exception('Not connected to relay');
    }

    // Calculate DateTime for 24 hours ago
    final since = DateTime.now().subtract(const Duration(hours: 24));
    debugPrint('📅 Looking for kind 35000 events since: $since');

    // Create request filter for kind 35000 events from last 24 hours
    final request = NostrRequest(
      filters: [
        NostrFilter(kinds: const [35000], since: since),
      ],
    );

    debugPrint('📡 Starting subscription for kind 35000 events...');

    // Start subscription using dart_nostr
    final nostrStream = Nostr.instance.services.relays.startEventsSubscription(
      request: request,
    );

    debugPrint('🎯 Subscription started, waiting for events...');

    // Convert dart_nostr events to our NostrEvent format
    return nostrStream.stream
        .map((dartNostrEvent) {
          debugPrint(
            '📥 Received event: kind=${dartNostrEvent.kind}, id=${dartNostrEvent.id}',
          );
          return dartNostrEvent;
        })
        .where((dartNostrEvent) {
          debugPrint(
            '🔍 Filtering event: kind=${dartNostrEvent.kind}, hasContent=${dartNostrEvent.content != null}',
          );
          return dartNostrEvent.id != null &&
              dartNostrEvent.kind != null &&
              dartNostrEvent.content != null &&
              dartNostrEvent.createdAt != null &&
              dartNostrEvent.tags != null &&
              dartNostrEvent.sig != null;
        })
        .map((dartNostrEvent) {
          debugPrint('✅ Processing valid event: ${dartNostrEvent.id}');
          return NostrEvent(
            id: dartNostrEvent.id!,
            pubkey: dartNostrEvent.pubkey,
            createdAt: dartNostrEvent.createdAt!.millisecondsSinceEpoch ~/ 1000,
            kind: dartNostrEvent.kind!,
            tags: dartNostrEvent.tags!,
            content: dartNostrEvent.content!,
            sig: dartNostrEvent.sig!,
          );
        })
        .handleError((error) {
          debugPrint('🚨 Stream error: $error');
        })
        .asBroadcastStream(); // Make it a broadcast stream to allow multiple listeners
  }

  Stream<NostrEvent> subscribeToResults(String electionId) {
    // TODO: Implement actual Nostr results subscription
    return Stream.periodic(const Duration(seconds: 5), (count) {
      return NostrEvent(
        id: "mock_result_$count",
        pubkey: "mock_pubkey",
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        kind: 1,
        tags: [],
        content: jsonEncode({
          'type': 'election_results',
          'election_id': electionId,
          'results': {'1': 10 + count * 2, '2': 8 + count * 3},
        }),
        sig: "mock_signature",
      );
    });
  }

  Stream<NostrEvent> subscribeToBlindSignatures() {
    return Stream.fromIterable([]);
  }

  Future<Uint8List?> waitForBlindSignature() async {
    await Future.delayed(const Duration(seconds: 2));
    return Uint8List.fromList([1, 2, 3, 4]); // Mock signature
  }
}

// Nostr event class (keeping our own for consistency)
class NostrEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;

  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
  });
}
