import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../providers/product_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _userRole;
  final TextEditingController _rateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final rate = context.read<SettingsProvider>().exchangeRate;
    _rateController.text = rate.toStringAsFixed(0);
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all (or just auth?)
    // Re-nav to main
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _userRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Currency Settings (Admin Only)
          if (isAdmin) ...[
            const Text(
              'Currency & Pricing',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFECECEC),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exchange Rate (USD to LBP)',
                    style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _rateController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            prefixText: '1 \$ = ',
                            suffixText: ' L.L',
                            border: InputBorder.none,
                            prefixStyle: TextStyle(color: Color(0xFFB0B0B0)),
                            suffixStyle: TextStyle(color: Color(0xFFB0B0B0)),
                          ),
                          onChanged: (val) {
                            final rate = double.tryParse(val);
                            if (rate != null) {
                              context.read<SettingsProvider>().setExchangeRate(
                                rate,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Changes apply instantly.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 48),
            const SizedBox(height: 24),
            // Data Management
            const Text(
              'Data Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFECECEC),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.file_upload,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  'Import Products from CSV',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Bulk add items',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
                onTap: () async {
                  try {
                    final result = await context
                        .read<ProductProvider>()
                        .importCSV();
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Import Report'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Products Added: ${result.count}'),
                                Text('Total Rows: ${result.totalRows}'),
                                Text(
                                  'Synthetic Items: ${result.syntheticItemsAdded.length}',
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Categories Found:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  result.distinctCategories
                                          .take(10)
                                          .join(', ') +
                                      (result.distinctCategories.length > 10
                                          ? '...'
                                          : ''),
                                ),
                                if (result.count == 0) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Debug Log (Why 0?):',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    color: Colors.grey[200],
                                    child: Text(
                                      result.debugLog,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Import failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 48),
          ],

          // Account Section
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFECECEC),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person, color: Colors.white54),
                  title: Text(
                    'Role: ${_userRole?.toUpperCase() ?? "UNKNOWN"}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
