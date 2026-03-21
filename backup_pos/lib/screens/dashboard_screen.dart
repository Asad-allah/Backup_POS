import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/transaction_provider.dart';
import 'package:intl/intl.dart';
import 'product_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _weeklySales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<TransactionProvider>();
    await provider.loadSynced();
    final sales = await provider.getWeeklySales();
    if (mounted) {
      setState(() {
        _weeklySales = sales;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideX(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 24),

              // Actions
              _buildBentoCard(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductListScreen(),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            color: Colors.purpleAccent,
                            size: 28,
                          ),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Manage Products',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Add, edit, or remove items',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),

              const SizedBox(height: 16),

              Consumer<TransactionProvider>(
                builder: (context, provider, _) {
                  final sales = provider.syncedTransactions.fold<double>(
                    0,
                    (sum, t) => sum + t.total,
                  );
                  final count = provider.syncedTransactions.length;

                  return Column(
                    children: [
                      // Row 1: Big Sales Card
                      _buildBentoCard(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'TOTAL SALES TODAY',
                              style: TextStyle(
                                color: Color(0xFFB0B0B0),
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  sales.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFECECEC),
                                    height: 1,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8, left: 4),
                                  child: Text(
                                    '\$',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFFECECEC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Row 2: Metrics
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildBentoCard(
                              // height: 120, // Removed fixed height to prevent overflow
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.receipt_long,
                                    color: Colors.white70,
                                    size: 24, // Smaller icon
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        fontSize: 20, // Smaller font
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Transactions',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildBentoCard(
                              // height: 120,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.show_chart,
                                    color: Colors.greenAccent,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '+12%', // Placeholder for now
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Growth',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Chart Section
                      const Text(
                        'Weekly Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildBentoCard(
                        height: 250,
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _weeklySales.isEmpty
                            ? const Center(
                                child: Text(
                                  'No data available',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : BarChart(
                                BarChartData(
                                  gridData: FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          if (value.toInt() >= 0 &&
                                              value.toInt() <
                                                  _weeklySales.length) {
                                            final dateStr =
                                                _weeklySales[value
                                                        .toInt()]['day']
                                                    as String;
                                            final date = DateTime.parse(
                                              dateStr,
                                            );
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                DateFormat('E').format(date),
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: _weeklySales.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final data = entry.value;
                                    return BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: (data['daily_total'] as num)
                                              .toDouble(),
                                          color: Colors.greenAccent,
                                          width: 16,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoCard({Widget? child, double? height, int? flex}) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}
