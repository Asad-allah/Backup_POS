// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('ALL.CSV');
  List<int> bytes = await file.readAsBytes();
  String content;

  // UTF-16LE Detection & Decoding
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    print('Detected UTF-16LE');
    final codes = <int>[];
    for (int i = 2; i < bytes.length - 1; i += 2) {
      codes.add(bytes[i] | (bytes[i + 1] << 8));
    }
    content = String.fromCharCodes(codes);
  } else {
    print('Assuming UTF-8');
    content = utf8.decode(bytes, allowMalformed: true);
  }

  final lines = content.split(RegExp(r'\r\n|\n|\r'));
  print('Total Lines: \${lines.length}');

  final Set<String> categories = {};
  int linesRead = 0;

  for (var line in lines) {
    if (line.trim().isEmpty) continue;

    // Simple CSV parse: split by comma, ignoring quotes for now as we just want Col 0
    final parts = line.split(',');
    if (parts.isNotEmpty) {
      final cat = parts[0].trim();
      if (cat.isNotEmpty &&
          cat != 'Category' &&
          cat != 'كاتلوج المنتج' &&
          cat != 'مرجع.') {
        categories.add(cat);
      }
    }

    linesRead++;
    if (linesRead > 500) break; // Check first 500 lines
  }

  print('\nDistict Categories Found (First 500 lines):');
  for (var cat in categories) {
    print('- "$cat"');
  }

  print('\nInspecting Target Categories (Rows):');
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    if (parts.length < 3) continue;

    final cat = parts[0].trim();
    // Check for number-like 'category'
    if (cat.startsWith('2300') || cat.startsWith('5595')) {
      final barcode = parts[2].trim();
      final name = parts.length > 3 ? parts[3].trim() : '???';
      print('Found Number-Row Item:');
      print('  Col0 (Is this Category?): "$cat"');
      print('  Name: "$name"');
      print('  Barcode: "$barcode" (Empty? ${barcode.isEmpty})');
      print('---');
    }
    if (cat.contains('خضار')) {
      final barcode = parts[2].trim();
      final name = parts.length > 3 ? parts[3].trim() : '???';
      final price = parts.length > 11 ? parts[11].trim() : '???';
      print('Found Vegetable Item:');
      print('  Cat: "$cat"');
      print('  Name: "$name"');
      print('  Barcode: "$barcode" (Empty? ${barcode.isEmpty})');
      print('  Price: "$price"');
      print('---');
    }
  }
}
