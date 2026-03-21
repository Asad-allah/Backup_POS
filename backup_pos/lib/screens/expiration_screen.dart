import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../providers/expiration_provider.dart';
import '../providers/product_provider.dart';
import '../models/expiration_date.dart';

class ExpirationScreen extends StatefulWidget {
  const ExpirationScreen({super.key});

  @override
  State<ExpirationScreen> createState() => _ExpirationScreenState();
}

class _ExpirationScreenState extends State<ExpirationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpirationProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddSheet({ExpirationDate? initialItem}) {
    try {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AddExpirationSheet(initialItem: initialItem),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open sheet: $e')),
      );
    }
  }

  void _showReminderSettings() {
    final provider = context.read<ExpirationProvider>();
    final controller =
        TextEditingController(text: provider.reminderDays.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active,
                color: Colors.orangeAccent, size: 22),
            const SizedBox(width: 8),
            const Text('Reminder Settings',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notify me this many days before expiry:',
              style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                suffixText: 'days',
                suffixStyle:
                    const TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFB0B0B0))),
          ),
          ElevatedButton(
            onPressed: () {
              final days = int.tryParse(controller.text) ?? 7;
              provider.setReminderDays(days);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Expiry Dates'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<ExpirationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount > 0) {
                return TextButton.icon(
                  icon:
                      const Icon(Icons.done_all, color: Colors.greenAccent, size: 18),
                  label: const Text('Read all',
                      style:
                          TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  onPressed: () => provider.markAllAsRead(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box, color: Colors.greenAccent, size: 26),
            tooltip: 'Add Expiry Date',
            onPressed: _showAddSheet,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined,
                color: Color(0xFFB0B0B0), size: 22),
            tooltip: 'Reminder settings',
            onPressed: _showReminderSettings,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFB0B0B0)),
            color: const Color(0xFF2C2C2C),
            onSelected: (value) async {
              final provider = context.read<ExpirationProvider>();
              if (value == 'export') {
                final path = await provider.exportCsv();
                if (!context.mounted) return;
                
                if (path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Exported to: $path'),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else {
                  final error = provider.error;
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $error')),
                    );
                  }
                }
              } else if (value == 'import') {
                final result = await provider.importCsv();
                if (!context.mounted) return;
                
                if (result != null) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF2C2C2C),
                      title: const Text('Import Complete', style: TextStyle(color: Colors.white)),
                      content: Text(
                        'Total CSV rows: ${result.totalRows}\n\n'
                        'Imported / Updated: ${result.importedCount} dates\n'
                        'Skipped (Product not found): ${result.skippedNotFoundCount} dates',
                        style: const TextStyle(color: Color(0xFFB0B0B0)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK', style: TextStyle(color: Colors.greenAccent)),
                        ),
                      ],
                    ),
                  );
                } else {
                  final error = provider.error;
                  if (error != null && error.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Import failed: $error')),
                    );
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Import CSV', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Export CSV', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ExpirationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.allItems.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Summary header
              _buildSummaryHeader(provider),
              const SizedBox(height: 8),
              
              // Internal Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search product or barcode...',
                    hintStyle: const TextStyle(color: Color(0xFF808080)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF808080), size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                ),
              ),
              const SizedBox(height: 8),
              
              if (_searchQuery.isNotEmpty)
                Expanded(
                  child: _buildItemList(
                    provider.allItems.where((item) {
                      final n = (item.productName ?? '').toLowerCase();
                      final b = item.barcode.toLowerCase();
                      final cat = provider.getCategory(b).toLowerCase();
                      final ds = DateFormat('yyyy-MM-dd').format(item.expiryDate);
                      return n.contains(_searchQuery) ||
                             b.contains(_searchQuery) ||
                             cat.contains(_searchQuery) ||
                             ds.contains(_searchQuery);
                    }).toList(),
                    'search',
                  ),
                )
              else ...[
                // Tab bar
                Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF808080),
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${provider.expiredItems.length}'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${provider.expiringSoonItems.length}'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${provider.okItems.length}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildItemList(provider.expiredItems, 'expired'),
                    _buildItemList(provider.expiringSoonItems, 'soon'),
                    _buildItemList(provider.okItems, 'ok'),
                  ],
                ),
              ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.event_busy,
                  size: 40, color: Color(0xFF404040)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No expiration dates yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "Add Expiry" to scan a product\nand record its expiration date',
              style: TextStyle(color: Color(0xFF808080), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Expiry Date',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFECECEC),
                foregroundColor: const Color(0xFF121212),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(ExpirationProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          _SummaryChip(
            count: provider.expiredItems.length,
            label: 'Expired',
            color: Colors.redAccent,
            icon: Icons.error_outline,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            count: provider.expiringSoonItems.length,
            label: 'Soon',
            color: Colors.orangeAccent,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            count: provider.okItems.length,
            label: 'OK',
            color: Colors.greenAccent,
            icon: Icons.check_circle_outline,
          ),
          const Spacer(),
          Consumer<ExpirationProvider>(
            builder: (_, p, _) => Text(
              '${p.reminderDays}d reminder',
              style:
                  const TextStyle(color: Color(0xFF808080), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(List<ExpirationDate> items, String type) {
    if (items.isEmpty) {
      final msg = type == 'expired'
          ? 'No expired items 🎉'
          : type == 'soon'
              ? 'Nothing expiring soon 👍'
              : 'No safe items tracked';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'expired'
                  ? Icons.celebration
                  : type == 'soon'
                      ? Icons.thumb_up
                      : Icons.inventory_2_outlined,
              size: 40,
              color: const Color(0xFF404040),
            ),
            const SizedBox(height: 12),
            Text(msg,
                style:
                    const TextStyle(color: Color(0xFF808080), fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ExpiryItemCard(
          item: item,
          type: type,
          reminderDays: context.read<ExpirationProvider>().reminderDays,
          onDismissed: () {
            context.read<ExpirationProvider>().deleteExpiration(item.id!);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed: ${item.productName ?? item.barcode}'),
                backgroundColor: const Color(0xFF2C2C2C),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onUpdate: () => _showAddSheet(initialItem: item),
          onTap: () {
            if (!item.isRead) {
              context.read<ExpirationProvider>().markAsRead(item.id!);
            }
          },
        );
      },
    );
  }
}

// ==================== SUMMARY CHIP ====================

class _SummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ADD EXPIRATION SHEET ====================

class _AddExpirationSheet extends StatefulWidget {
  final ExpirationDate? initialItem;
  
  const _AddExpirationSheet({this.initialItem});

  @override
  State<_AddExpirationSheet> createState() => _AddExpirationSheetState();
}

class _AddExpirationSheetState extends State<_AddExpirationSheet> {
  final _barcodeController = TextEditingController();
  final _dateController = TextEditingController();
  final _searchController = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _dateNode = FocusNode();
  String? _productName;
  bool _scanning = false;
  String? _error;
  MobileScannerController? _scannerController;
  bool _saving = false;
  int _savedCount = 0;
  String? _lastSavedName;
  Timer? _debounce;
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _barcodeController.text = widget.initialItem!.barcode;
      _productName = widget.initialItem!.productName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dateNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _dateController.dispose();
    _searchController.dispose();
    _barcodeFocus.dispose();
    _dateNode.dispose();
    _scannerController?.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<ProductProvider>().searchProducts(query);
        setState(() {
          _showSearchResults = query.isNotEmpty;
        });
      }
    });
  }

  void _startScan() {
    try {
      setState(() {
        _scanning = true;
        _scannerController = MobileScannerController();
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _error = 'Camera not available';
      });
    }
  }

  void _stopScan() {
    _scannerController?.dispose();
    setState(() {
      _scanning = false;
      _scannerController = null;
    });
  }

  void _onBarcodeScanned(String barcode) async {
    HapticFeedback.mediumImpact();
    _stopScan();
    _barcodeController.text = barcode;
    await _lookupProduct(barcode);
    // Auto-focus date field for fastest flow
    _dateNode.requestFocus();
  }

  Future<void> _lookupProduct(String barcode) async {
    if (!mounted) return;
    final product =
        await context.read<ProductProvider>().getByBarcode(barcode);
    if (mounted) {
      setState(() {
        _productName = product?.name;
      });
    }
  }

  /// Parse YYMMDD or YYMM input into a DateTime
  DateTime? _parseDate(String raw) {
    final digits = raw.replaceAll('/', '');
    if (digits.length < 4) return null;

    try {
      final yy = int.parse(digits.substring(0, 2));
      final mm = int.parse(digits.substring(2, 4));
      final dd =
          digits.length >= 6 ? int.parse(digits.substring(4, 6)) : 1;

      final year = 2000 + yy;
      if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
      return DateTime(year, mm, dd);
    } catch (_) {
      return null;
    }
  }

  String _formatPreview(String raw) {
    final date = _parseDate(raw);
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd (EEEE)').format(date);
  }

  void _save() async {
    if (_saving) return;

    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) {
      setState(() => _error = 'Scan or type a barcode first');
      return;
    }

    final date = _parseDate(_dateController.text);
    if (date == null) {
      setState(() => _error = 'Enter date as YYMM or YYMMDD');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await context.read<ExpirationProvider>().addExpiration(
          barcode: barcode,
          productName: _productName,
          expiryDate: date,
        );

    if (!mounted) return;

    // RAPID-FIRE: Don't close! Clear fields and restart scanner for next item
    HapticFeedback.heavyImpact();
    setState(() {
      _savedCount++;
      _lastSavedName = _productName ?? barcode;
      _saving = false;
      _productName = null;
      _error = null;
      _barcodeController.clear();
      _dateController.clear();
    });

    // Auto-restart scanner for next item
    _startScan();
  }

  void _close() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    try {
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;

      return Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title row
            Row(
              children: [
                const Icon(Icons.event_note,
                    color: Colors.orangeAccent, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Add Expiry Date',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Quick toggle: scan vs type barcode
                TextButton.icon(
                  onPressed: _scanning ? _stopScan : _startScan,
                  icon: Icon(
                    _scanning ? Icons.keyboard : Icons.qr_code_scanner,
                    size: 18,
                    color: const Color(0xFFB0B0B0),
                  ),
                  label: Text(
                    _scanning ? 'Type' : 'Scan',
                    style: const TextStyle(
                        color: Color(0xFFB0B0B0), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search products by name...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white54,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            if (_showSearchResults) ...[
              // Search Results
              Consumer<ProductProvider>(
                builder: (context, provider, _) {
                  if (provider.searchResults.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No products found.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.searchResults.length,
                    itemBuilder: (context, index) {
                      final product = provider.searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2, color: Colors.white54),
                        title: Text(
                          product.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          product.barcode,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onTap: () {
                          // Select product and stop searching/scanning
                          _barcodeController.text = product.barcode;
                          _productName = product.name;
                          _searchController.clear();
                          _showSearchResults = false;
                          _stopScan();
                          
                          // Auto focus date field
                          _dateNode.requestFocus();
                        },
                      );
                    },
                  );
                },
              ),
            ] else ...[
              // Scanner area
              if (_scanning)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: _scannerController!,
                          onDetect: (capture) {
                            final barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty &&
                                barcodes.first.rawValue != null) {
                              _onBarcodeScanned(barcodes.first.rawValue!);
                            }
                          },
                        ),
                        // Scan overlay
                        Center(
                          child: Container(
                            width: 200,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        // Hint
                        const Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Text(
                            'Point camera at barcode',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

            // Manual barcode input (always visible when not scanning)
            if (!_scanning) ...[
              TextField(
                controller: _barcodeController,
                focusNode: _barcodeFocus,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type barcode number',
                  hintStyle: const TextStyle(color: Color(0xFF808080)),
                  prefixIcon: const Icon(Icons.barcode_reader,
                      color: Color(0xFF808080), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onChanged: (val) async {
                  if (val.trim().length > 3) {
                    await _lookupProduct(val.trim());
                  }
                },
                onSubmitted: (_) => _dateNode.requestFocus(),
              ),
            ],

            // Scanned barcode display (when scanning returned)
            if (!_scanning && _barcodeController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code,
                        color: Color(0xFF808080), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _barcodeController.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'monospace'),
                      ),
                    ),
                    if (_productName != null)
                      Flexible(
                        child: Text(
                          _productName!,
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Product name when no barcode shown yet
            if (_scanning && _productName != null) ...[
              const SizedBox(height: 8),
              Text(
                '✓ ${_productName!}',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],

            const SizedBox(height: 16),

            // Date input label
            const Text(
              'Expiry Date',
              style: TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),

            // Date input
            TextField(
              controller: _dateController,
              focusNode: _dateNode,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
                _DateInputFormatter(),
              ],
              decoration: InputDecoration(
                hintText: 'YY/MM/DD',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.15),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),

            // Date preview
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatPreview(_dateController.text),
                  style: const TextStyle(
                      color: Colors.greenAccent, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _dateController.text.replaceAll('/', '').length < 6
                      ? 'day = 01 auto'
                      : '',
                  style: const TextStyle(
                      color: Color(0xFF808080), fontSize: 11),
                ),
              ],
            ),

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                  ],
                ),
              ),
            ],

            // Saved counter (rapid-fire feedback)
            if (_savedCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$_savedCount saved',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    if (_lastSavedName != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '• $_lastSavedName',
                          style: TextStyle(
                              color: Colors.greenAccent.withValues(alpha: 0.7),
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Buttons row
            Row(
              children: [
                // Done button (close)
                if (_savedCount > 0)
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _close,
                        icon: const Icon(Icons.done, size: 20),
                        label: Text('Done ($_savedCount)',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          side: BorderSide(
                              color: Colors.greenAccent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                if (_savedCount > 0) const SizedBox(width: 10),
                // Save & Next button
                Expanded(
                  flex: _savedCount > 0 ? 2 : 1,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF121212)),
                            )
                          : Icon(
                              _savedCount > 0 ? Icons.navigate_next : Icons.save,
                              size: 20),
                      label: Text(
                          _saving
                              ? 'Saving...'
                              : _savedCount > 0
                                  ? 'Save & Next'
                                  : 'Save Expiry Date',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFECECEC),
                        foregroundColor: const Color(0xFF121212),
                        disabledBackgroundColor: const Color(0xFF3C3C3C),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
    } catch (e, stack) {
      return Material(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Build Error: $e\n\n$stack',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      );
    }
  }
}

// ==================== DATE FORMATTER ====================
/// Auto-formats typed digits as YY/MM/DD (like credit card expiry input)
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ==================== ITEM CARD ====================

class _ExpiryItemCard extends StatelessWidget {
  final ExpirationDate item;
  final String type;
  final int reminderDays;
  final VoidCallback onDismissed;
  final VoidCallback onUpdate;
  final VoidCallback onTap;

  const _ExpiryItemCard({
    required this.item,
    required this.type,
    required this.reminderDays,
    required this.onDismissed,
    required this.onUpdate,
    required this.onTap,
  });

  Color get _accentColor {
    switch (type) {
      case 'expired':
        return Colors.redAccent;
      case 'soon':
        return Colors.orangeAccent;
      default:
        return Colors.greenAccent;
    }
  }

  IconData get _statusIcon {
    switch (type) {
      case 'expired':
        return Icons.error;
      case 'soon':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle;
    }
  }

  String get _statusText {
    final days = item.daysRemaining;
    if (days < 0) return '${-days}d ago';
    if (days == 0) return 'TODAY!';
    if (days == 1) return 'Tomorrow';
    return '${days}d left';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onUpdate();
          return false;
        }
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Text('Delete?',
                style: TextStyle(color: Colors.white)),
            content: Text(
              'Remove expiry date for ${item.productName ?? item.barcode}?',
              style: const TextStyle(color: Color(0xFFB0B0B0)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFFB0B0B0))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.edit, color: Colors.blueAccent, size: 20),
            SizedBox(width: 8),
            Text('Update', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          ],
        ),
      ),
      onDismissed: (_) => onDismissed(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: _accentColor, width: 3),
            ),
          ),
          child: Row(
            children: [
              // Status icon with unread indicator
              Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_statusIcon, color: _accentColor, size: 18),
                  ),
                  if (!item.isRead)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF2C2C2C), width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName ?? 'Unknown Product',
                      style: TextStyle(
                        color: item.isRead
                            ? const Color(0xFFD0D0D0)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight:
                            item.isRead ? FontWeight.w400 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.barcode,
                      style: const TextStyle(
                        color: Color(0xFF707070),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              // Date and countdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateFormat.format(item.expiryDate),
                    style: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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
}
