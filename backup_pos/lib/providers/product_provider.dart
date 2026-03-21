import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../services/database_helper.dart';
import '../services/csv_importer.dart';

/// Provider for managing products and CSV import
class ProductProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final CsvImporter _csvImporter = CsvImporter();

  List<Product> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  int _productCount = 0;

  List<Product> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get productCount => _productCount;

  /// Initialize product count
  Future<void> initialize() async {
    await _refreshProductCount();
  }

  Future<void> _refreshProductCount() async {
    _productCount = await _db.getProductCount();
    notifyListeners();
  }

  /// Import products from CSV file using file picker
  Future<ImportResult> importCSV() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return ImportResult(
          count: 0,
          totalRows: 0,
          distinctCategories: [],
          syntheticItemsAdded: [],
          debugLog: 'No file selected',
        );
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        throw Exception('Could not get file path');
      }

      final importResult = await _csvImporter.importFromFile(filePath);
      await _refreshProductCount();

      _isLoading = false;
      notifyListeners();
      return importResult;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Search products by name or barcode
  Future<void> searchProducts(String query) async {
    // If empty, load recent products/all products up to limit
    if (query.trim().isEmpty) {
      // We can reuse search with empty string which matches all due to %query%
      // But let's clarify that in DB helper or just pass empty string
      // The DB helper does 'LIKE %$query%'. '%%' matches all.
      _searchResults = await _db.getAllProducts();
    } else {
      _searchResults = await _db.searchProducts(query.trim());
    }
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _searchResults = await _db.getAllProducts();
    notifyListeners();
  }

  /// Get product by barcode
  Future<Product?> getByBarcode(String barcode) async {
    return await _db.getProductByBarcode(barcode);
  }

  /// Get Quick Keys products (No Barcode items)
  Future<List<Product>> getQuickKeysProducts() async {
    return await _db.getQuickKeysProducts();
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  /// Clear all products
  Future<void> clearProducts() async {
    await _db.clearProducts();
    await _refreshProductCount();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Add a new product
  Future<void> addProduct(Product product) async {
    try {
      await _db.addProduct(product);
      await _refreshProductCount();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update an existing product
  Future<void> updateProduct(Product product) async {
    try {
      await _db.updateProduct(product);
      // If updating the currently searched item, refresh search (optional)
      // For now just notify
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a product
  Future<void> deleteProduct(int id) async {
    try {
      await _db.deleteProduct(id);
      await _refreshProductCount();
      // Remove from search results if present
      _searchResults.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
