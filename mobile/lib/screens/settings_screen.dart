import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/nostr_key_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _keys;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadKeys();
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
          content: Text('$label copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                        'Error loading keys',
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
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildSettingsContent(),
    );
  }

  Widget _buildSettingsContent() {
    if (_keys == null) {
      return const Center(child: Text('No keys available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nostr Identity Section
          _buildSectionHeader('Nostr Identity'),
          const SizedBox(height: 8),
          Text(
            'Your Nostr identity is derived from your seed phrase using the derivation path: ${_keys!['derivationPath']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // NPub Card
          _buildKeyCard(
            title: 'Public Key (npub)',
            subtitle: 'Your Nostr public identifier',
            value: _keys!['npub'],
            icon: Icons.public,
            onTap: () => _copyToClipboard(_keys!['npub'], 'Public key'),
          ),
          const SizedBox(height: 16),

          // Seed Phrase Card
          _buildKeyCard(
            title: 'Seed Phrase',
            subtitle: 'Your recovery mnemonic (keep this secure!)',
            value: _keys!['mnemonic'],
            icon: Icons.security,
            onTap: () => _copyToClipboard(_keys!['mnemonic'], 'Seed phrase'),
            isSecret: true,
          ),
          const SizedBox(height: 24),

          // Security Warning
          _buildSecurityWarning(),
          const SizedBox(height: 24),

          // Advanced Section
          _buildSectionHeader('Advanced'),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Regenerate Keys'),
            subtitle: const Text('Generate new seed phrase (will lose current identity)'),
            onTap: _showRegenerateConfirmation,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About NIP-06'),
            subtitle: const Text('Learn about Nostr key derivation'),
            onTap: _showNip06Info,
          ),
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
                'Security Warning',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your seed phrase is your master key. Never share it with anyone. If you lose it, you cannot recover your identity. Store it safely offline.',
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
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NIP-06 defines how to derive Nostr keys from a mnemonic seed phrase.'),
              SizedBox(height: 8),
              Text('Derivation Path: m/44\'/1237\'/1989\'/0/0'),
              SizedBox(height: 8),
              Text('• 44\': BIP44 standard'),
              Text('• 1237\': Nostr coin type'),
              Text('• 1989\': Account index'),
              Text('• 0: Change (external)'),
              Text('• 0: Address index'),
              SizedBox(height: 8),
              Text('This ensures compatibility with other Nostr clients that follow NIP-06.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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
        content: const Text(
          'This will generate a new seed phrase and delete your current identity. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _regenerateKeys();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
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
          const SnackBar(
            content: Text('New keys generated successfully'),
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