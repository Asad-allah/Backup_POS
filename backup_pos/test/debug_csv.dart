// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:backup_pos/services/csv_importer.dart';

import 'dart:io';

void main() {
  test('Debug CSV Import', () async {
    // Initialize FFI for Windows
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final importer = CsvImporter();
    // The file path found by find_by_name
    final filePath = 'E:\\Backup_POS\\ALL.CSV';

    print('Attempting to import from: $filePath');

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      // Just dumping first 500 chars to see header/structure
      print('CSV HEAD:');
      print(String.fromCharCodes(bytes.take(500)));

      final count = await importer.importFromFile(filePath);
      print('SUCCESS: Imported $count products.');
    } catch (e, stack) {
      print('FAILURE: $e');
      print(stack);
      fail('Import failed');
    }
  });
}
