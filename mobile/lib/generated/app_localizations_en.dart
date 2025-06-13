// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Criptocracia';

  @override
  String get appSubtitle => 'Trustless Electronic Voting';

  @override
  String get navElections => 'Elections';

  @override
  String get navResults => 'Results';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAbout => 'About';

  @override
  String get selectElectionToViewResults =>
      'Select an election to view results';

  @override
  String get debugInfo => 'Debug Info';

  @override
  String get debugInformation => 'Debug Information';

  @override
  String relayUrl(String url) {
    return 'Relay URL: $url';
  }

  @override
  String ecPublicKey(String key) {
    return 'EC Public Key: $key';
  }

  @override
  String debugMode(String mode) {
    return 'Debug Mode: $mode';
  }

  @override
  String configured(String status) {
    return 'Configured: $status';
  }

  @override
  String get close => 'Close';

  @override
  String get aboutDescription =>
      'A trustless electronic voting system using blind RSA signatures and the Nostr protocol.';

  @override
  String get features => 'Features:';

  @override
  String get featureAnonymous => '• Anonymous voting with cryptographic proofs';

  @override
  String get featureRealtime => '• Real-time results via Nostr';

  @override
  String get featureDecentralized => '• Decentralized vote collection';

  @override
  String get featureTamperEvident => '• Tamper-evident vote counting';

  @override
  String get criptocraciaVoterApp => 'Criptocracia Voter App';

  @override
  String get mobileVotingAppDescription =>
      'A mobile voting application using the Nostr protocol.';

  @override
  String get configuration => 'Configuration:';

  @override
  String get usage => 'Usage: flutter run -- [OPTIONS]';

  @override
  String get options => 'Options:';

  @override
  String get debugModeOption => '-d, --debug               Enable debug mode';

  @override
  String get helpOption => '-h, --help                Show this help message';

  @override
  String get examples => 'Examples:';

  @override
  String error(String message) {
    return 'Error: $message';
  }

  @override
  String get retry => 'Retry';

  @override
  String get noElectionsFound => 'No Elections Found';

  @override
  String get noElectionsFoundDescription =>
      'No active elections were found on the Nostr relay in the last 24 hours.';

  @override
  String startTime(String time) {
    return 'Start: $time';
  }

  @override
  String endTime(String time) {
    return 'End: $time';
  }

  @override
  String candidatesCount(int count) {
    return 'Candidates ($count)';
  }

  @override
  String get noCandidatesAvailable =>
      'No candidates available for this election.';

  @override
  String get statusOpen => 'Open';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusFinished => 'Finished';

  @override
  String get statusCanceled => 'Canceled';

  @override
  String get castVote => 'Cast Vote';

  @override
  String get election => 'Election';

  @override
  String get yourChoice => 'Your Choice';

  @override
  String get votingProcess => 'Voting Process';

  @override
  String get generateNonce => 'Generate Nonce';

  @override
  String get sendBlindedNonce => 'Send Blinded Nonce';

  @override
  String get waitForSignature => 'Wait for Signature';

  @override
  String get voteComplete => 'Vote Complete';

  @override
  String get startVotingProcess => 'Start Voting Process';

  @override
  String get voteCastSuccessfully => 'Vote Cast Successfully!';

  @override
  String get voteRecordedAnonymously =>
      'Your vote has been recorded anonymously.';

  @override
  String get returnToElections => 'Return to Elections';

  @override
  String electionResults(String name) {
    return '$name - Results';
  }

  @override
  String get pauseUpdates => 'Pause Updates';

  @override
  String get resumeUpdates => 'Resume Updates';

  @override
  String get electionSummary => 'Election Summary';

  @override
  String get totalVotes => 'Total Votes';

  @override
  String get candidates => 'Candidates';

  @override
  String get status => 'Status';

  @override
  String get live => 'Live';

  @override
  String get paused => 'Paused';

  @override
  String get results => 'Results';

  @override
  String get liveUpdates => 'Live Updates';

  @override
  String get noVotesRecorded => 'No votes recorded yet';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String lastUpdated(String time) {
    return 'Last updated: $time';
  }

  @override
  String get settings => 'Settings';

  @override
  String get errorLoadingKeys => 'Error loading keys';

  @override
  String get noKeysAvailable => 'No keys available';

  @override
  String get nostrIdentity => 'Nostr Identity';

  @override
  String nostrIdentityDescription(String path) {
    return 'Your Nostr identity is derived from your seed phrase using the derivation path: $path';
  }

  @override
  String get publicKeyNpub => 'Public Key (npub)';

  @override
  String get publicKeyDescription => 'Your Nostr public identifier';

  @override
  String get seedPhrase => 'Seed Phrase';

  @override
  String get seedPhraseDescription =>
      'Your recovery mnemonic (keep this secure!)';

  @override
  String copiedToClipboard(String label) {
    return '$label copied to clipboard';
  }

  @override
  String get advanced => 'Advanced';

  @override
  String get regenerateKeys => 'Regenerate Keys';

  @override
  String get regenerateKeysDescription =>
      'Generate new seed phrase (will lose current identity)';

  @override
  String get aboutNip06 => 'About NIP-06';

  @override
  String get aboutNip06Description => 'Learn about Nostr key derivation';

  @override
  String get securityWarning => 'Security Warning';

  @override
  String get securityWarningText =>
      'Your seed phrase is your master key. Never share it with anyone. If you lose it, you cannot recover your identity. Store it safely offline.';

  @override
  String get nip06DialogTitle => 'About NIP-06';

  @override
  String get nip06Description =>
      'NIP-06 defines how to derive Nostr keys from a mnemonic seed phrase.';

  @override
  String get derivationPath => 'Derivation Path: m/44\'/1237\'/1989\'/0/0';

  @override
  String get derivationPathBip44 => '• 44\': BIP44 standard';

  @override
  String get derivationPathCoinType => '• 1237\': Nostr coin type';

  @override
  String get derivationPathAccount => '• 1989\': Account index';

  @override
  String get derivationPathChange => '• 0: Change (external)';

  @override
  String get derivationPathAddress => '• 0: Address index';

  @override
  String get nip06Compatibility =>
      'This ensures compatibility with other Nostr clients that follow NIP-06.';

  @override
  String get regenerateKeysConfirmation =>
      'This will generate a new seed phrase and delete your current identity. This action cannot be undone. Are you sure?';

  @override
  String get cancel => 'Cancel';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get newKeysGenerated => 'New keys generated successfully';

  @override
  String candidatesCountLabel(int count) {
    return '$count candidates';
  }

  @override
  String votesCount(int count) {
    return '$count votes';
  }

  @override
  String get vote => 'Vote';

  @override
  String get votes => 'votes';

  @override
  String votesRatio(int votes, int total) {
    return '$votes / $total';
  }

  @override
  String get appNotConfigured =>
      'App not configured. Please provide relay URL and EC public key.';

  @override
  String get electionOrCandidateNotSelected =>
      'Election or candidate not selected.';

  @override
  String failedToGenerateBlindNonce(String error) {
    return 'Failed to generate and blind nonce: $error';
  }

  @override
  String get blindedNonceNotGenerated => 'Blinded nonce not generated';

  @override
  String failedToSendBlindedNonce(String error) {
    return 'Failed to send blinded nonce: $error';
  }

  @override
  String get timeoutWaitingForSignature =>
      'Timeout waiting for blind signature';

  @override
  String failedToReceiveSignature(String error) {
    return 'Failed to receive blind signature: $error';
  }

  @override
  String get missingDataForVoteCasting =>
      'Missing required data for vote casting';

  @override
  String failedToCastVote(String error) {
    return 'Failed to cast vote: $error';
  }

  @override
  String failedToLoadElections(String error) {
    return 'Failed to load elections: $error';
  }

  @override
  String errorListeningToResults(String error) {
    return 'Error listening to results: $error';
  }

  @override
  String failedToStartListeningResults(String error) {
    return 'Failed to start listening to results: $error';
  }

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get noActiveElectionsFound =>
      'No active elections were found on the Nostr relay in the last 24 hours.';

  @override
  String get noCandidatesForElection =>
      'No candidates available for this election.';

  @override
  String get votingScreenTitle => 'Cast Vote';

  @override
  String get yourChoiceSection => 'Your Choice';

  @override
  String get voteCastSuccessMessage => 'Vote Cast Successfully!';

  @override
  String lastUpdatedAt(String time) {
    return 'Last updated: $time';
  }

  @override
  String get timeFormatJustNow => 'Just now';

  @override
  String timeFormatMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeFormatHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String candidatesCountShort(int count) {
    return '$count candidates';
  }

  @override
  String electionStartLabel(String time) {
    return 'Start: $time';
  }

  @override
  String electionEndLabel(String time) {
    return 'End: $time';
  }

  @override
  String get votesLabel => 'votes';

  @override
  String voteRatioDisplay(int votes, int total) {
    return '$votes / $total';
  }

  @override
  String get notConnectedToRelay => 'Not connected to relay';

  @override
  String failedToConnectRelay(String error) {
    return 'Failed to connect to Nostr relay: $error';
  }

  @override
  String get noVotesRecordedYet => 'No votes recorded yet';

  @override
  String get liveUpdatesLabel => 'Live Updates';
}
