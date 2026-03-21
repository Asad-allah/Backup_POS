import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expiration_date.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/expiration_csv_service.dart';

/// Provider for managing expiration date tracking.
/// Only tracks products that have been explicitly given expiration dates.
/// Integrates with NotificationService for local device notifications.
class ExpirationProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService.instance;
  final ExpirationCsvService _csvService = ExpirationCsvService();

  List<ExpirationDate> _allItems = [];
  Map<String, String> _categories = {};
  int _unreadCount = 0;
  int _reminderDays = 7;
  bool _isLoading = false;
  String? _error;

  List<ExpirationDate> get allItems => _allItems;
  int get unreadCount => _unreadCount;
  int get reminderDays => _reminderDays;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String getCategory(String barcode) => _categories[barcode] ?? '';

  /// Items past expiry date (sorted: most recently expired first)
  List<ExpirationDate> get expiredItems {
    final items = _allItems.where((e) => e.isExpired).toList();
    items.sort((a, b) => b.expiryDate.compareTo(a.expiryDate));
    return items;
  }

  /// Items within reminder window (sorted: closest to expiry first)
  List<ExpirationDate> get expiringSoonItems {
    final items =
        _allItems.where((e) => e.isExpiringSoon(_reminderDays)).toList();
    items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return items;
  }

  /// Items still safe (sorted: closest to expiry first)
  List<ExpirationDate> get okItems {
    final items = _allItems
        .where((e) => !e.isExpired && !e.isExpiringSoon(_reminderDays))
        .toList();
    items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return items;
  }

  /// Total count of items needing attention (expired + expiring soon)
  int get alertCount => expiredItems.length + expiringSoonItems.length;

  /// Initialize: load settings + data + notifications
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _reminderDays = prefs.getInt('expiry_reminder_days') ?? 7;
    
    // Notification init is non-critical — if it fails, the app still works
    try {
      await _notifications.initialize();
    } catch (e) {
      debugPrint('Notification init failed (non-critical): $e');
    }
    
    await loadAll();
  }

  /// Load all expiration records from DB
  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    _allItems = await _db.getAllExpirationDates();
    _categories = await _db.getExpirationCategories();
    _unreadCount = await _db.getUnreadExpiryCount(_reminderDays);

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new expiration date entry and schedule notification
  Future<void> addExpiration({
    required String barcode,
    String? productName,
    required DateTime expiryDate,
  }) async {
    final item = ExpirationDate(
      barcode: barcode,
      productName: productName,
      expiryDate: expiryDate,
    );
    final id = await _db.insertExpirationDate(item);

    // Schedule local notification (non-critical)
    try {
      final savedItem = item.copyWith(id: id);
      if (!savedItem.isExpired) {
        await _notifications.scheduleExpiryNotification(
          item: savedItem,
          reminderDays: _reminderDays,
        );
      }
    } catch (e) {
      debugPrint('Notification scheduling failed (non-critical): $e');
    }

    await loadAll();
  }

  /// Delete an expiration record and cancel its notification
  Future<void> deleteExpiration(int id) async {
    try { await _notifications.cancelNotification(id); } catch (_) {}
    await _db.deleteExpirationDate(id);
    await loadAll();
  }

  /// Mark a single item as read
  Future<void> markAsRead(int id) async {
    await _db.markExpiryAsRead(id);
    await loadAll();
  }

  /// Mark all items as read
  Future<void> markAllAsRead() async {
    await _db.markAllExpiriesAsRead();
    await loadAll();
  }

  /// Update the reminder threshold and reschedule all notifications
  Future<void> setReminderDays(int days) async {
    _reminderDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('expiry_reminder_days', days);

    // Reschedule all notifications with new threshold
    await _notifications.rescheduleAll(
      items: _allItems,
      reminderDays: _reminderDays,
    );

    // Recalculate unread count with new threshold
    _unreadCount = await _db.getUnreadExpiryCount(_reminderDays);
    notifyListeners();
  }

  /// Export current expiration items to a CSV file
  Future<String?> exportCsv() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final path = await _csvService.exportToCsv(_allItems);
      _isLoading = false;
      notifyListeners();
      return path;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Import expiration items from selected CSV file
  Future<ExpirationImportResult?> importCsv() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _csvService.importFromCsv();
      // Even if count is 0, we might want to refresh, but mainly if >0
      if (result.importedCount > 0) {
        // Reload all data so UI reflects new dates
        await loadAll();
      } else {
        _isLoading = false;
        notifyListeners();
      }
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
