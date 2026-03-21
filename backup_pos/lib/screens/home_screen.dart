import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'new_sale_screen.dart';
import 'dashboard_screen.dart';
import 'pending_screen.dart';
import 'history_screen.dart';
import 'buy_price_screen.dart';
import 'expiration_screen.dart';
import '../providers/product_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/expiration_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenData {
  final IconData icon;
  final String label;

  _HomeScreenData(this.icon, this.label);
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userRole = 'staff';
  bool _loading = true;

  // List<Widget> _screens = []; // Removed

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_role') ?? 'staff';
        // _buildNavigation(); // Removed
        _loading = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().initialize();
      context.read<TransactionProvider>().loadPending();
      context.read<ExpirationProvider>().initialize();
    });
  }

  Widget _buildCurrentScreen() {
    // Recreate screens on demand to ensure proper disposal (crucial for Camera/Scanner)
    switch (_selectedIndex) {
      case 0:
        return const NewSaleScreen();
      case 1:
        return _userRole == 'admin'
            ? const DashboardScreen()
            : const SizedBox();
      case 2:
        return _userRole == 'admin' ? const BuyPriceScreen() : const SizedBox();
      case 3:
        return const ExpirationScreen();
      case 4:
        return const PendingScreen();
      case 5:
        return const HistoryScreen();
      default:
        return const Center(child: Text("Unknown Screen"));
    }
  }

  void _onItemTapped(int index) {
    // Adjust index if non-admin tries to access hidden tabs?
    // The bottom bar hides them, so index should match the visible tabs list?
    // Wait, BottomNavigationBar items are generated dynamically.
    // If I tap index 1 as staff, it corresponds to 'Pending' (since Dash/Prices are hidden).
    // So we need to map the BottomNav index to the logical screen index.

    // Actually, let's keep it simple. The tabs generation logic below handles the display.
    // But verify the mapping.
    // Current tabs logic:
    // [Sale, Dash(if admin), Prices(if admin), Expiry, Pending, History]
    // Indices:
    // Admin: Sale(0), Dash(1), Prices(2), Expiry(3), Pending(4), History(5)
    // Staff: Sale(0), Expiry(1), Pending(2), History(3)

    int logicalIndex = index;
    if (_userRole != 'admin') {
      // Staff mapping: 0->0, 1->3, 2->4, 3->5
      if (index == 1) logicalIndex = 3;
      if (index == 2) logicalIndex = 4;
      if (index == 3) logicalIndex = 5;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _selectedIndex = logicalIndex;
    });
  }

  int _getVisualIndex(int logicalIndex, bool isAdmin) {
    if (isAdmin) return logicalIndex;
    if (logicalIndex == 0) return 0; // Sale
    if (logicalIndex == 3) return 1; // Expiry
    if (logicalIndex == 4) return 2; // Pending
    if (logicalIndex == 5) return 3; // History
    return 0; // Default safety
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    bool isAdmin = _userRole == 'admin';

    final tabs = [
      _HomeScreenData(Icons.point_of_sale, 'Sale'),
      if (isAdmin) _HomeScreenData(Icons.dashboard, 'Dash'),
      if (isAdmin) _HomeScreenData(Icons.price_check, 'Prices'),
      _HomeScreenData(Icons.event_busy, 'Expiry'),
      _HomeScreenData(Icons.pending_actions, 'Pending'),
      _HomeScreenData(Icons.history, 'History'),
    ];

    return Scaffold(
      extendBody: true,
      body: KeyedSubtree(
        key: ValueKey<int>(_selectedIndex),
        child: _buildCurrentScreen(),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _getVisualIndex(_selectedIndex, isAdmin),
          onTap: _onItemTapped,
          backgroundColor: const Color(0xFF121212),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: const Color(0xFFB0B0B0),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isPending = tab.label == 'Pending';
            final isExpiry = tab.label == 'Expiry';

            Widget iconWidget = Icon(tab.icon);

            if (isExpiry) {
              iconWidget = Consumer<ExpirationProvider>(
                builder: (context, provider, child) {
                  final count = provider.unreadCount;
                  if (count > 0) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(tab.icon),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Icon(tab.icon);
                },
              );
            }

            if (isPending) {
              iconWidget = Consumer<TransactionProvider>(
                builder: (context, provider, child) {
                  final count = provider.pendingTransactions.length;
                  if (count > 0) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(tab.icon),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Icon(tab.icon);
                },
              );
            }

            return BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: iconWidget,
              ),
              label: tab.label,
            );
          }),
        ),
      ),
    );
  }
}
