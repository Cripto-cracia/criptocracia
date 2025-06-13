import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/election.dart';
import '../providers/results_provider.dart';
import '../widgets/result_card.dart';
import '../generated/app_localizations.dart';

class ResultsScreen extends StatefulWidget {
  final Election election;

  const ResultsScreen({super.key, required this.election});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ResultsProvider>().startListening(widget.election.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(
            context,
          ).electionResultsTitle(widget.election.name),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<ResultsProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(
                  provider.isListening ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () {
                  if (provider.isListening) {
                    provider.stopListening();
                  } else {
                    provider.startListening(widget.election.id);
                  }
                },
                tooltip: provider.isListening
                    ? AppLocalizations.of(context).pauseUpdatesTooltip
                    : AppLocalizations.of(context).resumeUpdatesTooltip,
              );
            },
          ),
        ],
      ),
      body: Consumer<ResultsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.results.isEmpty) {
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
                    AppLocalizations.of(
                      context,
                    ).errorWithMessage(provider.error!),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        provider.startListening(widget.election.id),
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            );
          }

          final candidates = provider.getCandidatesWithVotes(widget.election);
          final totalVotes = provider.getTotalVotes();

          return RefreshIndicator(
            onRefresh: () => provider.refreshResults(widget.election.id),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.poll,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).electionSummarySection,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                context,
                                AppLocalizations.of(context).totalVotesLabel,
                                totalVotes.toString(),
                                Icons.how_to_vote,
                              ),
                              _buildSummaryItem(
                                context,
                                AppLocalizations.of(context).candidatesLabel,
                                candidates.length.toString(),
                                Icons.people,
                              ),
                              _buildSummaryItem(
                                context,
                                AppLocalizations.of(context).statusLabel,
                                provider.isListening
                                    ? AppLocalizations.of(context).liveStatus
                                    : AppLocalizations.of(context).pausedStatus,
                                provider.isListening
                                    ? Icons.radio_button_checked
                                    : Icons.pause,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Results Header
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context).resultsSection,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (provider.isListening)
                        Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context).liveStatus,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (candidates.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.poll_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context).noVotesRecordedYet,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...candidates.map((candidate) {
                      final percentage = totalVotes > 0
                          ? (candidate.votes / totalVotes * 100)
                          : 0.0;
                      final rank = candidates.indexOf(candidate) + 1;

                      return ResultCard(
                        candidate: candidate,
                        totalVotes: totalVotes,
                        percentage: percentage,
                        rank: rank,
                        isWinner: rank == 1 && totalVotes > 0,
                      );
                    }),

                  const SizedBox(height: 16),

                  // Last Update Info
                  if (provider.lastUpdate != null)
                    Center(
                      child: Text(
                        AppLocalizations.of(context).lastUpdatedLabel(
                          _formatLastUpdate(provider.lastUpdate!),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  String _formatLastUpdate(DateTime lastUpdate) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);

    if (difference.inSeconds < 60) {
      return AppLocalizations.of(context).timeFormatJustNow;
    } else if (difference.inMinutes < 60) {
      return AppLocalizations.of(
        context,
      ).timeFormatMinutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return AppLocalizations.of(
        context,
      ).timeFormatHoursAgo(difference.inHours);
    } else {
      return '${lastUpdate.day}/${lastUpdate.month} ${lastUpdate.hour}:${lastUpdate.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    context.read<ResultsProvider>().stopListening();
    super.dispose();
  }
}
