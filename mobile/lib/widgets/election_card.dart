import 'package:flutter/material.dart';
import '../models/election.dart';
import '../generated/app_localizations.dart';

class ElectionCard extends StatelessWidget {
  final Election election;
  final VoidCallback? onTap;

  const ElectionCard({super.key, required this.election, this.onTap});

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      election.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(context),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).candidatesCountShort(election.candidates.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeRange(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color chipColor;
    String label;
    IconData icon;

    switch (election.status.toLowerCase()) {
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
        label = election.status;
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

  String _formatTimeRange() {
    final startDate = election.startTime;
    final endDate = election.endTime;

    if (startDate.day == endDate.day &&
        startDate.month == endDate.month &&
        startDate.year == endDate.year) {
      return '${_formatTime(startDate)} - ${_formatTime(endDate)}';
    } else {
      return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
