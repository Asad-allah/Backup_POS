import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/compact_cart_card.dart';

class QuickKeysScreen extends StatefulWidget {
  final Function(Product) onItemSelected;
  final bool isSelectionMode;

  const QuickKeysScreen({
    super.key,
    required this.onItemSelected,
    this.isSelectionMode = false,
  });

  @override
  State<QuickKeysScreen> createState() => _QuickKeysScreenState();
}

class _QuickKeysScreenState extends State<QuickKeysScreen> {
  String? _selectedCategory;
  List<Product> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final provider = context.read<ProductProvider>();
    // Fetch specifically the Quick Keys products (NB-...) directly from DB
    // This avoids relying on the shared searchResults state which might be empty or filtered
    final products = await provider.getQuickKeysProducts();

    if (mounted) {
      setState(() {
        _allProducts = products;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 1. Products are already filtered by getQuickKeysProducts (NB-%)
    final noBarcodeProducts = _allProducts;

    // Get unique categories
    final categories =
        noBarcodeProducts
            .map((p) => p.category ?? 'Uncategorized')
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: [
            // Header / Back Button
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF2C2C2C),
              child: Row(
                children: [
                  if (_selectedCategory != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _selectedCategory = null;
                        });
                      },
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedCategory ?? 'Quick Keys',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              flex: widget.isSelectionMode ? 1 : 3,
              child: _selectedCategory == null
                  ? _buildCategoryGrid(categories)
                  : _buildItemGrid(noBarcodeProducts),
            ),
            if (!widget.isSelectionMode) ...[
              const Divider(height: 1, color: Colors.white24),
              // Cart Section (Split View for Sale Mode only)
              Expanded(flex: 2, child: _buildCartSection()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<String> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Quick Keys Found',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Import CSV with categories ending in "2", "جاج", or "منتجات افران"',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.5),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4 columns like screenshot
        childAspectRatio: 0.70,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Material(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.folder_rounded,
                  size: 40, // Reduced from 48
                  color: Colors.amber, // Folder color
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12, // Reduced from 14
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemGrid(List<Product> allProducts) {
    final items = allProducts
        .where((p) => p.category == _selectedCategory)
        .toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.70,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final product = items[index];
        return Material(
          color: const Color(0xFF383838), // Slightly lighter for items
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              widget.onItemSelected(product);
              if (widget.isSelectionMode) {
                Navigator.pop(context); // Close on selection
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added \${product.name}'),
                    duration: const Duration(milliseconds: 500),
                  ),
                );
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.insert_drive_file, // Item icon
                  size: 28, // Reduced from 32
                  color: Colors.cyan,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ), // Reduced from 13
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${product.sellPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartSection() {
    return Container(
      color: const Color(0xFF121212),
      child: Column(
        children: [
          // Cart Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Cart',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Explicit size
                  ),
                ),
                Consumer<CartProvider>(
                  builder: (context, cart, _) => Text(
                    '${cart.items.fold(0, (sum, item) => sum + item.quantity)} items', // Count total density not just rows
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Cart List
          Expanded(
            child: Consumer<CartProvider>(
              builder: (context, cart, _) {
                if (cart.isEmpty) {
                  return const Center(
                    child: Text(
                      'Cart is Empty',
                      style: TextStyle(color: Colors.white24, fontSize: 16),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CompactCartCard(
                        item: cart.items[index],
                        onIncrement: () => cart.incrementQuantity(index),
                        onDecrement: () => cart.decrementQuantity(index),
                        onRemove: () => cart.removeItem(index),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Mini Footer (Total)
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              if (cart.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF1E1E1E),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${cart.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Consumer<SettingsProvider>(
                          builder: (context, settings, _) {
                            final lbpTotal = cart.total * settings.exchangeRate;
                            return Text(
                              '≈ ${NumberFormat('#,###').format(lbpTotal)} L.L',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
