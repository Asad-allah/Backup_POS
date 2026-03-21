import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/transaction.dart' as app;
import '../models/transaction_item.dart';
import '../models/expiration_date.dart';

/// Database helper for SQLite operations
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('backup_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, // v4: expiration_dates table
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN quantity INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN buy_price REAL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expiration_dates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          barcode TEXT NOT NULL,
          product_name TEXT,
          expiry_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_read INTEGER DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expiry_barcode ON expiration_dates(barcode)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expiry_date ON expiration_dates(expiry_date)',
      );
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        sell_price REAL NOT NULL,
        buy_price REAL DEFAULT 0,
        quantity INTEGER DEFAULT 0
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_number TEXT UNIQUE NOT NULL,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        item_count INTEGER NOT NULL,
        status TEXT NOT NULL,
        synced_at TEXT,
        pdf_path TEXT
      )
    ''');

    // Transaction items table
    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        barcode TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        re_entered INTEGER DEFAULT 0,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id)
      )
    ''');

    // Expiration dates table (separate from products — import-safe)
    await db.execute('''
      CREATE TABLE expiration_dates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT NOT NULL,
        product_name TEXT,
        expiry_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER DEFAULT 0
      )
    ''');

    // Create indices
    await db.execute('CREATE INDEX idx_barcode ON products(barcode)');
    await db.execute(
      'CREATE INDEX idx_transaction_status ON transactions(status)',
    );
    await db.execute(
      'CREATE INDEX idx_expiry_barcode ON expiration_dates(barcode)',
    );
    await db.execute(
      'CREATE INDEX idx_expiry_date ON expiration_dates(expiry_date)',
    );
  }

  // ==================== PRODUCTS ====================

  Future<void> clearProducts() async {
    final db = await database;
    await db.delete('products');
  }

  Future<void> insertProducts(List<Product> products) async {
    final db = await database;
    final batch = db.batch();

    for (final product in products) {
      batch.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 50,
    );

    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Product>> getAllProducts({int limit = 100}) async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'name ASC', limit: limit);
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Product>> getQuickKeysProducts() async {
    final db = await database;
    final maps = await db.query(
      'products',
      where:
          'barcode LIKE ? OR category LIKE ? OR category LIKE ? OR category LIKE ?',
      whereArgs: ['NB-%', '%2', '%جاج%', '%منتجات افران%'],
      orderBy: 'category ASC, name ASC',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> getProductCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return result.first['count'] as int;
  }

  Future<int> addProduct(Product product) async {
    final db = await database;
    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== TRANSACTIONS ====================

  Future<int> createTransaction(
    app.Transaction transaction,
    List<TransactionItem> items,
  ) async {
    final db = await database;

    final txnId = await db.insert('transactions', transaction.toMap());

    final batch = db.batch();
    for (final item in items) {
      batch.insert('transaction_items', {
        ...item.toMap(),
        'transaction_id': txnId,
      });
    }
    await batch.commit(noResult: true);

    return txnId;
  }

  Future<String> generateTransactionNumber() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions',
    );
    final count = (result.first['count'] as int) + 1;
    return 'TXN_${count.toString().padLeft(3, '0')}';
  }

  Future<List<app.Transaction>> getTransactionsByStatus(String status) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'date DESC',
    );

    return maps.map((map) => app.Transaction.fromMap(map)).toList();
  }

  Future<List<TransactionItem>> getTransactionItems(int transactionId) async {
    final db = await database;
    final maps = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    return maps.map((map) => TransactionItem.fromMap(map)).toList();
  }

  Future<void> markItemReEntered(int itemId) async {
    final db = await database;
    await db.update(
      'transaction_items',
      {'re_entered': 1},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> markTransactionSynced(int transactionId) async {
    final db = await database;
    await db.update(
      'transactions',
      {'status': 'synced', 'synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM transactions WHERE status = 'pending'",
    );
    return result.first['count'] as int;
  }

  Future<int> getReEnteredItemCount(int transactionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transaction_items WHERE transaction_id = ? AND re_entered = 1',
      [transactionId],
    );
    return result.first['count'] as int;
  }

  Future<void> updateTransactionPdfPath(
    int transactionId,
    String pdfPath,
  ) async {
    final db = await database;
    await db.update(
      'transactions',
      {'pdf_path': pdfPath},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final db = await database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 7));

    // Group by date (YYYY-MM-DD from ISO string)
    // SQLite's substr(date, 1, 10) extracts YYYY-MM-DD
    final result = await db.rawQuery(
      '''
      SELECT 
        substr(date, 1, 10) as day, 
        SUM(total) as daily_total 
      FROM transactions 
      WHERE status = 'synced' 
        AND date >= ?
      GROUP BY day
      ORDER BY day ASC
    ''',
      [startOfWeek.toIso8601String()],
    );

    return result;
  }

  // ==================== EXPIRATION DATES ====================

  Future<int> insertExpirationDate(ExpirationDate item) async {
    final db = await database;
    
    // UPSERT logic: check if barcode already exists
    final existing = await db.query(
      'expiration_dates',
      where: 'barcode = ?',
      whereArgs: [item.barcode],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      // Update existing record with new expiry date and name
      await db.update(
        'expiration_dates',
        item.toMap(), // Converts the new ExpirationDate into map
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    } else {
      // Insert new record
      return await db.insert('expiration_dates', item.toMap());
    }
  }

  Future<List<ExpirationDate>> getAllExpirationDates() async {
    final db = await database;
    final maps = await db.query(
      'expiration_dates',
      orderBy: 'expiry_date ASC',
    );
    return maps.map((m) => ExpirationDate.fromMap(m)).toList();
  }

  /// Fetches a map of barcode -> category for all expiration items
  Future<Map<String, String>> getExpirationCategories() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT e.barcode, p.category
      FROM expiration_dates e
      LEFT JOIN products p ON e.barcode = p.barcode
    ''');
    final map = <String, String>{};
    for (final row in results) {
      final barcode = row['barcode'] as String;
      final category = row['category'] as String?;
      map[barcode] = category ?? '';
    }
    return map;
  }

  Future<int> getUnreadExpiryCount(int reminderDays) async {
    final db = await database;
    final now = DateTime.now();
    final threshold = now.add(Duration(days: reminderDays));
    final result = await db.rawQuery(
      '''SELECT COUNT(*) as count FROM expiration_dates 
         WHERE is_read = 0 AND expiry_date <= ?''',
      [threshold.toIso8601String()],
    );
    return result.first['count'] as int;
  }

  Future<void> markExpiryAsRead(int id) async {
    final db = await database;
    await db.update(
      'expiration_dates',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllExpiriesAsRead() async {
    final db = await database;
    await db.update('expiration_dates', {'is_read': 1});
  }

  Future<int> deleteExpirationDate(int id) async {
    final db = await database;
    return await db.delete(
      'expiration_dates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateExpirationDate(ExpirationDate item) async {
    final db = await database;
    return await db.update(
      'expiration_dates',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// After CSV re-import, refresh cached product names in expiration_dates
  /// by looking up the latest product name from the (newly imported) products table.
  /// This keeps expiry records accurate even after product data is replaced.
  Future<void> refreshExpiryProductNames() async {
    final db = await database;
    // Get all expiration records
    final expiryRecords = await db.query('expiration_dates');
    if (expiryRecords.isEmpty) return;

    final batch = db.batch();
    for (final record in expiryRecords) {
      final barcode = record['barcode'] as String;
      // Look up current product name
      final products = await db.query(
        'products',
        columns: ['name'],
        where: 'barcode = ?',
        whereArgs: [barcode],
        limit: 1,
      );
      if (products.isNotEmpty) {
        final newName = products.first['name'] as String;
        batch.update(
          'expiration_dates',
          {'product_name': newName},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
      }
    }
    await batch.commit(noResult: true);
  }
}
