import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import '../models/product.dart';
import 'database_helper.dart';

class ImportResult {
  final int count;
  final int totalRows;
  final List<String> distinctCategories;
  final List<String> syntheticItemsAdded;
  final String debugLog;

  ImportResult({
    required this.count,
    required this.totalRows,
    required this.distinctCategories,
    required this.syntheticItemsAdded,
    required this.debugLog,
  });
}

class CsvImporter {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<ImportResult> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found: $filePath');

    String contents;
    try {
      final bytes = await file.readAsBytes();
      contents = _decodeUtf16(bytes);
    } catch (e) {
      contents = await file.readAsString(encoding: utf8);
    }
    return await _parseAndImport(contents);
  }

  Future<ImportResult> importFromString(String csvContent) async {
    return await _parseAndImport(csvContent);
  }

  String _decodeUtf16(List<int> bytes) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        // LE
        final chars = Iterable.generate(
          (bytes.length - 2) ~/ 2,
          (i) => bytes[2 + i * 2] | (bytes[3 + i * 2] << 8),
        );
        return String.fromCharCodes(chars);
      } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        // BE
        return String.fromCharCodes(
          Iterable.generate(
            (bytes.length - 2) ~/ 2,
            (i) => (bytes[2 + i * 2] << 8) | bytes[3 + i * 2],
          ),
        );
      }
    }
    // Fallback LE
    return String.fromCharCodes(
      Iterable.generate(
        bytes.length ~/ 2,
        (i) => bytes[i * 2] | (bytes[i * 2 + 1] << 8),
      ),
    );
  }

  Future<ImportResult> _parseAndImport(String csvContent) async {
    List<List<dynamic>> rows = const CsvToListConverter(
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(csvContent);

    // FIX: If parser returned 1 giant row, manual fallback
    if (rows.length <= 1) {
      // print('DEBUG: Parser failed to split rows. Trying manual split.');
      final lines = csvContent.split(RegExp(r'\r\n|\n|\r'));
      if (lines.length > 1) {
        rows = [];
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          final lineRows = const CsvToListConverter(
            shouldParseNumbers: false,
            allowInvalid: true,
          ).convert(line);
          if (lineRows.isNotEmpty) rows.add(lineRows[0]);
        }
        // print('DEBUG: Manual split produced ${rows.length} rows');
      }
    }

    if (rows.isEmpty) throw Exception('CSV file is empty');

    final products = <Product>[];
    String? currentCategory;
    final Set<String> distinctCategories = {};
    final List<String> syntheticItems = [];
    final StringBuffer log = StringBuffer();

    log.writeln('Total Rows: ${rows.length}');

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      // Safe access
      final cell0 = row.isNotEmpty ? row[0].toString().trim() : '';
      final cell2 = row.length > 2 ? row[2].toString().trim() : '';

      // Skip header
      if (cell2.toLowerCase() == 'barcode') continue;

      // Update category ONLY if it seems to be a Header Row
      // A Header Row has a value in Col 0, but usually EMPTY Barcode/Name/Price
      // If Col 2 (Barcode) is present, it's an ITEM row, so we should NOT update category.
      bool isItemRow = false;
      if (cell2.isNotEmpty) {
        isItemRow = true; // Has explicit barcode
      } else {
        // Check if it has a Name/Price but no barcode (e.g. Synthetic Item candidates)
        // But synthetic item candidates usually don't have a value in Col 0 (unless they are headers?)
        // In this specific CSV, Headers have Col 0 value, Items have Col 0 value.
        // Headers have Empty Barcode. Items have Real/Empty Barcode.

        // If cell0 is not empty, and cell2 (barcode) is empty.
        // Is it a category header? Or a synthetic item?
        // In "ALL.CSV", header row: Col0="CatName", Col2="", Name=""
        // Item row: Col0="ID", Col2="Barcode", Name="Name"

        // So if Name (Col3) is also empty, it's definitely a category header.
        final nameCheck = row.length > 3 ? row[3].toString().trim() : '';
        if (nameCheck.isNotEmpty) {
          isItemRow =
              true; // Has Name -> It's an item (even if barcode missing)
        }
      }

      if (cell0.isNotEmpty && !isItemRow) {
        currentCategory = cell0;
        distinctCategories.add(currentCategory);
      }

      // 1. Is it a real barcode item?
      if (cell2.isNotEmpty) {
        final name = row.length > 3 ? row[3].toString().trim() : '';
        final priceStr = row.length > 11 ? row[11].toString() : '0';
        final price = _parsePrice(priceStr);

        if (name.isNotEmpty && price > 0) {
          final buyPriceStr = row.length > 6 ? row[6].toString() : '0';
          final qtyStr = row.length > 4 ? row[4].toString().trim() : '0';
          final buyPrice = _parsePrice(buyPriceStr);
          final qty = _parseQty(qtyStr);

          products.add(
            Product(
              barcode: cell2,
              name: name,
              category: currentCategory,
              sellPrice: price,
              buyPrice: buyPrice,
              quantity: qty,
            ),
          );
        }
      }
      // 2. Is it a No-Barcode item in a specific category?
      else if (currentCategory != null) {
        final cat = currentCategory.trim();
        // Permissive check: Ends with "2" (with or without space), or matches Arabic keywords
        final isNoBarcodeCategory =
            cat.endsWith(
              '2',
            ) || // Matches "Vegetables 2", "Vegetables2", "Cat2"
            cat.contains('جاج') ||
            cat.contains('منتجات افران');

        if (isNoBarcodeCategory) {
          final name = row.length > 3 ? row[3].toString().trim() : '';
          // If it has a Name, treat as item
          if (name.isNotEmpty) {
            final priceStr = row.length > 11 ? row[11].toString() : '0';
            final price = _parsePrice(priceStr);

            if (price > 0) {
              final syntheticBarcode = 'NB-$cat-$name';

              final buyPriceStr = row.length > 6 ? row[6].toString() : '0';
              final qtyStr = row.length > 4 ? row[4].toString().trim() : '0';
              final buyPrice = _parsePrice(buyPriceStr);
              final qty = _parseQty(qtyStr);

              products.add(
                Product(
                  barcode: syntheticBarcode,
                  name: name,
                  category: currentCategory,
                  sellPrice: price,
                  buyPrice: buyPrice,
                  quantity: qty,
                ),
              );
              syntheticItems.add('$name ($cat)');
            } else {
              log.writeln('Row $i: Skipped (Price 0) - $name');
            }
          }
        }
      }
    }

    log.writeln('Distinct Categories Found: ${distinctCategories.join(", ")}');
    log.writeln('Synthetic Items Created: ${syntheticItems.length}');

    if (products.isEmpty) {
      throw Exception('No parsed products. Log:\n$log');
    }

    await _db.clearProducts();
    for (int i = 0; i < products.length; i += 100) {
      final end = (i + 100 < products.length) ? i + 100 : products.length;
      await _db.insertProducts(products.sublist(i, end));
    }

    // After re-import: refresh cached product names in expiration_dates table.
    // Expiration dates are in a separate table (never deleted by import),
    // but we update the cached names so they match the new product data.
    await _db.refreshExpiryProductNames();

    return ImportResult(
      count: products.length,
      totalRows: rows.length,
      distinctCategories: distinctCategories.toList(),
      syntheticItemsAdded: syntheticItems,
      debugLog: log.toString(),
    );
  }

  double _parsePrice(String priceStr) {
    // Keep ONLY digits and dots.
    final cleaned = priceStr.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    if (cleaned.isEmpty) return 0.0;
    try {
      return double.parse(cleaned);
    } catch (e) {
      return 0.0;
    }
  }

  int _parseQty(String qtyStr) {
    // Should handle "25-" or "25"
    final cleaned = qtyStr.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (cleaned.isEmpty) return 0;
    try {
      return int.parse(cleaned);
    } catch (e) {
      return 0;
    }
  }
}
