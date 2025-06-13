import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/election.dart';
import '../providers/voting_provider.dart';
import '../generated/app_localizations.dart';

class VotingScreen extends StatefulWidget {
  final Election election;
  final Candidate candidate;

  const VotingScreen({
    super.key,
    required this.election,
    required this.candidate,
  });

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VotingProvider>().initializeVoting(
        widget.election,
        widget.candidate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).castVote),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<VotingProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Election Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).electionSection,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.election.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Candidate Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).yourChoiceSection,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.candidate.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Voting Process Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).votingProcessSection,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildProcessStep(
                          context,
                          AppLocalizations.of(context).generateNonceStep,
                          provider.currentStep >= VotingStep.generateNonce,
                          provider.currentStep == VotingStep.generateNonce && provider.isLoading,
                        ),
                        _buildProcessStep(
                          context,
                          AppLocalizations.of(context).sendBlindedNonceStep,
                          provider.currentStep >= VotingStep.sendBlindedNonce,
                          provider.currentStep == VotingStep.sendBlindedNonce && provider.isLoading,
                        ),
                        _buildProcessStep(
                          context,
                          AppLocalizations.of(context).waitForSignatureStep,
                          provider.currentStep >= VotingStep.waitForSignature,
                          provider.currentStep == VotingStep.waitForSignature && provider.isLoading,
                        ),
                        _buildProcessStep(
                          context,
                          AppLocalizations.of(context).castVote,
                          provider.currentStep >= VotingStep.castVote,
                          provider.currentStep == VotingStep.castVote && provider.isLoading,
                        ),
                        _buildProcessStep(
                          context,
                          AppLocalizations.of(context).voteCompleteStep,
                          provider.currentStep == VotingStep.complete,
                          false,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Error Display
                if (provider.error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Action Buttons
                if (provider.currentStep == VotingStep.initial)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: provider.isLoading ? null : () => provider.startVoting(),
                      icon: const Icon(Icons.how_to_vote),
                      label: Text(AppLocalizations.of(context).startVotingProcess),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),

                if (provider.currentStep == VotingStep.complete)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).voteCastSuccess,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context).voteRecordedMessage,
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.popUntil(
                            context, 
                            (route) => route.isFirst,
                          ),
                          child: Text(AppLocalizations.of(context).returnToElections),
                        ),
                      ),
                    ],
                  ),

                if (provider.error != null && provider.currentStep != VotingStep.complete)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : () => provider.retryCurrentStep(),
                      child: Text(AppLocalizations.of(context).retry),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProcessStep(BuildContext context, String title, bool isCompleted, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(
                    isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isCompleted 
                        ? Colors.green 
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isCompleted 
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: isLoading ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}