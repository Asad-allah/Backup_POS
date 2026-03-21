import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../providers/transaction_provider.dart';

class ReentryScreen extends StatefulWidget {
  final int transactionId;

  const ReentryScreen({super.key, this.transactionId = 0});

  @override
  State<ReentryScreen> createState() => _ReentryScreenState();
}

class _ReentryScreenState extends State<ReentryScreen> {
  int _manualIndex = -1;

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TransactionProvider>().loadTransactionItems(
          widget.transactionId,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<TransactionProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = provider.currentItems;
            if (items.isEmpty && widget.transactionId != 0) {
              return const Center(
                child: Text(
                  'No items found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            // Determine which item to show
            int indexToShow = _manualIndex;
            if (indexToShow == -1 || indexToShow >= items.length) {
              // Default to first pending item
              indexToShow = items.indexWhere((i) => !i.reEntered);
            }

            // If all done (indexToShow == -1 meaning no pending found and not manual), show completion
            if (indexToShow == -1 && items.every((i) => i.reEntered)) {
              return _buildCompletionState(context, provider);
            }

            // If we are in "all done" state but manual browsing?
            // If indexToShow is -1 but items exist and all reentered, we might want to let user browse history?
            // Let's stick to simple logic: If all reentered and user isn't manually browsing, show completion.
            // If user manually navigated, show that item.

            if (indexToShow == -1 && items.isNotEmpty) {
              indexToShow = 0; // Fallback to first if all done
              if (items.every((i) => i.reEntered) && _manualIndex == -1) {
                return _buildCompletionState(context, provider);
              }
            }

            final currentItem = items[indexToShow];
            final totalItems = items.length;
            final progress =
                (items.where((i) => i.reEntered).length) / totalItems;
            final isDone = currentItem.reEntered;

            return Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCircleBtn(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      Text(
                        '#${widget.transactionId} (${indexToShow + 1}/$totalItems)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                      ),
                      _buildCircleBtn(
                        Icons.list,
                        onTap: () {
                          // For now reset manual index
                          setState(() => _manualIndex = -1);
                        },
                      ),
                    ],
                  ),
                ),

                // Progress
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white10,
                      color: progress == 1.0
                          ? Colors.greenAccent
                          : const Color(0xFFECECEC),
                      minHeight: 8,
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Status Banner
                      if (isDone)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.greenAccent),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ITEM RE-ENTERED',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Barcode (Hide/Show logic)
                      if (!isDone)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              BarcodeWidget(
                                barcode: Barcode.code128(),
                                data: currentItem.barcode,
                                height: 80,
                                drawText: false,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                currentItem.barcode,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Info Card
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(16),
                          border: isDone
                              ? Border.all(
                                  color: Colors.greenAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                )
                              : null,
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(
                                currentItem.productName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${currentItem.quantity} x \$${currentItem.unitPrice}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              trailing: Text(
                                '\$${currentItem.totalPrice}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Prev
                      _buildCircleBtn(
                        Icons.chevron_left,
                        onTap: indexToShow > 0
                            ? () {
                                setState(() => _manualIndex = indexToShow - 1);
                              }
                            : null,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isDone
                              ? null
                              : () async {
                                  await provider.markItemDone(currentItem.id!);
                                  // Auto advance
                                  if (indexToShow < items.length - 1) {
                                    setState(
                                      () => _manualIndex = indexToShow + 1,
                                    );
                                  } else {
                                    setState(
                                      () => _manualIndex = -1,
                                    ); // Check completion
                                  }
                                },
                          icon: Icon(isDone ? Icons.check : Icons.input),
                          label: Text(isDone ? 'DONE' : 'MARK ENTERED'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDone
                                ? Colors.green.withValues(alpha: 0.2)
                                : const Color(0xFFECECEC),
                            foregroundColor: isDone
                                ? Colors.greenAccent
                                : Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Next
                      _buildCircleBtn(
                        Icons.chevron_right,
                        onTap: indexToShow < items.length - 1
                            ? () {
                                setState(() => _manualIndex = indexToShow + 1);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompletionState(
    BuildContext context,
    TransactionProvider provider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.greenAccent),
          const SizedBox(height: 24),
          const Text(
            'Re-entry Complete!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await provider.markTransactionSynced(widget.transactionId);
              nav.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('FINALIZE & MOVE TO HISTORY'),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1.0,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
