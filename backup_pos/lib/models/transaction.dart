/// Transaction model representing a completed sale
class Transaction {
  final int? id;
  final String transactionNumber;
  final DateTime date;
  final double total;
  final int itemCount;
  final String status; // 'pending' or 'synced'
  final DateTime? syncedAt;
  final String? pdfPath;

  Transaction({
    this.id,
    required this.transactionNumber,
    required this.date,
    required this.total,
    required this.itemCount,
    required this.status,
    this.syncedAt,
    this.pdfPath,
  });

  bool get isPending => status == 'pending';
  bool get isSynced => status == 'synced';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_number': transactionNumber,
      'date': date.toIso8601String(),
      'total': total,
      'item_count': itemCount,
      'status': status,
      'synced_at': syncedAt?.toIso8601String(),
      'pdf_path': pdfPath,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      transactionNumber: map['transaction_number'] as String,
      date: DateTime.parse(map['date'] as String),
      total: (map['total'] as num).toDouble(),
      itemCount: map['item_count'] as int,
      status: map['status'] as String,
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      pdfPath: map['pdf_path'] as String?,
    );
  }

  Transaction copyWith({
    int? id,
    String? transactionNumber,
    DateTime? date,
    double? total,
    int? itemCount,
    String? status,
    DateTime? syncedAt,
    String? pdfPath,
  }) {
    return Transaction(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      date: date ?? this.date,
      total: total ?? this.total,
      itemCount: itemCount ?? this.itemCount,
      status: status ?? this.status,
      syncedAt: syncedAt ?? this.syncedAt,
      pdfPath: pdfPath ?? this.pdfPath,
    );
  }
}
