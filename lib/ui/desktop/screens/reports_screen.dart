import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/bill_model.dart';
import '../../../data/services/pdf_service.dart';
import '../../common/widgets/custom_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _billSearchQuery = '';
  int _selectedTab = 0; // 0 = Sales & Revenue MIS, 1 = Purchase & Supplier Reports

  void _showCancelBillDialog(BuildContext context, BillModel bill, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Text('Cancel Bill & Issue Credit Note?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill Number: ${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Customer: ${bill.customerName} (${bill.customerPhone})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('Net Amount: ₹${bill.netAmount.toStringAsFixed(2)} (${bill.paymentMode})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This action will:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.error)),
                  const SizedBox(height: 4),
                  Text('• Restock ${bill.items.fold(0, (sum, i) => sum + i.quantity)} medicine item(s) back into stock.', style: const TextStyle(fontSize: 11)),
                  if (bill.paymentMode == 'Credit')
                    Text('• Deduct ₹${bill.netAmount.toStringAsFixed(2)} from ${bill.customerName}\'s Udhar pending balance.', style: const TextStyle(fontSize: 11)),
                  const Text('• Change bill status to CANCELLED.', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Bill')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              provider.cancelBill(bill);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bill ${bill.billNumber} cancelled & credit note issued.')),
              );
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }

  void _showBillDetailsDialog(BuildContext context, BillModel bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${DateFormat('dd-MM-yyyy hh:mm a').format(bill.createdAt)} | Customer: ${bill.customerName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DataTable(
                columns: const [
                  DataColumn(label: Text('Item Name')),
                  DataColumn(label: Text('Batch')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Total')),
                ],
                rows: bill.items.map((item) {
                  return DataRow(cells: [
                    DataCell(Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(item.batchNumber)),
                    DataCell(Text(item.quantity.toString())),
                    DataCell(Text('₹${item.salePrice.toStringAsFixed(1)}')),
                    DataCell(Text('₹${item.totalPrice.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]);
                }).toList(),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(bill.paymentMode, style: TextStyle(color: bill.paymentMode == 'Credit' ? Colors.orange : AppColors.success, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${bill.netAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              final dash = Provider.of<DashboardProvider>(context, listen: false);
              PdfService.printReceipt(
                bill,
                pharmacyName: dash.pharmacyName,
                storeAddress: dash.storeAddress,
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('Print Receipt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);

    // Filter valid completed bills for profit stats
    final validBills = dashProvider.bills.where((b) => b.status != 'CANCELLED').toList();

    double grossRevenue = 0.0;
    double totalDiscounts = 0.0;
    double netRevenue = 0.0;
    double totalPurchaseCostOfSales = 0.0;

    for (var bill in validBills) {
      grossRevenue += bill.totalAmount;
      totalDiscounts += bill.discount;
      netRevenue += bill.netAmount;

      for (var item in bill.items) {
        final matched = dashProvider.inventory.where(
          (inv) => inv.medicineName.toLowerCase() == item.medicineName.toLowerCase()
        );
        if (matched.isNotEmpty) {
          totalPurchaseCostOfSales += matched.first.purchasePrice * item.quantity;
        } else {
          totalPurchaseCostOfSales += item.salePrice * 0.6 * item.quantity;
        }
      }
    }

    final totalProfit = (netRevenue - totalPurchaseCostOfSales).clamp(0.0, 9999999.0);
    final profitMarginPercent = netRevenue > 0 ? (totalProfit / netRevenue) * 100 : 0.0;

    // Filter bills search
    final searchedBills = dashProvider.bills.where((b) {
      return b.billNumber.toLowerCase().contains(_billSearchQuery.toLowerCase()) ||
          b.customerName.toLowerCase().contains(_billSearchQuery.toLowerCase()) ||
          b.customerPhone.contains(_billSearchQuery);
    }).toList();

    // Filter purchase vouchers for Purchase Register
    final purchaseVouchers = dashProvider.vouchers.where((v) => v.type == 'PURCHASE').toList();
    final filteredPurchaseVouchers = purchaseVouchers.where((v) {
      final q = _billSearchQuery.toLowerCase();
      return q.isEmpty ||
          v.voucherNumber.toLowerCase().contains(q) ||
          v.partyName.toLowerCase().contains(q) ||
          v.remarks.toLowerCase().contains(q);
    }).toList();

    final totalPurchaseAmt = purchaseVouchers.fold(0.0, (sum, v) => sum + v.amount);
    final supplierNetDue = dashProvider.suppliers.fold(0.0, (sum, s) => sum + s.due);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header & Category Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTab == 0 ? 'Sales & Revenue MIS Analytics' : 'Purchase Bills & Supplier Register',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        _selectedTab == 0 ? 'Track retail sales, profit margins, and credit notes' : 'Monitor stock purchase bills, vendor dues, and itemized purchase statements',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _selectedTab = 0),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bar_chart, size: 16, color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Sales & MIS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => setState(() => _selectedTab = 1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.blue.shade700 : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 16, color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Purchase & Supplier Register',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_selectedTab == 0) ...[
              // Sales KPI Summary Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: _buildReportKpi(
                        'Net Sales Revenue',
                        '₹${netRevenue.toStringAsFixed(2)}',
                        'Gross: ₹${grossRevenue.toStringAsFixed(2)}',
                        Icons.payments,
                        AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildReportKpi(
                        'Cost of Goods Sold',
                        '₹${totalPurchaseCostOfSales.toStringAsFixed(2)}',
                        'Deducted from Stock',
                        Icons.shopping_cart_checkout,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildReportKpi(
                        'Net Profit',
                        '₹${totalProfit.toStringAsFixed(2)}',
                        'Margin: ${profitMarginPercent.toStringAsFixed(1)}%',
                        Icons.trending_up,
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildReportKpi(
                        'Discounts Given',
                        '₹${totalDiscounts.toStringAsFixed(2)}',
                        'Loyalty Deductions',
                        Icons.local_offer,
                        AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Charts and Summary
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revenue vs. Profit Margin Analysis',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: netRevenue > 0 ? netRevenue * 1.2 : 1000,
                                barTouchData: BarTouchData(enabled: true),
                                gridData: FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        switch (value.toInt()) {
                                          case 0:
                                            return const Text('Sales', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold));
                                          case 1:
                                            return const Text('Cost', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold));
                                          case 2:
                                            return const Text('Profit', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold));
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: [
                                  BarChartGroupData(
                                    x: 0,
                                    barRods: [
                                      BarChartRodData(
                                        toY: netRevenue,
                                        color: AppColors.accent,
                                        width: 24,
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    ],
                                  ),
                                  BarChartGroupData(
                                    x: 1,
                                    barRods: [
                                      BarChartRodData(
                                        toY: totalPurchaseCostOfSales,
                                        color: Colors.orange,
                                        width: 24,
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    ],
                                  ),
                                  BarChartGroupData(
                                    x: 2,
                                    barRods: [
                                      BarChartRodData(
                                        toY: totalProfit,
                                        color: AppColors.success,
                                        width: 24,
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // BILL SEARCH, MODIFY & CANCELLATION LEDGER
              CustomCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Billing Modification & Credit Note Desk',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Search, print, inspect or cancel bills (Credit Note / Sales Return)',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 320,
                          child: TextField(
                            onChanged: (val) => setState(() => _billSearchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search Bill #, Customer Name, Phone...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),

                    searchedBills.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: Text('No matching bill records found.', style: TextStyle(color: AppColors.textMuted))),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Bill Number', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Net Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: searchedBills.map((bill) {
                              final isCancelled = bill.status == 'CANCELLED';
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  DataCell(
                                    Text(DateFormat('dd-MM-yyyy hh:mm a').format(bill.createdAt), style: const TextStyle(fontSize: 12)),
                                  ),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(bill.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (bill.items.isNotEmpty)
                                          SizedBox(
                                            width: 180,
                                            child: Text(
                                              bill.items.map((i) => i.medicineName).join(', '),
                                              style: const TextStyle(fontSize: 11, color: AppColors.primaryLight, fontStyle: FontStyle.italic),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (bill.customerPhone.isNotEmpty)
                                          Text(bill.customerPhone, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      bill.paymentMode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: bill.paymentMode == 'Credit' ? Colors.orange : AppColors.success,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${bill.netAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                                        color: isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCancelled ? AppColors.error.withValues(alpha: 0.12) : AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        bill.status,
                                        style: TextStyle(
                                          color: isCancelled ? AppColors.error : AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'View Bill Items',
                                          icon: const Icon(Icons.visibility, color: AppColors.primary, size: 20),
                                          onPressed: () => _showBillDetailsDialog(context, bill),
                                        ),
                                        IconButton(
                                          tooltip: 'Print Tax Invoice',
                                          icon: const Icon(Icons.print, color: AppColors.accent, size: 20),
                                          onPressed: () {
                                             final dash = Provider.of<DashboardProvider>(context, listen: false);
                                             PdfService.printReceipt(
                                               bill,
                                               pharmacyName: dash.pharmacyName,
                                               storeAddress: dash.storeAddress,
                                             );
                                           },
                                        ),
                                        if (!isCancelled)
                                          IconButton(
                                            tooltip: 'Cancel Bill (Sales Return)',
                                            icon: const Icon(Icons.cancel, color: AppColors.error, size: 20),
                                            onPressed: () => _showCancelBillDialog(context, bill, dashProvider),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                  ],
                ),
              ),
            ] else ...[
              // PURCHASE REPORTS TAB
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: _buildReportKpi(
                        'Total Purchases Vol.',
                        '₹${totalPurchaseAmt.toStringAsFixed(2)}',
                        'Stock Procurement',
                        Icons.inventory,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildReportKpi(
                        'Supplier Dues Outstanding',
                        '₹${supplierNetDue.toStringAsFixed(2)}',
                        'Net Credit Payable',
                        Icons.account_balance_wallet,
                        Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildReportKpi(
                        'Purchase Invoices Count',
                        '${purchaseVouchers.length}',
                        'Registered Vouchers',
                        Icons.receipt,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildReportKpi(
                        'Active Suppliers',
                        '${dashProvider.suppliers.length}',
                        'Wholesale Vendors',
                        Icons.business,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              CustomCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Purchase Invoices & Stock Inward Register',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Complete log of medicines purchased from suppliers with cost rates & batch numbers',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 320,
                          child: TextField(
                            onChanged: (val) => setState(() => _billSearchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search Bill #, Supplier Name, Medicine...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),

                    filteredPurchaseVouchers.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: Text('No purchase invoice records match your search filter.', style: TextStyle(color: AppColors.textMuted))),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Invoice Ref No.', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Supplier Agency', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Total Bill (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Purchased Items Summary', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filteredPurchaseVouchers.map((voucher) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(voucher.voucherNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                                  ),
                                  DataCell(
                                    Text(DateFormat('dd-MM-yyyy hh:mm a').format(voucher.createdAt), style: const TextStyle(fontSize: 12)),
                                  ),
                                  DataCell(
                                    Text(voucher.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  DataCell(
                                    Text(
                                      voucher.paymentMode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: voucher.paymentMode == 'Credit' ? Colors.orange.shade900 : AppColors.success,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${voucher.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 250,
                                      child: Text(
                                        voucher.remarks.isNotEmpty ? voucher.remarks : 'Stock Purchase Entry',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.visibility, color: Colors.blue),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text('Purchase Bill #${voucher.voucherNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            content: SizedBox(
                                              width: 500,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Supplier: ${voucher.partyName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                  Text('Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(voucher.createdAt)} | Amount: ₹${voucher.amount.toStringAsFixed(2)} (${voucher.paymentMode})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                  const SizedBox(height: 12),
                                                  const Text('Item Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.grey.shade300),
                                                    ),
                                                    child: Text(voucher.remarks, style: const TextStyle(fontSize: 12, height: 1.4)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            actions: [
                                              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportKpi(String label, String value, String subText, IconData icon, Color color) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
