/// Transaction item representing a single product in a transaction
class TransactionItem {
  final int? id;
  final int? transactionId;
  final String barcode;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final bool reEntered;

  TransactionItem({
    this.id,
    this.transactionId,
    required this.barcode,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.reEntered = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'barcode': barcode,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      're_entered': reEntered ? 1 : 0,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      barcode: map['barcode'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
      reEntered: (map['re_entered'] as int) == 1,
    );
  }

  TransactionItem copyWith({
    int? id,
    int? transactionId,
    String? barcode,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    bool? reEntered,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      reEntered: reEntered ?? this.reEntered,
    );
  }
}
