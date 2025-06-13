import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/election.dart';
import '../providers/voting_provider.dart';
import '../widgets/candidate_card.dart';
import 'voting_screen.dart';
import '../generated/app_localizations.dart';
import '../services/selected_election_service.dart';

class ElectionDetailScreen extends StatefulWidget {
  final Election election;

  const ElectionDetailScreen({super.key, required this.election});

  @override
  State<ElectionDetailScreen> createState() => _ElectionDetailScreenState();
}

class _ElectionDetailScreenState extends State<ElectionDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Save this election as the selected one when the user opens it
    _saveSelectedElection();
  }

  Future<void> _saveSelectedElection() async {
    try {
      await SelectedElectionService.setSelectedElection(widget.election);
      debugPrint('💾 Saved selected election: ${widget.election.name} (${widget.election.id})');
    } catch (e) {
      debugPrint('❌ Error saving selected election: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive =
        widget.election.status.toLowerCase() == 'open' &&
        now.isAfter(widget.election.startTime) &&
        now.isBefore(widget.election.endTime);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.election.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Election Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.election.name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildStatusChip(context),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).electionStartLabel(_formatDateTime(widget.election.startTime)),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                AppLocalizations.of(context).electionEndLabel(_formatDateTime(widget.election.endTime)),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Candidates Section
            Text(
              AppLocalizations.of(context).candidatesCount(widget.election.candidates.length),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (widget.election.candidates.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    AppLocalizations.of(context).noCandidatesForElection,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              ...widget.election.candidates.map(
                (candidate) => CandidateCard(
                  candidate: candidate,
                  onTap: isActive ? () => _navigateToVoting(candidate) : null,
                  showVoteButton: isActive,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color chipColor;
    String label;
    IconData icon;

    switch (widget.election.status.toLowerCase()) {
      case 'open':
        chipColor = Colors.orange;
        label = AppLocalizations.of(context).statusOpen;
        icon = Icons.schedule;
        break;
      case 'in-progress':
        chipColor = Colors.green;
        label = AppLocalizations.of(context).statusInProgress;
        icon = Icons.radio_button_checked;
        break;
      case 'finished':
        chipColor = Colors.blue;
        label = AppLocalizations.of(context).statusFinished;
        icon = Icons.check_circle_outline;
        break;
      case 'canceled':
        chipColor = Colors.red;
        label = AppLocalizations.of(context).statusCanceled;
        icon = Icons.cancel_outlined;
        break;
      default:
        chipColor = Colors.grey;
        label = widget.election.status;
        icon = Icons.info_outline;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: chipColor,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToVoting(Candidate candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => VotingProvider(),
          child: VotingScreen(election: widget.election, candidate: candidate),
        ),
      ),
    );
  }
}
