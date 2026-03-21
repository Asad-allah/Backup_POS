import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cart_item.dart';
import '../providers/settings_provider.dart';

class CompactCartCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const CompactCartCard({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // Use alignment instead of Spacer
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFECECEC),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      final lbpTotal = item.total * settings.exchangeRate;
                      return Text(
                        '${NumberFormat('#,###').format(lbpTotal)} L.L',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4), // Small gap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.red[300],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    _miniBtn(Icons.remove, onDecrement),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _miniBtn(Icons.add, onIncrement, highlight: true),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap, {bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFECECEC) : const Color(0xFF2C2C2C),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 12,
          color: highlight ? const Color(0xFF121212) : Colors.white70,
        ),
      ),
    );
  }
}
