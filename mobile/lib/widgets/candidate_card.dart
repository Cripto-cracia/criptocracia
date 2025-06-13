import 'package:flutter/material.dart';
import '../models/election.dart';
import '../generated/app_localizations.dart';

class CandidateCard extends StatelessWidget {
  final Candidate candidate;
  final VoidCallback? onTap;
  final bool showVoteButton;

  const CandidateCard({
    super.key,
    required this.candidate,
    this.onTap,
    this.showVoteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Candidate Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Candidate Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (candidate.votes > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.how_to_vote,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context).votesCount(candidate.votes),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Vote Button
              if (showVoteButton && onTap != null) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.how_to_vote, size: 18),
                  label: Text(AppLocalizations.of(context).vote),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}