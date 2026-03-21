import 'product.dart';

/// Cart item representing a product with quantity in the current sale
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.sellPrice * quantity;

  String get barcode => product.barcode;
  String get name => product.name;
  double get unitPrice => product.sellPrice;

  @override
  String toString() => 'CartItem(${product.name} x$quantity = \$$total)';
}
