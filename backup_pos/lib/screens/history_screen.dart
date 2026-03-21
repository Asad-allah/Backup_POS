import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../providers/transaction_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadSynced();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transaction History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  InkWell(
                    onTap: () async {
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.amber,
                                onPrimary: Colors.black,
                                surface: Color(0xFF2C2C2C),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        if (!context.mounted) return;
                        context.read<TransactionProvider>().applyFilters(
                          dateRange: picked,
                        );
                      }
                    },
                    child: _buildFilterChip('Date Range', Icons.calendar_today),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('Amount', Icons.attach_money),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cashier', Icons.person),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECECEC),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFECECEC).withValues(alpha: 0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () async {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Exporting CSV... (Mock)'),
                          ),
                        );
                        // Future improvement: Call database helper to export all transactions to CSV
                      },
                      child: Row(
                        children: const [
                          Icon(
                            Icons.file_upload,
                            size: 18,
                            color: Color(0xFF121212),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'EXPORT ALL',
                            style: TextStyle(
                              color: Color(0xFF121212),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // List
            Expanded(
              child: Consumer<TransactionProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.syncedTransactions.isEmpty) {
                    return const Center(
                      child: Text(
                        'No transactions found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      100,
                    ), // Bottom padding for nav bar
                    itemCount: provider.syncedTransactions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final trx = provider.syncedTransactions[index];
                      return _TransactionCard(transaction: trx)
                          .animate()
                          .fade(duration: 400.ms, delay: (50 * index).ms)
                          .slideX(
                            begin: 0.2,
                            end: 0,
                            curve: Curves.easeOutQuad,
                          );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // Dark mode bg
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFECECEC)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatefulWidget {
  final Transaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard> {
  bool _isExpanded = false;
  bool _loadingItems = false;
  List<TransactionItem> _items = [];

  Future<void> _toggleExpand() async {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      return;
    }

    if (_items.isEmpty) {
      setState(() => _loadingItems = true);
      try {
        final items = await context
            .read<TransactionProvider>()
            .fetchTransactionItems(widget.transaction.id!);
        if (!context.mounted) return;
        if (mounted) {
          setState(() {
            _items = items;
            _loadingItems = false;
            _isExpanded = true;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _loadingItems = false);
      }
    } else {
      setState(() => _isExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('hh:mm a');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: const Color(0xFFECECEC), width: 6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFFECECEC,
                              ).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.check_circle,
                                size: 12,
                                color: Color(0xFFECECEC),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SYNCED',
                                style: TextStyle(
                                  color: Color(0xFFECECEC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${widget.transaction.transactionNumber}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${widget.transaction.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(widget.transaction.date)} • ${widget.transaction.itemCount} Items',
                      style: const TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Color(0xFFECECEC),
                  ),
                ),
              ],
            ),
          ),

          if (_isExpanded || _loadingItems)
            Container(
              color: Colors.black12,
              constraints: const BoxConstraints(maxHeight: 300),
              child: _loadingItems
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Scrollbar(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Colors.white10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  '${item.quantity}x',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.productName,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                Text(
                                  '\$${item.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),

          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  _isExpanded ? Icons.expand_less : Icons.list,
                  _isExpanded ? 'Hide Items' : 'Show Items',
                  onTap: _toggleExpand,
                ),
                Container(width: 1, height: 20, color: Colors.white10),
                _buildActionButton(
                  Icons.receipt_long,
                  'Receipt',
                  onTap: _openReceipt,
                ),
                Container(width: 1, height: 20, color: Colors.white10),
                _buildActionButton(Icons.print, 'Reprint', onTap: _reprint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReceipt() async {
    if (widget.transaction.pdfPath != null) {
      // Use open_file or similar if available, or just re-generate specifically for viewing
      // For now, let's re-generate since we have the data, or check if path exists
      // Simpler: Just re-generate and open
      _reprint();
    } else {
      _reprint();
    }
  }

  Future<void> _reprint() async {
    final messenger = ScaffoldMessenger.of(context);
    final transactionProvider = context.read<TransactionProvider>();

    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Generating Receipt...')),
      );

      // Need items
      List<TransactionItem> items = _items;
      if (items.isEmpty) {
        items = await transactionProvider.fetchTransactionItems(
          widget.transaction.id!,
        );
      }

      // Generate PDF
      final pdfGen = transactionProvider.pdfGenerator;
      await pdfGen.generateReceipt(widget.transaction, items);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Receipt Generated')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildActionButton(
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.grey),
      label: Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory),
    );
  }
}
