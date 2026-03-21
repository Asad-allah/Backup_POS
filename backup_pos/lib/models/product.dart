/// Product model representing items from CSV import
class Product {
  final int? id;
  final String barcode;
  final String name;
  final String? category;
  final double sellPrice;
  final double buyPrice; // New field
  final int quantity;

  Product({
    this.id,
    required this.barcode,
    required this.name,
    this.category,
    required this.sellPrice,
    this.buyPrice = 0.0, // Default to 0
    this.quantity = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'category': category,
      'sell_price': sellPrice,
      'buy_price': buyPrice,
      'quantity': quantity,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      category: map['category'] as String?,
      sellPrice: (map['sell_price'] as num).toDouble(),
      buyPrice: (map['buy_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as int?) ?? 0,
    );
  }

  @override
  String toString() =>
      'Product(barcode: $barcode, name: $name, price: $sellPrice)';
}
