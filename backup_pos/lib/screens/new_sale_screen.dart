import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';
import 'settings_screen.dart';
import 'quick_keys_screen.dart';
import '../widgets/compact_cart_card.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    autoStart: false, // Don't start immediately
  );
  Timer? _debounce;
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    // Delay camera start to allow previous screen to dispose its camera
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scannerController.start();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController.stop(); // Explicitly stop first
    _scannerController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<ProductProvider>().searchProducts(query);
      setState(() {
        _showSearchResults = query.isNotEmpty;
      });
    });
  }

  void _addToCart(Product product) {
    context.read<CartProvider>().addProduct(product);
    HapticFeedback.mediumImpact();
  }

  DateTime? _lastScanTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Sale',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.5),
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.grid_view,
                                color: Colors.amber,
                              ),
                              tooltip: 'Quick Keys (No Barcode)',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QuickKeysScreen(
                                      onItemSelected: (product) {
                                        _addToCart(product);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            onSelected: (value) {
                              if (value == 'hold') {
                                context.read<CartProvider>().holdCart();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Order held')),
                                );
                              } else if (value == 'restore') {
                                context.read<CartProvider>().restoreHeldCart();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Order restored'),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'hold',
                                child: Text('Hold Order'),
                              ),
                              if (context.read<CartProvider>().hasHeldCart)
                                const PopupMenuItem(
                                  value: 'restore',
                                  child: Text('Restore Held'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Placeholder for Scanner
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            final now = DateTime.now();
                            if (_lastScanTime != null &&
                                now.difference(_lastScanTime!) <
                                    const Duration(milliseconds: 700)) {
                              return;
                            }
                            _lastScanTime = now;

                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              if (barcode.rawValue != null) {
                                final messenger = ScaffoldMessenger.of(context);
                                final provider = context
                                    .read<ProductProvider>();

                                // Find product by barcode
                                provider.getByBarcode(barcode.rawValue!).then((
                                  product,
                                ) {
                                  if (product != null) {
                                    FlutterRingtonePlayer().playNotification();
                                    _addToCart(product);
                                  } else {
                                    // Play error sound
                                    FlutterRingtonePlayer().play(
                                      android: AndroidSounds.notification,
                                      ios: IosSounds.triTone,
                                    );
                                    HapticFeedback.heavyImpact();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Product not found'),
                                          backgroundColor: Colors.redAccent,
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  }
                                });
                              }
                            }
                          },
                        ),
                        // Scan line animation or overlay could go here
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          width: 200,
                          height: 100,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _showSearchResults
                  ? _buildSearchResults()
                  : _buildCartList(),
            ),
            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: provider.searchResults.length,
          itemBuilder: (context, index) {
            final product = provider.searchResults[index];
            return ListTile(
              title: Text(
                product.name,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '\$${product.sellPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () {
                _addToCart(product);
                _searchController.clear();
                setState(() => _showSearchResults = false);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCartList() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.isEmpty) {
          return const Center(
            child: Text('Empty Cart', style: TextStyle(color: Colors.grey)),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: cart.items.length,
          itemBuilder: (context, index) {
            return CompactCartCard(
              item: cart.items[index],
              onIncrement: () => cart.incrementQuantity(index),
              onDecrement: () => cart.decrementQuantity(index),
              onRemove: () => cart.removeItem(index),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        if (provider.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            child: Row(
              children: [
                // Total Section
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${provider.itemCount} items',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const SizedBox(height: 2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${provider.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          Consumer<SettingsProvider>(
                            builder: (context, settings, _) {
                              final lbpTotal =
                                  provider.total * settings.exchangeRate;
                              return Text(
                                '≈ ${NumberFormat('#,###').format(lbpTotal)} L.L',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                Row(
                  children: [
                    if (provider.itemCount > 0)
                      IconButton(
                        onPressed: () {
                          provider.clearCart();
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Clear Cart',
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: provider.itemCount == 0
                          ? null
                          : () => _processSale(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFECECEC),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 20),
                      label: const Text(
                        'Receipt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _processSale(BuildContext context) {
    final cart = context.read<CartProvider>();
    final items = cart.getItemsForCheckout();

    context
        .read<TransactionProvider>()
        .createTransaction(items)
        .then((trx) {
          cart.clearCart();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Receipt ${trx.transactionNumber} saved!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        })
        .catchError((e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        });
  }
}
