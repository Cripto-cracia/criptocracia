import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/election_provider.dart';
import 'providers/results_provider.dart';
import 'screens/elections_screen.dart';
import 'screens/results_screen.dart';

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
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAppInfo(),
            tooltip: 'App Info',
          ),
        ],
      ),
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
