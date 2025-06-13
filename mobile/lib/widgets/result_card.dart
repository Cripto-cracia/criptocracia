import 'package:flutter/material.dart';
import '../models/election.dart';
import '../generated/app_localizations.dart';

class ResultCard extends StatelessWidget {
  final Candidate candidate;
  final int totalVotes;
  final double percentage;
  final int rank;
  final bool isWinner;

  const ResultCard({
    super.key,
    required this.candidate,
    required this.totalVotes,
    required this.percentage,
    required this.rank,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isWinner ? 4 : 2,
      color: isWinner 
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Rank Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getRankColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      rank.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Candidate Avatar
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person,
                    size: 25,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Candidate Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              candidate.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isWinner 
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          if (isWinner)
                            Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 20,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Vote Count and Percentage
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${candidate.votes}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isWinner 
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).votesLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress Bar
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isWinner 
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    if (totalVotes > 0)
                      Text(
                        AppLocalizations.of(context).voteRatioDisplay(candidate.votes, totalVotes),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: totalVotes > 0 ? percentage / 100 : 0,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isWinner 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  minHeight: 6,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(BuildContext context) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.brown[400]!;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}