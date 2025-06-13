import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/election_provider.dart';
import 'providers/results_provider.dart';
import 'screens/elections_screen.dart';
import 'screens/results_screen.dart';
import 'screens/account_screen.dart';
import 'services/nostr_key_manager.dart';
import 'generated/app_localizations.dart';

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
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
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
          return Center(
            child: Text(AppLocalizations.of(context).selectElectionToViewResults),
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
              tooltip: AppLocalizations.of(context).debugInfo,
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.how_to_vote),
            label: AppLocalizations.of(context).navElections,
          ),
          BottomNavigationBarItem(icon: const Icon(Icons.poll), label: AppLocalizations.of(context).navResults),
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
                  AppLocalizations.of(context).appTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).appSubtitle,
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
            title: Text(AppLocalizations.of(context).navElections),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.poll),
            title: Text(AppLocalizations.of(context).navResults),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 1);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(AppLocalizations.of(context).navAccount),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountScreen()),
              );
            },
          ),
          if (AppConfig.debugMode) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: Text(AppLocalizations.of(context).debugInfo),
              onTap: () {
                Navigator.pop(context);
                _showDebugInfo();
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppLocalizations.of(context).navAbout),
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
        title: Text(AppLocalizations.of(context).debugInformation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).relayUrl(AppConfig.relayUrl)),
            Text(AppLocalizations.of(context).ecPublicKey(AppConfig.ecPublicKey)),
            Text(AppLocalizations.of(context).debugMode(AppConfig.debugMode.toString())),
            Text(AppLocalizations.of(context).configured(AppConfig.isConfigured.toString())),
          ],
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

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).appTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).aboutDescription,
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).features),
            Text(AppLocalizations.of(context).featureAnonymous),
            Text(AppLocalizations.of(context).featureRealtime),
            Text(AppLocalizations.of(context).featureDecentralized),
            Text(AppLocalizations.of(context).featureTamperEvident),
          ],
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
}
