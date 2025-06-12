import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/election_provider.dart';
import 'providers/results_provider.dart';
import 'screens/elections_screen.dart';
import 'screens/results_screen.dart';
import 'screens/settings_screen.dart';
import 'services/nostr_key_manager.dart';

void main(List<String> args) {
  AppConfig.parseArguments(args);
  runApp(const CriptocraciaApp());
}

class CriptocraciaApp extends StatelessWidget {
  const CriptocraciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ElectionProvider()),
        ChangeNotifierProvider(create: (_) => ResultsProvider()),
      ],
      child: MaterialApp(
        title: 'Criptocracia',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF03FFFE)),
          useMaterial3: true,
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize Nostr keys on first launch
    _initializeKeys();
  }

  Future<void> _initializeKeys() async {
    try {
      await NostrKeyManager.initializeKeysIfNeeded();
    } catch (e) {
      debugPrint('Error initializing Nostr keys: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const ElectionsScreen(),
      Consumer<ElectionProvider>(
        builder: (context, provider, child) {
          if (provider.elections.isNotEmpty) {
            return ResultsScreen(election: provider.elections.first);
          }
          return const Center(
            child: Text('Select an election to view results'),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (AppConfig.debugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () => _showDebugInfo(),
              tooltip: 'Debug Info',
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_vote),
            label: 'Elections',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.poll), label: 'Results'),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.how_to_vote,
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Criptocracia',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Trustless Electronic Voting',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.how_to_vote),
            title: const Text('Elections'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.poll),
            title: const Text('Results'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 1);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          if (AppConfig.debugMode) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Debug Info'),
              onTap: () {
                Navigator.pop(context);
                _showDebugInfo();
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              _showAppInfo();
            },
          ),
        ],
      ),
    );
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relay URL: ${AppConfig.relayUrl}'),
            Text('EC Public Key: ${AppConfig.ecPublicKey}'),
            Text('Debug Mode: ${AppConfig.debugMode}'),
            Text('Configured: ${AppConfig.isConfigured}'),
          ],
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

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Criptocracia'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A trustless electronic voting system using blind RSA signatures and the Nostr protocol.',
            ),
            SizedBox(height: 16),
            Text('Features:'),
            Text('• Anonymous voting with cryptographic proofs'),
            Text('• Real-time results via Nostr'),
            Text('• Decentralized vote collection'),
            Text('• Tamper-evident vote counting'),
          ],
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
}
