import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart' as app;
import '../models/transaction_item.dart';

/// PDF Generator for creating thermal-format receipts
class PdfGenerator {
  /// Generate a receipt PDF and return the file path
  Future<String> generateReceipt(
    app.Transaction transaction,
    List<TransactionItem> items,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 2),
                    bottom: pw.BorderSide(width: 2),
                  ),
                ),
                child: pw.Text(
                  'SALES RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              pw.SizedBox(height: 12),

              // Transaction info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Transaction #:',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    transaction.transactionNumber,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                    _formatDate(transaction.date),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Time:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                    _formatTime(transaction.date),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Items
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.productName,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '  ${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            '\$${item.totalPrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Items:',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '${transaction.itemCount}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL:',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '\$${transaction.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Footer
              pw.Text(
                'Thank you!',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Backup POS Receipt',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${directory.path}/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final fileName =
        'receipt_${transaction.transactionNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${receiptsDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }
}
