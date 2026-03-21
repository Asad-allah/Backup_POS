// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:backup_pos/services/csv_importer.dart';
import 'package:backup_pos/services/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Verify Quick Keys Import Logic (Real Data Structure)', () async {
    try {
      final importer = CsvImporter();

      // Test Data mimicking the user's ALL.CSV structure
      // CRITICAL: Items have an ID in Column 0. If simpler logic is used, this ID overwrites the Category!

      const csvContent = '''
Category,Code,Barcode,Name,Qty,Unit,BuyPrice,Currency,Tax,Desc,Img,SellPrice
خضار 2,,,"",,,,0,,,0
100100,,1001,"طماطم",10,kg,5,USD,0,,,100
100101,,,"خيار",10,kg,5,USD,0,,,50
دجاج,,,"",,,,0,,,0
200200,,2002,"فروج",5,pcs,10,USD,0,,,200
200201,,,"صدر دجاج",5,pcs,12,USD,0,,,300
مشروبات,,,"",,,,0,,,0
300300,,3003,"كولا",50,pcs,1,USD,0,,,10
''';

      print('Starting Import Simulation...');
      final result = await importer.importFromString(csvContent);

      print('Import Result:');
      print('  Count: ${result.count}');
      print('  Categories: ${result.distinctCategories}');
      print('  Synthetic Items: ${result.syntheticItemsAdded}');

      // 1. Check Import Counts
      // Should import ALL 5 items.
      expect(result.count, 5, reason: 'Should import all 5 items');

      // 2. Check Synthetic items (No Barcode items should get NB-)
      // "خيار" and "صدر دجاج" have no barcode, so they should be synthetic.
      expect(
        result.syntheticItemsAdded.length,
        2,
        reason: 'Should generate synthetic barcodes for No-Barcode items',
      );
      expect(result.syntheticItemsAdded.any((s) => s.contains('خيار')), isTrue);
      expect(
        result.syntheticItemsAdded.any((s) => s.contains('صدر دجاج')),
        isTrue,
      );

      // 3. Check Database Query (The Result Screen Logic)
      // The Quick Keys screen should show items from "خضار 2" and "دجاج"
      // BOTH Real Barcode AND Synthetic Barcode items.
      // "مشروبات" (Drinks) should NOT be shown.

      final dbHelper = DatabaseHelper.instance;
      final quickKeys = await dbHelper.getQuickKeysProducts();

      print('DB Query Result (Quick Keys): ${quickKeys.length} items');
      for (var p in quickKeys) {
        print('  - ${p.name} (Cat: "${p.category}", Barcode: "${p.barcode}")');
      }

      // Expected:
      // طماطم (Real Barcode, Cat: خضار 2) -> YES
      // خيار (Synthetic, Cat: خضار 2) -> YES
      // فروج (Real Barcode, Cat: دجاج) -> YES
      // صدر دجاج (Synthetic, Cat: دجاج) -> YES
      // كولا (Real Barcode, Cat: مشروبات) -> NO

      expect(
        quickKeys.length,
        4,
        reason:
            'Should see 4 items in Quick Keys (2 Categories x 2 items each)',
      );

      final names = quickKeys.map((p) => p.name).toList();
      expect(names, contains('طماطم'));
      expect(names, contains('خيار'));
      expect(names, contains('فروج'));
      expect(names, contains('صدر دجاج'));
      expect(names, isNot(contains('كولا')));
    } catch (e, s) {
      print('TEST FAILED: $e');
      print(s);
      rethrow;
    }
  });
}
