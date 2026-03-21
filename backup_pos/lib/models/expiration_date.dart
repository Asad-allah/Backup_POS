/// Model representing a product expiration date record.
/// Linked to products by barcode (survives CSV re-imports).
class ExpirationDate {
  final int? id;
  final String barcode;
  final String? productName;
  final DateTime expiryDate;
  final DateTime createdAt;
  final bool isRead;

  ExpirationDate({
    this.id,
    required this.barcode,
    this.productName,
    required this.expiryDate,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'barcode': barcode,
      'product_name': productName,
      'expiry_date': expiryDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
    };
  }

  factory ExpirationDate.fromMap(Map<String, dynamic> map) {
    return ExpirationDate(
      id: map['id'] as int?,
      barcode: map['barcode'] as String,
      productName: map['product_name'] as String?,
      expiryDate: DateTime.parse(map['expiry_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      isRead: (map['is_read'] as int?) == 1,
    );
  }

  ExpirationDate copyWith({
    int? id,
    String? barcode,
    String? productName,
    DateTime? expiryDate,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return ExpirationDate(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Days remaining until expiry (negative = expired)
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  bool get isExpired => daysRemaining < 0;

  bool isExpiringSoon(int reminderDays) =>
      !isExpired && daysRemaining <= reminderDays;

  @override
  String toString() =>
      'ExpirationDate(barcode: $barcode, expiry: $expiryDate, days: $daysRemaining)';
}
