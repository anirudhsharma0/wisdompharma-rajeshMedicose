import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/voucher_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/services/pdf_service.dart';
import '../../common/widgets/custom_card.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  String _searchQuery = '';
  String _typeFilter = 'ALL'; // 'ALL', 'RECEIPT', 'PAYMENT'

  final _partyNameController = TextEditingController();
  final _partyPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _remarksController = TextEditingController();
  String _selectedPaymentMode = 'Cash';
  String _selectedCategory = 'Supplier Payment';

  @override
  void dispose() {
    _partyNameController.dispose();
    _partyPhoneController.dispose();
    _amountController.dispose();
    _refController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _openVoucherDialog(BuildContext context, {required bool isReceipt}) {
    _partyNameController.clear();
    _partyPhoneController.clear();
    _amountController.clear();
    _refController.clear();
    _remarksController.clear();
    _selectedPaymentMode = 'Cash';
    _selectedCategory = isReceipt ? 'Customer Khata' : 'Supplier Payment';

    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isReceipt ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isReceipt ? Icons.call_received : Icons.call_made,
                      color: isReceipt ? AppColors.success : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReceipt ? 'New Receipt Voucher (Payment Received)' : 'New Payment Voucher (Payment Paid)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        isReceipt ? 'Record debt recovery from customer' : 'Record money paid to supplier or expense',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Party Name (AutoComplete for Customers if Receipt)
                      if (isReceipt) ...[
                        const Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        Autocomplete<CustomerModel>(
                          displayStringForOption: (option) => option.name,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<CustomerModel>.empty();
                            }
                            return dashProvider.customers.where((cust) =>
                                cust.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                cust.phone.contains(textEditingValue.text));
                          },
                          onSelected: (CustomerModel selection) {
                            setModalState(() {
                              _partyNameController.text = selection.name;
                              _partyPhoneController.text = selection.phone;
                              if (selection.pendingBalance > 0) {
                                _amountController.text = selection.pendingBalance.toStringAsFixed(2);
                              }
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (val) => _partyNameController.text = val,
                              decoration: InputDecoration(
                                hintText: 'Type or select customer name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.person, size: 18),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        const Text('Supplier / Payee Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _partyNameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Mankind Pharma / City Electricals',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.business, size: 18),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Phone Number & Amount Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _partyPhoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: '10-digit phone',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.phone, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Payment Mode & Category Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedPaymentMode,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: ['Cash', 'UPI', 'Cheque', 'Bank Transfer'].map((mode) {
                                    return DropdownMenuItem(value: mode, child: Text(mode, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => _selectedPaymentMode = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: (isReceipt
                                          ? ['Customer Khata', 'Direct Advance', 'Misc Income']
                                          : ['Supplier Payment', 'Rent', 'Salary', 'Electricity', 'Misc Expense'])
                                      .map((cat) {
                                    return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => _selectedCategory = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cheque / Ref Number (Show if Cheque/UPI/Bank Transfer)
                      if (_selectedPaymentMode != 'Cash') ...[
                        Text(
                          _selectedPaymentMode == 'Cheque' ? 'Cheque No. & Bank Name' : 'Transaction UTR / Ref No.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _refController,
                          decoration: InputDecoration(
                            hintText: _selectedPaymentMode == 'Cheque' ? 'e.g. CHQ-481920 (HDFC Bank)' : 'e.g. UPI/39102948102',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.tag, size: 18),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Remarks
                      const Text('Remarks / Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _remarksController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Received partial payment against previous balance',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReceipt ? AppColors.success : Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    final party = _partyNameController.text.trim();
                    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;

                    if (party.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter customer or supplier name')),
                      );
                      return;
                    }
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount (> 0)')),
                      );
                      return;
                    }

                    final vNum = isReceipt
                        ? 'RCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
                        : 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                    final voucher = VoucherModel(
                      voucherNumber: vNum,
                      type: isReceipt ? 'RECEIPT' : 'PAYMENT',
                      partyName: party,
                      partyPhone: _partyPhoneController.text.trim(),
                      amount: amt,
                      paymentMode: _selectedPaymentMode,
                      referenceNumber: _refController.text.trim(),
                      category: _selectedCategory,
                      remarks: _remarksController.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    dashProvider.addVoucher(voucher);
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${voucher.type} Voucher $vNum recorded successfully!')),
                    );
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text('Save ${isReceipt ? "Receipt" : "Payment"} Voucher'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);

    // Calculate voucher statistics
    final now = DateTime.now();
    final todayVouchers = dashProvider.vouchers.where((v) =>
        v.createdAt.year == now.year && v.createdAt.month == now.month && v.createdAt.day == now.day);

    final totalReceiptsToday = todayVouchers
        .where((v) => v.type == 'RECEIPT')
        .fold(0.0, (sum, v) => sum + v.amount);

    final totalPaymentsToday = todayVouchers
        .where((v) => v.type == 'PAYMENT')
        .fold(0.0, (sum, v) => sum + v.amount);

    final totalChequesToday = todayVouchers
        .where((v) => v.paymentMode == 'Cheque' || v.paymentMode == 'Bank Transfer')
        .fold(0.0, (sum, v) => sum + v.amount);

    // Filter list
    final filteredVouchers = dashProvider.vouchers.where((v) {
      final matchesSearch = v.voucherNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.partyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.partyPhone.contains(_searchQuery) ||
          v.referenceNumber.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesType = _typeFilter == 'ALL' || v.type == _typeFilter;

      return matchesSearch && matchesType;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP SUMMARY CARDS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 250,
                  child: _buildMetricCard(
                    title: 'Payment Received Today',
                    value: '₹${totalReceiptsToday.toStringAsFixed(2)}',
                    subtitle: 'From Customer Debt Recovery',
                    icon: Icons.call_received,
                    color: AppColors.success,
                    bgColor: const Color(0xFFE6F4EA),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 250,
                  child: _buildMetricCard(
                    title: 'Payment Paid Today',
                    value: '₹${totalPaymentsToday.toStringAsFixed(2)}',
                    subtitle: 'Supplier Payouts & Expenses',
                    icon: Icons.call_made,
                    color: Colors.orange,
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 250,
                  child: _buildMetricCard(
                    title: 'Cheque & Bank Volume',
                    value: '₹${totalChequesToday.toStringAsFixed(2)}',
                    subtitle: 'Non-Cash Settlements',
                    icon: Icons.account_balance,
                    color: const Color(0xFF3B82F6),
                    bgColor: const Color(0xFFE8F0FE),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 250,
                  child: _buildMetricCard(
                    title: 'Total Vouchers Logged',
                    value: '${dashProvider.vouchers.length}',
                    subtitle: 'Permanent Ledger Entries',
                    icon: Icons.receipt_long,
                    color: const Color(0xFF8B5CF6),
                    bgColor: const Color(0xFFF3E8FF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. MAIN HEADER & ACTION BAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Voucher & Receipt Book',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Record customer credit collections, supplier payouts, and print official vouchers',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openVoucherDialog(context, isReceipt: true),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Receipt Voucher (Payment Received)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openVoucherDialog(context, isReceipt: false),
                    icon: const Icon(Icons.remove, size: 16),
                    label: const Text('+ Payment Voucher (Payment Pay)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. SEARCH & TYPE FILTER CONTROL
          CustomCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by Voucher No, Party Name, Phone or Ref No...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Type Toggle Buttons
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _buildFilterButton('ALL', 'All Vouchers'),
                      _buildFilterButton('RECEIPT', 'Receipts (Received)'),
                      _buildFilterButton('PAYMENT', 'Payments (Paid)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. VOUCHERS TABLE
          Expanded(
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: filteredVouchers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text('No vouchers found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          const Text('Use buttons above to record Payment Received or Payment Paid vouchers.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowColor: WidgetStateProperty.all(AppColors.background),
                        columns: const [
                          DataColumn(label: Text('Voucher No.', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Party / Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Payment Mode & Ref', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredVouchers.map((voucher) {
                          final isReceipt = voucher.type == 'RECEIPT';
                          final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  voucher.voucherNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                ),
                              ),
                              DataCell(
                                Text(
                                  dateFormat.format(voucher.createdAt),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isReceipt ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isReceipt ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    isReceipt ? 'RECEIPT' : 'PAYMENT',
                                    style: TextStyle(
                                      color: isReceipt ? AppColors.success : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      voucher.partyName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                    if (voucher.partyPhone.isNotEmpty)
                                      Text(
                                        voucher.partyPhone,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      voucher.paymentMode,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    if (voucher.referenceNumber.isNotEmpty)
                                      Text(
                                        voucher.referenceNumber,
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  voucher.category,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₹${voucher.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isReceipt ? AppColors.success : Colors.orange,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Print Voucher Receipt',
                                      icon: const Icon(Icons.print, color: AppColors.primary, size: 20),
                                      onPressed: () {
                                        PdfService.printVoucher(
                                          voucher,
                                          pharmacyName: dashProvider.pharmacyName,
                                          storeAddress: dashProvider.storeAddress,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Voucher Entry',
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Voucher?'),
                                            content: Text('Are you sure you want to delete voucher ${voucher.voucherNumber}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                onPressed: () {
                                                  if (voucher.id != null) {
                                                    dashProvider.deleteVoucher(voucher.id!);
                                                  }
                                                  Navigator.pop(ctx);
                                                },
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String type, String label) {
    final isSelected = _typeFilter == type;
    return InkWell(
      onTap: () => setState(() => _typeFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
