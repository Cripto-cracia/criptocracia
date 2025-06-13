// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Criptocracia';

  @override
  String get appSubtitle => 'Votación Electrónica sin Confianza';

  @override
  String get navElections => 'Elecciones';

  @override
  String get navResults => 'Resultados';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navAbout => 'Acerca de';

  @override
  String get selectElectionToViewResults =>
      'Selecciona una elección para ver los resultados';

  @override
  String get debugInfo => 'Info de Depuración';

  @override
  String get debugInformation => 'Información de Depuración';

  @override
  String relayUrl(String url) {
    return 'URL del Relay: $url';
  }

  @override
  String ecPublicKey(String key) {
    return 'Clave Pública EC: $key';
  }

  @override
  String debugMode(String mode) {
    return 'Modo Depuración: $mode';
  }

  @override
  String configured(String status) {
    return 'Configurado: $status';
  }

  @override
  String get close => 'Cerrar';

  @override
  String get aboutDescription =>
      'Un sistema de votación electrónica sin confianza que utiliza firmas RSA ciegas y el protocolo Nostr.';

  @override
  String get features => 'Características:';

  @override
  String get featureAnonymous =>
      '• Votación anónima con pruebas criptográficas';

  @override
  String get featureRealtime => '• Resultados en tiempo real vía Nostr';

  @override
  String get featureDecentralized => '• Recolección descentralizada de votos';

  @override
  String get featureTamperEvident =>
      '• Conteo de votos a prueba de manipulación';

  @override
  String get criptocraciaVoterApp => 'App de Votación Criptocracia';

  @override
  String get mobileVotingAppDescription =>
      'Una aplicación móvil de votación que utiliza el protocolo Nostr.';

  @override
  String get configuration => 'Configuración:';

  @override
  String get usage => 'Uso: flutter run -- [OPCIONES]';

  @override
  String get options => 'Opciones:';

  @override
  String get debugModeOption =>
      '-d, --debug               Habilitar modo depuración';

  @override
  String get helpOption =>
      '-h, --help                Mostrar este mensaje de ayuda';

  @override
  String get examples => 'Ejemplos:';

  @override
  String error(String message) {
    return 'Error: $message';
  }

  @override
  String get retry => 'Reintentar';

  @override
  String get noElectionsFound => 'No se Encontraron Elecciones';

  @override
  String get noElectionsFoundDescription =>
      'No se encontraron elecciones activas en el relay Nostr en las últimas 24 horas.';

  @override
  String startTime(String time) {
    return 'Inicio: $time';
  }

  @override
  String endTime(String time) {
    return 'Fin: $time';
  }

  @override
  String candidatesCount(int count) {
    return 'Candidatos ($count)';
  }

  @override
  String get noCandidatesAvailable =>
      'No hay candidatos disponibles para esta elección.';

  @override
  String get statusOpen => 'Abierta';

  @override
  String get statusInProgress => 'En Progreso';

  @override
  String get statusFinished => 'Finalizada';

  @override
  String get statusCanceled => 'Cancelada';

  @override
  String get castVote => 'Emitir Voto';

  @override
  String get election => 'Elección';

  @override
  String get yourChoice => 'Tu Elección';

  @override
  String get votingProcess => 'Proceso de Votación';

  @override
  String get generateNonce => 'Generar Nonce';

  @override
  String get sendBlindedNonce => 'Enviar Nonce Ciego';

  @override
  String get waitForSignature => 'Esperar Firma';

  @override
  String get voteComplete => 'Voto Completo';

  @override
  String get startVotingProcess => 'Iniciar Proceso de Votación';

  @override
  String get voteCastSuccessfully => '¡Voto Emitido Exitosamente!';

  @override
  String get voteRecordedAnonymously =>
      'Tu voto ha sido registrado anónimamente.';

  @override
  String get returnToElections => 'Volver a Elecciones';

  @override
  String electionResults(String name) {
    return '$name - Resultados';
  }

  @override
  String get pauseUpdates => 'Pausar Actualizaciones';

  @override
  String get resumeUpdates => 'Reanudar Actualizaciones';

  @override
  String get electionSummary => 'Resumen de la Elección';

  @override
  String get totalVotes => 'Total de Votos';

  @override
  String get candidates => 'Candidatos';

  @override
  String get status => 'Estado';

  @override
  String get live => 'En Vivo';

  @override
  String get paused => 'Pausado';

  @override
  String get results => 'Resultados';

  @override
  String get liveUpdates => 'En Vivo';

  @override
  String get noVotesRecorded => 'Aún no se han registrado votos';

  @override
  String get justNow => 'Justo ahora';

  @override
  String minutesAgo(int minutes) {
    return 'hace ${minutes}m';
  }

  @override
  String hoursAgo(int hours) {
    return 'hace ${hours}h';
  }

  @override
  String lastUpdated(String time) {
    return 'Última actualización: $time';
  }

  @override
  String get settings => 'Ajustes';

  @override
  String get errorLoadingKeys => 'Error al cargar las claves';

  @override
  String get noKeysAvailable => 'No hay claves disponibles';

  @override
  String get nostrIdentity => 'Identidad Nostr';

  @override
  String nostrIdentityDescription(String path) {
    return 'Tu identidad Nostr se deriva de tu frase semilla usando la ruta de derivación: $path';
  }

  @override
  String get publicKeyNpub => 'Clave Pública (npub)';

  @override
  String get publicKeyDescription => 'Tu identificador público Nostr';

  @override
  String get seedPhrase => 'Frase Semilla';

  @override
  String get seedPhraseDescription =>
      'Tu mnemónico de recuperación (¡manténlo seguro!)';

  @override
  String copiedToClipboard(String label) {
    return '$label copiado al portapapeles';
  }

  @override
  String get advanced => 'Avanzado';

  @override
  String get regenerateKeys => 'Regenerar Claves';

  @override
  String get regenerateKeysDescription =>
      'Generar nueva frase semilla (perderás la identidad actual)';

  @override
  String get aboutNip06 => 'Acerca de NIP-06';

  @override
  String get aboutNip06Description =>
      'Aprende sobre la derivación de claves Nostr';

  @override
  String get securityWarning => 'Advertencia de Seguridad';

  @override
  String get securityWarningText =>
      'Tu frase semilla es tu clave maestra. Nunca la compartas con nadie. Si la pierdes, no podrás recuperar tu identidad. Guárdala de forma segura sin conexión.';

  @override
  String get nip06DialogTitle => 'Acerca de NIP-06';

  @override
  String get nip06Description =>
      'NIP-06 define cómo derivar claves Nostr desde una frase semilla mnemónica.';

  @override
  String get derivationPath => 'Ruta de Derivación: m/44\'/1237\'/1989\'/0/0';

  @override
  String get derivationPathBip44 => '• 44\': Estándar BIP44';

  @override
  String get derivationPathCoinType => '• 1237\': Tipo de moneda Nostr';

  @override
  String get derivationPathAccount => '• 1989\': Índice de cuenta';

  @override
  String get derivationPathChange => '• 0: Cambio (externo)';

  @override
  String get derivationPathAddress => '• 0: Índice de dirección';

  @override
  String get nip06Compatibility =>
      'Esto asegura compatibilidad con otros clientes Nostr que siguen NIP-06.';

  @override
  String get regenerateKeysConfirmation =>
      'Esto generará una nueva frase semilla y eliminará tu identidad actual. Esta acción no se puede deshacer. ¿Estás seguro?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get regenerate => 'Regenerar';

  @override
  String get newKeysGenerated => 'Nuevas claves generadas exitosamente';

  @override
  String candidatesCountLabel(int count) {
    return '$count candidatos';
  }

  @override
  String votesCount(int count) {
    return '$count votos';
  }

  @override
  String get vote => 'Votar';

  @override
  String get votes => 'votos';

  @override
  String votesRatio(int votes, int total) {
    return '$votes / $total';
  }

  @override
  String get appNotConfigured =>
      'App no configurada. Por favor proporciona la URL del relay y la clave pública EC.';

  @override
  String get electionOrCandidateNotSelected =>
      'Elección o candidato no seleccionado.';

  @override
  String failedToGenerateBlindNonce(String error) {
    return 'Error al generar y cegar nonce: $error';
  }

  @override
  String get blindedNonceNotGenerated => 'Nonce ciego no generado';

  @override
  String failedToSendBlindedNonce(String error) {
    return 'Error al enviar nonce ciego: $error';
  }

  @override
  String get timeoutWaitingForSignature =>
      'Tiempo agotado esperando firma ciega';

  @override
  String failedToReceiveSignature(String error) {
    return 'Error al recibir firma ciega: $error';
  }

  @override
  String get missingDataForVoteCasting =>
      'Faltan datos requeridos para emitir el voto';

  @override
  String failedToCastVote(String error) {
    return 'Error al emitir voto: $error';
  }

  @override
  String failedToLoadElections(String error) {
    return 'Error al cargar elecciones: $error';
  }

  @override
  String errorListeningToResults(String error) {
    return 'Error al escuchar resultados: $error';
  }

  @override
  String failedToStartListeningResults(String error) {
    return 'Error al comenzar a escuchar resultados: $error';
  }

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get noActiveElectionsFound =>
      'No se encontraron elecciones activas en el relay Nostr en las últimas 24 horas.';

  @override
  String get noCandidatesForElection =>
      'No hay candidatos disponibles para esta elección.';

  @override
  String get votingScreenTitle => 'Emitir Voto';

  @override
  String get yourChoiceSection => 'Tu Elección';

  @override
  String get voteCastSuccessMessage => '¡Voto Emitido Exitosamente!';

  @override
  String lastUpdatedAt(String time) {
    return 'Última actualización: $time';
  }

  @override
  String get timeFormatJustNow => 'Justo ahora';

  @override
  String timeFormatMinutesAgo(int minutes) {
    return 'hace ${minutes}m';
  }

  @override
  String timeFormatHoursAgo(int hours) {
    return 'hace ${hours}h';
  }

  @override
  String candidatesCountShort(int count) {
    return '$count candidatos';
  }

  @override
  String electionStartLabel(String time) {
    return 'Inicio: $time';
  }

  @override
  String electionEndLabel(String time) {
    return 'Fin: $time';
  }

  @override
  String get votesLabel => 'votos';

  @override
  String voteRatioDisplay(int votes, int total) {
    return '$votes / $total';
  }

  @override
  String get notConnectedToRelay => 'No conectado al relay';

  @override
  String failedToConnectRelay(String error) {
    return 'Error al conectar con el relay Nostr: $error';
  }

  @override
  String get noVotesRecordedYet => 'Aún no se han registrado votos';

  @override
  String get liveUpdatesLabel => 'En Vivo';

  @override
  String get electionSection => 'Elección';

  @override
  String get votingProcessSection => 'Proceso de Votación';

  @override
  String get generateNonceStep => 'Generar Nonce';

  @override
  String get sendBlindedNonceStep => 'Enviar Nonce Ciego';

  @override
  String get waitForSignatureStep => 'Esperar Firma';

  @override
  String get voteCompleteStep => 'Voto Completo';

  @override
  String get voteCastSuccess => '¡Voto Emitido Exitosamente!';

  @override
  String get voteRecordedMessage => 'Tu voto ha sido registrado anónimamente.';

  @override
  String electionResultsTitle(String name) {
    return '$name - Resultados';
  }

  @override
  String get pauseUpdatesTooltip => 'Pausar Actualizaciones';

  @override
  String get resumeUpdatesTooltip => 'Reanudar Actualizaciones';

  @override
  String get electionSummarySection => 'Resumen';

  @override
  String get totalVotesLabel => 'Total de Votos';

  @override
  String get candidatesLabel => 'Candidatos';

  @override
  String get statusLabel => 'Estado';

  @override
  String get liveStatus => 'En Vivo';

  @override
  String get pausedStatus => 'Pausado';

  @override
  String get resultsSection => 'Resultados';

  @override
  String lastUpdatedLabel(String time) {
    return 'Última actualización: $time';
  }

  @override
  String failedToSendBlindNonce(String error) {
    return 'Error al enviar nonce ciego: $error';
  }

  @override
  String get timeoutWaitingSignature => 'Tiempo agotado esperando firma ciega';

  @override
  String get missingDataForVoting =>
      'Faltan datos requeridos para emitir el voto';

  @override
  String errorListeningResults(String error) {
    return 'Error al escuchar resultados: $error';
  }
}
