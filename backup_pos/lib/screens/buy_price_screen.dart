import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'quick_keys_screen.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import 'package:intl/intl.dart';

class BuyPriceScreen extends StatefulWidget {
  const BuyPriceScreen({super.key});

  @override
  State<BuyPriceScreen> createState() => _BuyPriceScreenState();
}

class _BuyPriceScreenState extends State<BuyPriceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    autoStart: false, // Don't start immediately
  );
  Product? _selectedProduct;
  Timer? _debounce;
  bool _isLoading = false;

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
      _searchProduct(query);
    });
  }

  Future<void> _searchProduct(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _selectedProduct = null);
      return;
    }

    setState(() => _isLoading = true);
    // Try exact match first (barcode)
    final product = await context.read<ProductProvider>().getByBarcode(query);
    if (product != null) {
      if (mounted) {
        setState(() {
          _selectedProduct = product;
          _isLoading = false;
        });
        FlutterRingtonePlayer().playNotification();
      }
      return;
    }

    // Fallback to name search in provider
    if (!mounted) return;
    await context.read<ProductProvider>().searchProducts(query);

    if (mounted) {
      setState(() {
        _isLoading = false;
        // If query was from scan and no product found at all
        if (query.length > 5 &&
            context.read<ProductProvider>().searchResults.isEmpty) {
          FlutterRingtonePlayer().play(
            android: AndroidSounds.notification,
            ios: IosSounds.triTone,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product not found'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 1),
            ),
          );
        }
      });
    }
  }

  DateTime? _lastScanTime;

  Widget _buildInfoCard(
    String label,
    String value,
    Color color, {
    bool isLarge = false,
    String? subValue, // LBP
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isLarge ? 24 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 4),
            Text(
              subValue,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double margin = 0;
    double marginPercent = 0;
    if (_selectedProduct != null) {
      margin = _selectedProduct!.sellPrice - _selectedProduct!.buyPrice;
      if (_selectedProduct!.sellPrice > 0) {
        marginPercent = (margin / _selectedProduct!.sellPrice) * 100;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Price Checker (Admin)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search / Scan Input
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Scan barcode or enter SKU',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _selectedProduct = null);
                        },
                      ),

                    // Quick Keys Button
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.grid_view,
                          color: Colors.amber,
                          size: 20,
                        ),
                        tooltip: 'Quick Keys',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuickKeysScreen(
                                isSelectionMode: true, // Don't show cart
                                onItemSelected: (product) {
                                  _searchProduct(
                                    product.barcode,
                                  ); // Use barcode to "search"
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Scanner View
            Container(
              height: 140, // Slightly taller
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
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
                          _searchController.text = barcode.rawValue!;
                          _searchProduct(barcode.rawValue!);
                        }
                      }
                    },
                  ),
                  const Center(
                    child: Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white24,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search Results or Selection
            Expanded(
              child: _selectedProduct != null
                  ? SingleChildScrollView(
                      child: _buildProductDetails(margin, marginPercent),
                    )
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        if (_searchController.text.isEmpty) {
          return const Center(
            child: Text(
              'Enter name or scan barcode',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.searchResults.isEmpty) {
          return const Center(
            child: Text(
              'No matches found',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.searchResults.length,
          itemBuilder: (context, index) {
            final product = provider.searchResults[index];
            return ListTile(
              title: Text(
                product.name,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                product.barcode,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              trailing: Text(
                '\$${product.sellPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                setState(() {
                  _selectedProduct = product;
                  _searchController.text = product.name;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductDetails(double margin, double marginPercent) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          _selectedProduct!.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Barcode: ${_selectedProduct!.barcode}',
          style: const TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  final lbpVal =
                      _selectedProduct!.buyPrice * settings.exchangeRate;
                  return _buildInfoCard(
                    'BUY PRICE',
                    '\$${_selectedProduct!.buyPrice.toStringAsFixed(2)}',
                    Colors.orangeAccent,
                    subValue: '${NumberFormat('#,###').format(lbpVal)} L.L',
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  final lbpVal =
                      _selectedProduct!.sellPrice * settings.exchangeRate;
                  return _buildInfoCard(
                    'SELL PRICE',
                    '\$${_selectedProduct!.sellPrice.toStringAsFixed(2)}',
                    Colors.greenAccent,
                    subValue: '${NumberFormat('#,###').format(lbpVal)} L.L',
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildInfoCard(
          'PROFIT MARGIN',
          '\$${margin.toStringAsFixed(2)} (${marginPercent.toStringAsFixed(1)}%)',
          margin > 0 ? Colors.blueAccent : Colors.redAccent,
          isLarge: true,
        ),
      ],
    );
  }
}
