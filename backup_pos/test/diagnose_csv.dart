// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('Diagnose CSV Columns', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi; // Initialize database factory

    final file = File('e:\\Backup_POS\\ALL.CSV');
    if (!await file.exists()) {
      print('File not found');
      return;
    }

    // Manual UTF-16 LE decode (common for Excel CSVs)
    final bytes = await file.readAsBytes();
    String contents;
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final chars = Iterable.generate(
        (bytes.length - 2) ~/ 2,
        (i) => bytes[2 + i * 2] | (bytes[3 + i * 2] << 8),
      );
      contents = String.fromCharCodes(chars);
    } else {
      contents = String.fromCharCodes(bytes); // Fallback
    }

    final rawLines = contents.split(RegExp(r'\r\n|\n|\r'));
    print('Total Raw Lines: ${rawLines.length}');

    for (int i = 0; i < 5 && i < rawLines.length; i++) {
      if (rawLines[i].trim().isEmpty) continue;
      print('\nROW $i RAW: ${rawLines[i]}');
      // Simple split by comma for debug visual
      final parts = rawLines[i].split(',');
      for (int j = 0; j < parts.length; j++) {
        print('  [$j]: "${parts[j]}"');
      }
    }
  });
}
