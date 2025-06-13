import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/nostr_key_manager.dart';
import '../generated/app_localizations.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _keys;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _seedPhraseController = TextEditingController();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _seedPhraseController.addListener(() {
      setState(() {}); // Rebuild to update button state
    });
  }

  Future<void> _loadKeys() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final keys = await NostrKeyManager.getDerivedKeys();
      setState(() {
        _keys = keys;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).copiedToClipboard(label)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _seedPhraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).account),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).errorLoadingKeys,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadKeys,
                        child: Text(AppLocalizations.of(context).retry),
                      ),
                    ],
                  ),
                )
              : _buildAccountContent(),
    );
  }

  Widget _buildAccountContent() {
    if (_keys == null) {
      return Center(child: Text(AppLocalizations.of(context).noKeysAvailable));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nostr Identity Section
          _buildSectionHeader(AppLocalizations.of(context).nostrIdentity),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).nostrIdentityDescription(_keys!['derivationPath']),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // NPub Card
          _buildKeyCard(
            title: AppLocalizations.of(context).publicKeyNpub,
            subtitle: AppLocalizations.of(context).publicKeyDescription,
            value: _keys!['npub'],
            icon: Icons.public,
            onTap: () => _copyToClipboard(_keys!['npub'], AppLocalizations.of(context).publicKeyNpub),
          ),
          const SizedBox(height: 16),

          // Seed Phrase Card
          _buildKeyCard(
            title: AppLocalizations.of(context).seedPhrase,
            subtitle: AppLocalizations.of(context).seedPhraseDescription,
            value: _keys!['mnemonic'],
            icon: Icons.security,
            onTap: () => _copyToClipboard(_keys!['mnemonic'], AppLocalizations.of(context).seedPhrase),
            isSecret: true,
          ),
          const SizedBox(height: 24),

          // Security Warning
          _buildSecurityWarning(),
          const SizedBox(height: 24),

          // Advanced Section
          _buildSectionHeader(AppLocalizations.of(context).advanced),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(AppLocalizations.of(context).regenerateKeys),
            subtitle: Text(AppLocalizations.of(context).regenerateKeysDescription),
            onTap: _showRegenerateConfirmation,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppLocalizations.of(context).aboutNip06),
            subtitle: Text(AppLocalizations.of(context).aboutNip06Description),
            onTap: _showNip06Info,
          ),
          const SizedBox(height: 16),
          _buildImportSeedPhraseSection(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildKeyCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool isSecret = false,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.copy, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSecret ? _maskSeedPhrase(value) : value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).securityWarning,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).securityWarningText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
          ),
        ],
      ),
    );
  }

  String _maskSeedPhrase(String seedPhrase) {
    final words = seedPhrase.split(' ');
    if (words.length < 4) return seedPhrase;

    // Show first 2 and last 2 words, mask the middle
    final first = words.take(2).join(' ');
    final last = words.skip(words.length - 2).join(' ');
    final masked = '••• ••• ••• •••';

    return '$first $masked $last';
  }

  void _showNip06Info() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About NIP-06'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).nip06Description),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).derivationPath),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).derivationPathBip44),
              Text(AppLocalizations.of(context).derivationPathCoinType),
              Text(AppLocalizations.of(context).derivationPathAccount),
              Text(AppLocalizations.of(context).derivationPathChange),
              Text(AppLocalizations.of(context).derivationPathAddress),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).nip06Compatibility),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).close),
          ),
        ],
      ),
    );
  }

  void _showRegenerateConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Keys'),
        content: Text(
          AppLocalizations.of(context).regenerateKeysConfirmation,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _regenerateKeys();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context).regenerate),
          ),
        ],
      ),
    );
  }

  Widget _buildImportSeedPhraseSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).importSeedPhrase,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        AppLocalizations.of(context).importSeedPhraseDescription,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _seedPhraseController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).enterSeedPhrase,
                hintText: AppLocalizations.of(context).seedPhraseHint,
                border: const OutlineInputBorder(),
                enabled: !_isImporting,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting || _seedPhraseController.text.trim().isEmpty
                    ? null
                    : _showImportConfirmation,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(AppLocalizations.of(context).importButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImportConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(AppLocalizations.of(context).importSeedPhraseWarning),
            ),
          ],
        ),
        content: Text(AppLocalizations.of(context).importWarningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _importSeedPhrase();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context).continueImport),
          ),
        ],
      ),
    );
  }

  Future<void> _importSeedPhrase() async {
    final seedPhrase = _seedPhraseController.text.trim();
    
    if (seedPhrase.isEmpty) {
      return;
    }

    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      // Import the new seed phrase
      await NostrKeyManager.importMnemonic(seedPhrase);
      
      // Reload the keys to display the new identity
      await _loadKeys();
      
      // Clear the input field
      _seedPhraseController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).seedPhraseImportedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Invalid') 
                ? AppLocalizations.of(context).invalidSeedPhrase 
                : AppLocalizations.of(context).errorWithMessage(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _regenerateKeys() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Clear existing keys and generate new ones
      await NostrKeyManager.clearAllKeys();
      await NostrKeyManager.generateAndStoreMnemonic();
      await _loadKeys();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).newKeysGenerated),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}