import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/transaction.dart' as app;
import '../models/transaction_item.dart';
import '../services/database_helper.dart';
import '../services/pdf_generator.dart';

/// Provider for managing transactions
class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final PdfGenerator _pdfGenerator = PdfGenerator();

  List<app.Transaction> _pendingTransactions = [];
  List<app.Transaction> _syncedTransactions = [];
  List<app.Transaction> _filteredTransactions = []; // For display
  List<TransactionItem> _currentItems = [];
  int _pendingCount = 0;
  bool _isLoading = false;

  List<app.Transaction> get pendingTransactions => _pendingTransactions;
  List<app.Transaction> get syncedTransactions =>
      _filteredTransactions.isNotEmpty
      ? _filteredTransactions
      : _syncedTransactions; // Use filtered if active
  List<TransactionItem> get currentItems => _currentItems;
  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  PdfGenerator get pdfGenerator => _pdfGenerator;

  /// Initialize and load transactions
  Future<void> initialize() async {
    await loadPending();
    await loadSynced();
  }

  /// Load pending transactions
  Future<void> loadPending() async {
    _pendingTransactions = await _db.getTransactionsByStatus('pending');
    _pendingCount = _pendingTransactions.length;
    notifyListeners();
  }

  /// Load synced transactions
  Future<void> loadSynced() async {
    _syncedTransactions = await _db.getTransactionsByStatus('synced');
    _filteredTransactions = []; // Reset filter
    notifyListeners();
  }

  /// Apply filters to synced transactions
  void applyFilters({DateTimeRange? dateRange, double? minAmount}) {
    if (dateRange == null && minAmount == null) {
      _filteredTransactions = [];
    } else {
      _filteredTransactions = _syncedTransactions.where((txn) {
        bool matchesDate = true;
        bool matchesAmount = true;

        if (dateRange != null) {
          // Check if date is within range (inclusive)
          matchesDate =
              txn.date.isAfter(
                dateRange.start.subtract(const Duration(seconds: 1)),
              ) &&
              txn.date.isBefore(
                dateRange.end.add(const Duration(days: 1)),
              ); // Add 1 day to include end date fully
        }

        if (minAmount != null) {
          matchesAmount = txn.total >= minAmount;
        }

        return matchesDate && matchesAmount;
      }).toList();
    }
    notifyListeners();
  }

  /// Create a new transaction from cart items
  Future<app.Transaction> createTransaction(List<CartItem> cartItems) async {
    _isLoading = true;
    notifyListeners();

    try {
      final transactionNumber = await _db.generateTransactionNumber();
      final now = DateTime.now();

      // Calculate totals
      final total = cartItems.fold(0.0, (sum, item) => sum + item.total);
      final itemCount = cartItems.fold(0, (sum, item) => sum + item.quantity);

      // Create transaction
      final transaction = app.Transaction(
        transactionNumber: transactionNumber,
        date: now,
        total: total,
        itemCount: itemCount,
        status: 'pending',
      );

      // Create transaction items
      final items = cartItems
          .map(
            (cartItem) => TransactionItem(
              barcode: cartItem.barcode,
              productName: cartItem.name,
              quantity: cartItem.quantity,
              unitPrice: cartItem.unitPrice,
              totalPrice: cartItem.total,
            ),
          )
          .toList();

      // Save to database
      final txnId = await _db.createTransaction(transaction, items);

      // Generate PDF receipt
      final savedTransaction = transaction.copyWith(id: txnId);
      final pdfPath = await _pdfGenerator.generateReceipt(
        savedTransaction,
        items,
      );
      await _db.updateTransactionPdfPath(txnId, pdfPath);

      // Reload pending transactions
      await loadPending();

      _isLoading = false;
      notifyListeners();

      return savedTransaction.copyWith(pdfPath: pdfPath);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Load items for a specific transaction
  Future<void> loadTransactionItems(int transactionId) async {
    _currentItems = await _db.getTransactionItems(transactionId);
    notifyListeners();
  }

  /// Get transaction items without updating state
  Future<List<TransactionItem>> fetchTransactionItems(int transactionId) {
    return _db.getTransactionItems(transactionId);
  }

  final Set<int> _skippedItemIds = {};

  /// Skip an item for this session
  void skipItem(int itemId) {
    _skippedItemIds.add(itemId);
    notifyListeners();
  }

  /// Get current item index for progress (skipping skipped ones)
  int getCurrentItemIndex() {
    return _currentItems.indexWhere(
      (item) => !item.reEntered && !_skippedItemIds.contains(item.id),
    );
  }

  /// Mark an item as re-entered
  Future<void> markItemDone(int itemId) async {
    await _db.markItemReEntered(itemId);
    _skippedItemIds.remove(itemId); // Remove from skipped if complete

    // Update local state
    final index = _currentItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _currentItems[index] = _currentItems[index].copyWith(reEntered: true);
      notifyListeners();
    }
  }

  /// Mark transaction as synced
  Future<void> markTransactionSynced(int transactionId) async {
    await _db.markTransactionSynced(transactionId);
    await loadPending();
    await loadSynced();
    _currentItems = [];
    _skippedItemIds.clear();
    notifyListeners();
  }

  /// Clear current items
  void clearCurrentItems() {
    _currentItems = [];
    _skippedItemIds.clear();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getWeeklySales() {
    return _db.getWeeklySales();
  }
}
