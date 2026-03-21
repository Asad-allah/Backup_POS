import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as app;

/// Widget for displaying a transaction in lists
class TransactionTile extends StatelessWidget {
  final app.Transaction transaction;
  final bool showReentryButton;
  final VoidCallback? onReentry;
  final VoidCallback? onViewReceipt;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.showReentryButton = false,
    this.onReentry,
    this.onViewReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final syncDateFormat = DateFormat('MMM d, h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            transaction.transactionNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            transaction.isPending
                                ? Icons.pending_actions
                                : Icons.check_circle,
                            color: transaction.isPending
                                ? Colors.orange
                                : Colors.green,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(transaction.date),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${transaction.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${transaction.itemCount} items',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),

            // Synced date (for history)
            if (transaction.isSynced && transaction.syncedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Synced: ${syncDateFormat.format(transaction.syncedAt!)}',
                style: TextStyle(color: Colors.green[700], fontSize: 13),
              ),
            ],

            const SizedBox(height: 12),

            // Action button
            if (showReentryButton && onReentry != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onReentry,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Re-enter Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else if (onViewReceipt != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewReceipt,
                  icon: const Icon(Icons.receipt),
                  label: const Text('View Receipt'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
