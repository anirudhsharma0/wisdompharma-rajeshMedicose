import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/bill_model.dart';
import '../../../providers/dashboard_provider.dart';
import '../../common/widgets/custom_card.dart';
import 'pos_billing_screen.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);

    // Calculate metrics
    final totalSales = dashProvider.bills.fold(0.0, (sum, b) => sum + b.netAmount);
    final totalPurchases = dashProvider.inventory.fold(0.0, (sum, item) => sum + (item.purchasePrice * item.quantity));
    final totalMeds = dashProvider.inventory.length;
    final totalCustomers = dashProvider.customers.length;
    
    // Sort recent bills
    final recentBills = [...dashProvider.bills];
    recentBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final topRecentBills = recentBills.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TOP QUICK ACTION HEADER BAR
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Title Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Quick Operations Launcher',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Fast one-click shortcuts for billing, purchases, and customer management',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Action 1: + New POS Bill
                      ElevatedButton.icon(
                        onPressed: () => onNavigate(1),
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('+ New POS Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Action 2: + Add Purchase Bill
                      ElevatedButton.icon(
                        onPressed: () => onNavigate(2),
                        icon: const Icon(Icons.post_add, size: 16),
                        label: const Text('+ Add Purchase Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Action 3: + Add Customer (Khata)
                      ElevatedButton.icon(
                        onPressed: () => onNavigate(4),
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        label: const Text('+ Add Customer (Khata)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 1. SUMMARY CARDS ROW (5 cards)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: _buildSummaryCard(
                    title: 'Total Sales',
                    value: '₹${totalSales.toStringAsFixed(2)}',
                    subtitle: 'Today +12.5%',
                    icon: Icons.shopping_cart,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFE6F4EA),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 220,
                  child: _buildSummaryCard(
                    title: 'Total Purchases',
                    value: '₹${totalPurchases.toStringAsFixed(2)}',
                    subtitle: 'Today +8.7%',
                    icon: Icons.payments,
                    iconColor: const Color(0xFF3B82F6),
                    iconBg: const Color(0xFFE8F0FE),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 220,
                  child: _buildSummaryCard(
                    title: 'Total Medicines',
                    value: '$totalMeds',
                    subtitle: 'In Stock',
                    icon: Icons.medication,
                    iconColor: const Color(0xFF8B5CF6),
                    iconBg: const Color(0xFFF3E8FF),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 220,
                  child: _buildSummaryCard(
                    title: 'Total Customers',
                    value: '$totalCustomers',
                    subtitle: 'Active',
                    icon: Icons.people,
                    iconColor: const Color(0xFFF59E0B),
                    iconBg: const Color(0xFFFEF3C7),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 220,
                  child: _buildSummaryCard(
                    title: 'Total Suppliers',
                    value: '${dashProvider.suppliers.length}',
                    subtitle: 'Active',
                    icon: Icons.local_shipping,
                    iconColor: const Color(0xFF0D9488),
                    iconBg: const Color(0xFFE6F4F1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. GRID ROW (Low Stock, Expiry, Quick Actions)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Low Stock Alert
              Expanded(
                flex: 3,
                child: CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: const [
                                Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Low Stock Alert',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => onNavigate(3), // Navigate to Stock Management
                            child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const Divider(height: 12, color: AppColors.border),
                      const SizedBox(height: 8),
                      dashProvider.lowStockMedicines.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(
                                child: Text('No low stock alerts', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: dashProvider.lowStockMedicines.take(5).length,
                              itemBuilder: (context, index) {
                                final item = dashProvider.lowStockMedicines[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.medicineName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${item.quantity} Qty',
                                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Column 2: Expiry Alert
              Expanded(
                flex: 3,
                child: CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: const [
                                Icon(Icons.event_busy, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Expiry Alert',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => onNavigate(7), // Navigate to Expiry Management
                            child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const Divider(height: 12, color: AppColors.border),
                      const SizedBox(height: 8),
                      dashProvider.nearExpiryMedicines.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(
                                child: Text('No near-expiry alerts', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: dashProvider.nearExpiryMedicines.take(5).length,
                              itemBuilder: (context, index) {
                                final item = dashProvider.nearExpiryMedicines[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.medicineName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.expiryDate,
                                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Column 3: Quick Actions
              Expanded(
                flex: 4,
                child: CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6.0),
                        child: Text(
                          'Quick Actions',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        ),
                      ),
                      const Divider(height: 12, color: AppColors.border),
                      const SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          _buildQuickActionButton(
                            label: 'New Sale',
                            icon: Icons.add_shopping_cart,
                            color: const Color(0xFF10B981),
                            onTap: () => onNavigate(1), // Navigate to POS
                          ),
                          _buildQuickActionButton(
                            label: 'New Purchase',
                            icon: Icons.add_chart,
                            color: const Color(0xFF3B82F6),
                            onTap: () => onNavigate(2), // Navigate to Stock
                          ),
                          _buildQuickActionButton(
                            label: 'Add Medicine',
                            icon: Icons.medication_liquid,
                            color: const Color(0xFF8B5CF6),
                            onTap: () => onNavigate(3), // Stock Management
                          ),
                          _buildQuickActionButton(
                            label: 'Add Customer',
                            icon: Icons.person_add,
                            color: const Color(0xFF0D9488),
                            onTap: () => onNavigate(4), // Customers Ledger
                          ),
                          _buildQuickActionButton(
                            label: 'Add Supplier',
                            icon: Icons.local_shipping,
                            color: Colors.orange,
                            onTap: () => onNavigate(5), // Suppliers
                          ),
                          _buildQuickActionButton(
                            label: 'Reports',
                            icon: Icons.analytics,
                            color: const Color(0xFFE91E63),
                            onTap: () => onNavigate(8), // Navigate to Reports
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. SALES OVERVIEW CHART & RECENT TRANSACTIONS ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Sales Overview Line Chart
              Expanded(
                flex: 6,
                child: CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sales Overview',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: const [
                                Text('This Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '₹${totalSales.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.primary),
                      ),
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          final currentMonthStr = DateFormat('MMM').format(DateTime.now());
                          final chartSpots = _getSalesChartSpots(dashProvider.bills);
                          double maxSaleVal = 0;
                          for (var s in chartSpots) {
                            if (s.y > maxSaleVal) maxSaleVal = s.y;
                          }
                          final maxYVal = maxSaleVal > 0 ? (maxSaleVal * 1.25).clamp(1000.0, 10000000.0) : 60000.0;

                          return SizedBox(
                            height: 220,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: AppColors.border.withValues(alpha: 0.5),
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 45,
                                      getTitlesWidget: (val, meta) {
                                        if (val == 0) return const Text('0');
                                        if (val >= 1000 && (val - 20000).abs() < 500) return const Text('20K');
                                        if (val >= 1000 && (val - 40000).abs() < 500) return const Text('40K');
                                        if (val >= 1000 && (val - 60000).abs() < 500) return const Text('60K');
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (val, meta) {
                                        switch (val.toInt()) {
                                          case 1:
                                            return Text('01 $currentMonthStr');
                                          case 7:
                                            return Text('07 $currentMonthStr');
                                          case 14:
                                            return Text('14 $currentMonthStr');
                                          case 21:
                                            return Text('21 $currentMonthStr');
                                          case 28:
                                            return Text('28 $currentMonthStr');
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                minX: 1,
                                maxX: 30,
                                minY: 0,
                                maxY: maxYVal,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: chartSpots,
                                    isCurved: true,
                                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.2),
                                          AppColors.primary.withValues(alpha: 0.0),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right: Recent Transactions
              Expanded(
                flex: 4,
                child: CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          TextButton(
                            onPressed: () => onNavigate(8), // Navigate to Reports
                            child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const Divider(height: 12, color: AppColors.border),
                      const SizedBox(height: 8),
                      topRecentBills.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40.0),
                              child: Center(
                                  child: Text('No transactions recorded yet.',
                                      style: TextStyle(color: AppColors.textMuted))),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: topRecentBills.length,
                              itemBuilder: (context, index) {
                                final bill = topRecentBills[index];
                                final isCredit = bill.paymentMode == 'Credit';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isCredit
                                              ? const Color(0xFFFEF3C7)
                                              : const Color(0xFFE6F4EA),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isCredit ? Icons.credit_card : Icons.receipt,
                                          color: isCredit ? Colors.orange : AppColors.primary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bill.billNumber,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              bill.customerName,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${bill.netAmount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isCredit ? Colors.orange : AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            bill.paymentMode,
                                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '© 2026 Medical Store Software. All rights reserved.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FlSpot> _getSalesChartSpots(List<BillModel> bills) {
    if (bills.isEmpty) {
      return const [FlSpot(1, 0), FlSpot(30, 0)];
    }
    final now = DateTime.now();
    Map<int, double> daySales = {};
    for (var bill in bills) {
      if (bill.createdAt.year == now.year && bill.createdAt.month == now.month) {
        final day = bill.createdAt.day;
        daySales[day] = (daySales[day] ?? 0.0) + bill.netAmount;
      }
    }
    if (daySales.isEmpty) {
      return const [FlSpot(1, 0), FlSpot(30, 0)];
    }
    List<FlSpot> spots = [];
    for (int day = 1; day <= 30; day++) {
      spots.add(FlSpot(day.toDouble(), daySales[day] ?? 0.0));
    }
    return spots;
  }
}
