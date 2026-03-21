import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/expiration_date.dart';
import 'database_helper.dart';

class ExpirationImportResult {
  final int totalRows;
  final int importedCount;
  final int skippedNotFoundCount;
  final String debugLog;

  ExpirationImportResult({
    required this.totalRows,
    required this.importedCount,
    required this.skippedNotFoundCount,
    required this.debugLog,
  });
}

class ExpirationCsvService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<String> exportToCsv(List<ExpirationDate> items) async {
    final List<List<dynamic>> rows = [];
    // Header
    rows.add(['barcode', 'product_name', 'expiry_date']);
    
    final dateFormat = DateFormat('yyyy-MM-dd');
    for (var item in items) {
      rows.add([
        item.barcode,
        item.productName ?? '',
        dateFormat.format(item.expiryDate),
      ]);
    }
    
    final csvString = const ListToCsvConverter().convert(rows);
    
    // Save to Downloads folder
    final directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final path = '${directory.path}/BackupPOS_Expiries_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvString);
    return path;
  }

  Future<ExpirationImportResult> importFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    
    if (result == null || result.files.isEmpty) {
       return ExpirationImportResult(
          totalRows: 0,
          importedCount: 0,
          skippedNotFoundCount: 0,
          debugLog: 'No file selected',
       );
    }
    
    final filePath = result.files.single.path;
    if (filePath == null) throw Exception('Could not get file path');
    
    final file = File(filePath);
    String contents;
    try {
      final bytes = await file.readAsBytes();
      try {
        contents = utf8.decode(bytes);
      } catch (_) {
        contents = _decodeUtf16(bytes);
      }
    } catch (_) {
      contents = await file.readAsString(encoding: utf8);
    }

    List<List<dynamic>> rows = const CsvToListConverter(
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(contents);

    // Fallback split logic
    if (rows.length <= 1) {
      final lines = contents.split(RegExp(r'\r\n|\n|\r'));
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
      }
    }

    if (rows.isEmpty) throw Exception('CSV file is empty');

    int imported = 0;
    int skippedCount = 0;
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    // Skip header if first row is 'barcode'
    if (rows.isNotEmpty && rows[0].isNotEmpty && rows[0][0].toString().toLowerCase() == 'barcode') {
      rows.removeAt(0);
    }

    for (var row in rows) {
      if (row.isEmpty) continue;
      final barcode = row[0].toString().trim();
      if (barcode.isEmpty) continue;
      
      String? name;
      DateTime? expiry;
      
      if (row.length > 1) name = row[1].toString().trim();
      if (row.length > 2) {
        final dateStr = row[2].toString().trim();
        try {
           expiry = dateFormat.parse(dateStr);
        } catch (_) {
           // Try yyMMdd fallback
           try {
             if (dateStr.length == 6) {
               final yy = int.parse(dateStr.substring(0,2));
               final mm = int.parse(dateStr.substring(2,4));
               final dd = int.parse(dateStr.substring(4,6));
               expiry = DateTime(2000 + yy, mm, dd);
             }
           } catch (_) {}
        }
      }
      
      if (expiry == null) {
         skippedCount++;
         continue;
      }
      
      // Validation: does product exist?
      final product = await _db.getProductByBarcode(barcode);
      if (product == null) {
         skippedCount++;
         continue;
      }
      
      // Insert via UPSERT
      final item = ExpirationDate(
         barcode: barcode,
         productName: name?.isNotEmpty == true ? name : product.name,
         expiryDate: expiry,
      );
      await _db.insertExpirationDate(item);
      imported++;
    }
    
    return ExpirationImportResult(
       totalRows: rows.length,
       importedCount: imported,
       skippedNotFoundCount: skippedCount,
       debugLog: 'Success',
    );
  }

  String _decodeUtf16(List<int> bytes) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        final chars = Iterable.generate(
          (bytes.length - 2) ~/ 2,
          (i) => bytes[2 + i * 2] | (bytes[3 + i * 2] << 8),
        );
        return String.fromCharCodes(chars);
      } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return String.fromCharCodes(
          Iterable.generate(
            (bytes.length - 2) ~/ 2,
            (i) => (bytes[2 + i * 2] << 8) | bytes[3 + i * 2],
          ),
        );
      }
    }
    return String.fromCharCodes(
      Iterable.generate(
        bytes.length ~/ 2,
        (i) => bytes[i * 2] | (bytes[i * 2 + 1] << 8),
      ),
    );
  }
}
