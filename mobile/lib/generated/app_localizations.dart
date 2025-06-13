import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Criptocracia'**
  String get appTitle;

  /// The application subtitle shown in the drawer
  ///
  /// In en, this message translates to:
  /// **'Trustless Electronic Voting'**
  String get appSubtitle;

  /// Navigation label for elections tab
  ///
  /// In en, this message translates to:
  /// **'Elections'**
  String get navElections;

  /// Navigation label for results tab
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get navResults;

  /// Navigation label for settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Navigation label for about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// Message shown when no election is selected for results view
  ///
  /// In en, this message translates to:
  /// **'Select an election to view results'**
  String get selectElectionToViewResults;

  /// Debug information label
  ///
  /// In en, this message translates to:
  /// **'Debug Info'**
  String get debugInfo;

  /// Debug information dialog title
  ///
  /// In en, this message translates to:
  /// **'Debug Information'**
  String get debugInformation;

  /// Debug info relay URL
  ///
  /// In en, this message translates to:
  /// **'Relay URL: {url}'**
  String relayUrl(String url);

  /// Debug info EC public key
  ///
  /// In en, this message translates to:
  /// **'EC Public Key: {key}'**
  String ecPublicKey(String key);

  /// Debug mode status
  ///
  /// In en, this message translates to:
  /// **'Debug Mode: {mode}'**
  String debugMode(String mode);

  /// Configuration status
  ///
  /// In en, this message translates to:
  /// **'Configured: {status}'**
  String configured(String status);

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// About dialog description
  ///
  /// In en, this message translates to:
  /// **'A trustless electronic voting system using blind RSA signatures and the Nostr protocol.'**
  String get aboutDescription;

  /// Features section header
  ///
  /// In en, this message translates to:
  /// **'Features:'**
  String get features;

  /// Anonymous voting feature
  ///
  /// In en, this message translates to:
  /// **'• Anonymous voting with cryptographic proofs'**
  String get featureAnonymous;

  /// Real-time results feature
  ///
  /// In en, this message translates to:
  /// **'• Real-time results via Nostr'**
  String get featureRealtime;

  /// Decentralized collection feature
  ///
  /// In en, this message translates to:
  /// **'• Decentralized vote collection'**
  String get featureDecentralized;

  /// Tamper-evident counting feature
  ///
  /// In en, this message translates to:
  /// **'• Tamper-evident vote counting'**
  String get featureTamperEvident;

  /// App name in help text
  ///
  /// In en, this message translates to:
  /// **'Criptocracia Voter App'**
  String get criptocraciaVoterApp;

  /// App description in help text
  ///
  /// In en, this message translates to:
  /// **'A mobile voting application using the Nostr protocol.'**
  String get mobileVotingAppDescription;

  /// Configuration section header
  ///
  /// In en, this message translates to:
  /// **'Configuration:'**
  String get configuration;

  /// Usage instructions
  ///
  /// In en, this message translates to:
  /// **'Usage: flutter run -- [OPTIONS]'**
  String get usage;

  /// Options section header
  ///
  /// In en, this message translates to:
  /// **'Options:'**
  String get options;

  /// Debug mode option description
  ///
  /// In en, this message translates to:
  /// **'-d, --debug               Enable debug mode'**
  String get debugModeOption;

  /// Help option description
  ///
  /// In en, this message translates to:
  /// **'-h, --help                Show this help message'**
  String get helpOption;

  /// Examples section header
  ///
  /// In en, this message translates to:
  /// **'Examples:'**
  String get examples;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String error(String message);

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No elections found title
  ///
  /// In en, this message translates to:
  /// **'No Elections Found'**
  String get noElectionsFound;

  /// No elections found description
  ///
  /// In en, this message translates to:
  /// **'No active elections were found on the Nostr relay in the last 24 hours.'**
  String get noElectionsFoundDescription;

  /// Election start time
  ///
  /// In en, this message translates to:
  /// **'Start: {time}'**
  String startTime(String time);

  /// Election end time
  ///
  /// In en, this message translates to:
  /// **'End: {time}'**
  String endTime(String time);

  /// Candidates section with count
  ///
  /// In en, this message translates to:
  /// **'Candidates ({count})'**
  String candidatesCount(int count);

  /// No candidates available message
  ///
  /// In en, this message translates to:
  /// **'No candidates available for this election.'**
  String get noCandidatesAvailable;

  /// Election status: Open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// Election status: In Progress
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// Election status: Finished
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get statusFinished;

  /// Election status: Canceled
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get statusCanceled;

  /// Cast vote screen title and button
  ///
  /// In en, this message translates to:
  /// **'Cast Vote'**
  String get castVote;

  /// Election section header
  ///
  /// In en, this message translates to:
  /// **'Election'**
  String get election;

  /// Your choice section header
  ///
  /// In en, this message translates to:
  /// **'Your Choice'**
  String get yourChoice;

  /// Voting process section header
  ///
  /// In en, this message translates to:
  /// **'Voting Process'**
  String get votingProcess;

  /// Generate nonce step
  ///
  /// In en, this message translates to:
  /// **'Generate Nonce'**
  String get generateNonce;

  /// Send blinded nonce step
  ///
  /// In en, this message translates to:
  /// **'Send Blinded Nonce'**
  String get sendBlindedNonce;

  /// Wait for signature step
  ///
  /// In en, this message translates to:
  /// **'Wait for Signature'**
  String get waitForSignature;

  /// Vote complete step
  ///
  /// In en, this message translates to:
  /// **'Vote Complete'**
  String get voteComplete;

  /// Start voting process button
  ///
  /// In en, this message translates to:
  /// **'Start Voting Process'**
  String get startVotingProcess;

  /// Vote cast success message
  ///
  /// In en, this message translates to:
  /// **'Vote Cast Successfully!'**
  String get voteCastSuccessfully;

  /// Vote recorded message
  ///
  /// In en, this message translates to:
  /// **'Your vote has been recorded anonymously.'**
  String get voteRecordedAnonymously;

  /// Return to elections button
  ///
  /// In en, this message translates to:
  /// **'Return to Elections'**
  String get returnToElections;

  /// Election results title
  ///
  /// In en, this message translates to:
  /// **'{name} - Results'**
  String electionResults(String name);

  /// Pause updates tooltip
  ///
  /// In en, this message translates to:
  /// **'Pause Updates'**
  String get pauseUpdates;

  /// Resume updates tooltip
  ///
  /// In en, this message translates to:
  /// **'Resume Updates'**
  String get resumeUpdates;

  /// Election summary section
  ///
  /// In en, this message translates to:
  /// **'Election Summary'**
  String get electionSummary;

  /// Total votes label
  ///
  /// In en, this message translates to:
  /// **'Total Votes'**
  String get totalVotes;

  /// Candidates label
  ///
  /// In en, this message translates to:
  /// **'Candidates'**
  String get candidates;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Live status
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// Paused status
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// Results section header
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// Live updates label
  ///
  /// In en, this message translates to:
  /// **'Live Updates'**
  String get liveUpdates;

  /// No votes recorded message
  ///
  /// In en, this message translates to:
  /// **'No votes recorded yet'**
  String get noVotesRecorded;

  /// Just now time format
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Minutes ago time format
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// Hours ago time format
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// Last updated time
  ///
  /// In en, this message translates to:
  /// **'Last updated: {time}'**
  String lastUpdated(String time);

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Error loading keys message
  ///
  /// In en, this message translates to:
  /// **'Error loading keys'**
  String get errorLoadingKeys;

  /// No keys available message
  ///
  /// In en, this message translates to:
  /// **'No keys available'**
  String get noKeysAvailable;

  /// Nostr identity section
  ///
  /// In en, this message translates to:
  /// **'Nostr Identity'**
  String get nostrIdentity;

  /// Nostr identity description
  ///
  /// In en, this message translates to:
  /// **'Your Nostr identity is derived from your seed phrase using the derivation path: {path}'**
  String nostrIdentityDescription(String path);

  /// Public key npub label
  ///
  /// In en, this message translates to:
  /// **'Public Key (npub)'**
  String get publicKeyNpub;

  /// Public key description
  ///
  /// In en, this message translates to:
  /// **'Your Nostr public identifier'**
  String get publicKeyDescription;

  /// Seed phrase label
  ///
  /// In en, this message translates to:
  /// **'Seed Phrase'**
  String get seedPhrase;

  /// Seed phrase description
  ///
  /// In en, this message translates to:
  /// **'Your recovery mnemonic (keep this secure!)'**
  String get seedPhraseDescription;

  /// Copied to clipboard message
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboard(String label);

  /// Advanced section
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// Regenerate keys button
  ///
  /// In en, this message translates to:
  /// **'Regenerate Keys'**
  String get regenerateKeys;

  /// Regenerate keys description
  ///
  /// In en, this message translates to:
  /// **'Generate new seed phrase (will lose current identity)'**
  String get regenerateKeysDescription;

  /// About NIP-06 button
  ///
  /// In en, this message translates to:
  /// **'About NIP-06'**
  String get aboutNip06;

  /// About NIP-06 description
  ///
  /// In en, this message translates to:
  /// **'Learn about Nostr key derivation'**
  String get aboutNip06Description;

  /// Security warning title
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarning;

  /// Security warning text
  ///
  /// In en, this message translates to:
  /// **'Your seed phrase is your master key. Never share it with anyone. If you lose it, you cannot recover your identity. Store it safely offline.'**
  String get securityWarningText;

  /// NIP-06 dialog title
  ///
  /// In en, this message translates to:
  /// **'About NIP-06'**
  String get nip06DialogTitle;

  /// NIP-06 description
  ///
  /// In en, this message translates to:
  /// **'NIP-06 defines how to derive Nostr keys from a mnemonic seed phrase.'**
  String get nip06Description;

  /// Derivation path
  ///
  /// In en, this message translates to:
  /// **'Derivation Path: m/44\'/1237\'/1989\'/0/0'**
  String get derivationPath;

  /// BIP44 standard explanation
  ///
  /// In en, this message translates to:
  /// **'• 44\': BIP44 standard'**
  String get derivationPathBip44;

  /// Nostr coin type explanation
  ///
  /// In en, this message translates to:
  /// **'• 1237\': Nostr coin type'**
  String get derivationPathCoinType;

  /// Account index explanation
  ///
  /// In en, this message translates to:
  /// **'• 1989\': Account index'**
  String get derivationPathAccount;

  /// Change explanation
  ///
  /// In en, this message translates to:
  /// **'• 0: Change (external)'**
  String get derivationPathChange;

  /// Address index explanation
  ///
  /// In en, this message translates to:
  /// **'• 0: Address index'**
  String get derivationPathAddress;

  /// NIP-06 compatibility note
  ///
  /// In en, this message translates to:
  /// **'This ensures compatibility with other Nostr clients that follow NIP-06.'**
  String get nip06Compatibility;

  /// Regenerate keys confirmation message
  ///
  /// In en, this message translates to:
  /// **'This will generate a new seed phrase and delete your current identity. This action cannot be undone. Are you sure?'**
  String get regenerateKeysConfirmation;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Regenerate button
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// New keys generated success message
  ///
  /// In en, this message translates to:
  /// **'New keys generated successfully'**
  String get newKeysGenerated;

  /// Candidates count label
  ///
  /// In en, this message translates to:
  /// **'{count} candidates'**
  String candidatesCountLabel(int count);

  /// Votes count
  ///
  /// In en, this message translates to:
  /// **'{count} votes'**
  String votesCount(int count);

  /// Vote button
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get vote;

  /// Votes label
  ///
  /// In en, this message translates to:
  /// **'votes'**
  String get votes;

  /// Votes ratio display
  ///
  /// In en, this message translates to:
  /// **'{votes} / {total}'**
  String votesRatio(int votes, int total);

  /// App not configured error
  ///
  /// In en, this message translates to:
  /// **'App not configured. Please provide relay URL and EC public key.'**
  String get appNotConfigured;

  /// Election or candidate not selected error
  ///
  /// In en, this message translates to:
  /// **'Election or candidate not selected.'**
  String get electionOrCandidateNotSelected;

  /// Failed to generate blind nonce error
  ///
  /// In en, this message translates to:
  /// **'Failed to generate and blind nonce: {error}'**
  String failedToGenerateBlindNonce(String error);

  /// Blinded nonce not generated error
  ///
  /// In en, this message translates to:
  /// **'Blinded nonce not generated'**
  String get blindedNonceNotGenerated;

  /// Failed to send blinded nonce error
  ///
  /// In en, this message translates to:
  /// **'Failed to send blinded nonce: {error}'**
  String failedToSendBlindedNonce(String error);

  /// Timeout waiting for signature error
  ///
  /// In en, this message translates to:
  /// **'Timeout waiting for blind signature'**
  String get timeoutWaitingForSignature;

  /// Failed to receive signature error
  ///
  /// In en, this message translates to:
  /// **'Failed to receive blind signature: {error}'**
  String failedToReceiveSignature(String error);

  /// Missing data for vote casting error
  ///
  /// In en, this message translates to:
  /// **'Missing required data for vote casting'**
  String get missingDataForVoteCasting;

  /// Failed to cast vote error
  ///
  /// In en, this message translates to:
  /// **'Failed to cast vote: {error}'**
  String failedToCastVote(String error);

  /// Failed to load elections error
  ///
  /// In en, this message translates to:
  /// **'Failed to load elections: {error}'**
  String failedToLoadElections(String error);

  /// Error listening to results
  ///
  /// In en, this message translates to:
  /// **'Error listening to results: {error}'**
  String errorListeningToResults(String error);

  /// Failed to start listening to results error
  ///
  /// In en, this message translates to:
  /// **'Failed to start listening to results: {error}'**
  String failedToStartListeningResults(String error);

  /// Generic error with message
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No active elections found description
  ///
  /// In en, this message translates to:
  /// **'No active elections were found on the Nostr relay in the last 24 hours.'**
  String get noActiveElectionsFound;

  /// No candidates available message
  ///
  /// In en, this message translates to:
  /// **'No candidates available for this election.'**
  String get noCandidatesForElection;

  /// Voting screen title
  ///
  /// In en, this message translates to:
  /// **'Cast Vote'**
  String get votingScreenTitle;

  /// Your choice section header
  ///
  /// In en, this message translates to:
  /// **'Your Choice'**
  String get yourChoiceSection;

  /// Vote cast success message
  ///
  /// In en, this message translates to:
  /// **'Vote Cast Successfully!'**
  String get voteCastSuccessMessage;

  /// Last updated time
  ///
  /// In en, this message translates to:
  /// **'Last updated: {time}'**
  String lastUpdatedAt(String time);

  /// Just now time format
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeFormatJustNow;

  /// Minutes ago format
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeFormatMinutesAgo(int minutes);

  /// Hours ago format
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeFormatHoursAgo(int hours);

  /// Short candidates count
  ///
  /// In en, this message translates to:
  /// **'{count} candidates'**
  String candidatesCountShort(int count);

  /// Election start time label
  ///
  /// In en, this message translates to:
  /// **'Start: {time}'**
  String electionStartLabel(String time);

  /// Election end time label
  ///
  /// In en, this message translates to:
  /// **'End: {time}'**
  String electionEndLabel(String time);

  /// Votes label in singular/plural context
  ///
  /// In en, this message translates to:
  /// **'votes'**
  String get votesLabel;

  /// Vote ratio display format
  ///
  /// In en, this message translates to:
  /// **'{votes} / {total}'**
  String voteRatioDisplay(int votes, int total);

  /// Error when not connected to relay
  ///
  /// In en, this message translates to:
  /// **'Not connected to relay'**
  String get notConnectedToRelay;

  /// Failed to connect to relay error
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to Nostr relay: {error}'**
  String failedToConnectRelay(String error);

  /// No votes recorded message
  ///
  /// In en, this message translates to:
  /// **'No votes recorded yet'**
  String get noVotesRecordedYet;

  /// Live updates indicator
  ///
  /// In en, this message translates to:
  /// **'Live Updates'**
  String get liveUpdatesLabel;

  /// Election section header
  ///
  /// In en, this message translates to:
  /// **'Election'**
  String get electionSection;

  /// Voting process section header
  ///
  /// In en, this message translates to:
  /// **'Voting Process'**
  String get votingProcessSection;

  /// Generate nonce voting step
  ///
  /// In en, this message translates to:
  /// **'Generate Nonce'**
  String get generateNonceStep;

  /// Send blinded nonce voting step
  ///
  /// In en, this message translates to:
  /// **'Send Blinded Nonce'**
  String get sendBlindedNonceStep;

  /// Wait for signature voting step
  ///
  /// In en, this message translates to:
  /// **'Wait for Signature'**
  String get waitForSignatureStep;

  /// Vote complete step
  ///
  /// In en, this message translates to:
  /// **'Vote Complete'**
  String get voteCompleteStep;

  /// Vote cast success message
  ///
  /// In en, this message translates to:
  /// **'Vote Cast Successfully!'**
  String get voteCastSuccess;

  /// Vote recorded confirmation message
  ///
  /// In en, this message translates to:
  /// **'Your vote has been recorded anonymously.'**
  String get voteRecordedMessage;

  /// Election results screen title
  ///
  /// In en, this message translates to:
  /// **'{name} - Results'**
  String electionResultsTitle(String name);

  /// Pause updates tooltip
  ///
  /// In en, this message translates to:
  /// **'Pause Updates'**
  String get pauseUpdatesTooltip;

  /// Resume updates tooltip
  ///
  /// In en, this message translates to:
  /// **'Resume Updates'**
  String get resumeUpdatesTooltip;

  /// Election summary section header
  ///
  /// In en, this message translates to:
  /// **'Election Summary'**
  String get electionSummarySection;

  /// Total votes label
  ///
  /// In en, this message translates to:
  /// **'Total Votes'**
  String get totalVotesLabel;

  /// Candidates label
  ///
  /// In en, this message translates to:
  /// **'Candidates'**
  String get candidatesLabel;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// Live status indicator
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveStatus;

  /// Paused status indicator
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pausedStatus;

  /// Results section header
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get resultsSection;

  /// Last updated label with time
  ///
  /// In en, this message translates to:
  /// **'Last updated: {time}'**
  String lastUpdatedLabel(String time);

  /// Failed to send blinded nonce error
  ///
  /// In en, this message translates to:
  /// **'Failed to send blinded nonce: {error}'**
  String failedToSendBlindNonce(String error);

  /// Timeout waiting for signature error
  ///
  /// In en, this message translates to:
  /// **'Timeout waiting for blind signature'**
  String get timeoutWaitingSignature;

  /// Missing data for voting error
  ///
  /// In en, this message translates to:
  /// **'Missing required data for vote casting'**
  String get missingDataForVoting;

  /// Error listening to results
  ///
  /// In en, this message translates to:
  /// **'Error listening to results: {error}'**
  String errorListeningResults(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
