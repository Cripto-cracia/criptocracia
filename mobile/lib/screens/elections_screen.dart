import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/election.dart';
import '../providers/election_provider.dart';
import '../widgets/election_card.dart';
import 'election_detail_screen.dart';
import '../generated/app_localizations.dart';

class ElectionsScreen extends StatefulWidget {
  const ElectionsScreen({super.key});

  @override
  State<ElectionsScreen> createState() => _ElectionsScreenState();
}

class _ElectionsScreenState extends State<ElectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ElectionProvider>().loadElections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ElectionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
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
                    AppLocalizations.of(context).errorWithMessage(provider.error!),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadElections(),
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            );
          }

          if (provider.elections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.how_to_vote_outlined,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context).noElectionsFound,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).noActiveElectionsFound,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.elections.length,
            itemBuilder: (context, index) {
              final election = provider.elections[index];
              return ElectionCard(
                election: election,
                onTap: () => _navigateToElectionDetail(election),
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToElectionDetail(Election election) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ElectionDetailScreen(election: election),
      ),
    );
  }
}
