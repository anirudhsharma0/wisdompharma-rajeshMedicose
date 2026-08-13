import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/bill_model.dart';
import '../../common/widgets/receipt_preview.dart';
import '../../../data/services/pdf_service.dart';


class BillsHistoryScreen extends StatefulWidget {
  const BillsHistoryScreen({super.key});

  @override
  State<BillsHistoryScreen> createState() => _BillsHistoryScreenState();
}

class _BillsHistoryScreenState extends State<BillsHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedPaymentMode = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showReceiptDialog(BuildContext context, BillModel bill) {
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Bottom sheet handle bar
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Digital Receipt Copy',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: ReceiptPreview(bill: bill),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => PdfService.printReceipt(
                        bill,
                        pharmacyName: dashProvider.pharmacyName,
                        storeAddress: dashProvider.storeAddress,
                      ),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => PdfService.shareReceipt(
                        bill,
                        pharmacyName: dashProvider.pharmacyName,
                        storeAddress: dashProvider.storeAddress,
                      ),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share PDF'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (bill.status != 'CANCELLED')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel Bill?'),
                              content: Text('Are you sure you want to cancel bill ${bill.billNumber} and issue a credit note?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () {
                                    dashProvider.cancelBill(bill);
                                    if (!context.mounted) return;
                                    Navigator.pop(ctx);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Bill ${bill.billNumber} cancelled & stock restored.')),
                                    );
                                  },
                                  child: const Text('Cancel Bill'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel Bill'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    // Apply filters
    final filteredBills = dashProvider.bills.where((bill) {
      // 1. Search Query Filter (Bill number or customer name)
      final query = _searchController.text.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          bill.billNumber.toLowerCase().contains(query) ||
          bill.customerName.toLowerCase().contains(query) ||
          bill.customerPhone.contains(query);

      // 2. Date Filter
      bool matchesDate = true;
      if (_selectedDate != null) {
        matchesDate = bill.createdAt.year == _selectedDate!.year &&
            bill.createdAt.month == _selectedDate!.month &&
            bill.createdAt.day == _selectedDate!.day;
      }

      // 3. Payment Mode Filter
      final matchesPayment = _selectedPaymentMode == 'All' ||
          bill.paymentMode.toLowerCase() == _selectedPaymentMode.toLowerCase();

      return matchesQuery && matchesDate && matchesPayment;
    }).toList();

    final totalSales = filteredBills.fold<double>(0, (sum, item) => sum + item.netAmount);

    return Column(
      children: [
        // Top Filter & Summary Header Banner
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by Customer, Phone or Bill No...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryDark, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // Filter Pills Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Date Filter Chip
                    ActionChip(
                      avatar: const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryDark),
                      label: Text(
                        _selectedDate == null ? 'Date: All' : DateFormat('dd MMM').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedDate == null ? AppColors.textSecondary : AppColors.primaryDark,
                        ),
                      ),
                      backgroundColor: _selectedDate == null ? AppColors.background : AppColors.primary.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black87,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                    ),
                    if (_selectedDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate = null),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                        ),
                      ),
                    const SizedBox(width: 8),

                    // Payment Mode Pills
                    ...['All', 'Cash', 'UPI', 'Card', 'Credit'].map((mode) {
                      final isSelected = _selectedPaymentMode == mode;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FilterChip(
                          label: Text(mode),
                          selected: isSelected,
                          selectedColor: AppColors.primaryDark,
                          backgroundColor: AppColors.background,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (val) {
                            if (val) setState(() => _selectedPaymentMode = mode);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Summary Stats Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filteredBills.length} Transactions',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    Row(
                      children: [
                        const Text('Total Value: ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text(
                          '₹${totalSales.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List Area
        Expanded(
          child: dashProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredBills.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No matching sales invoices found.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredBills.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemBuilder: (context, index) {
                        final bill = filteredBills[index];
                        final isCredit = bill.paymentMode == 'Credit';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppColors.softShadow,
                            border: Border.all(
                              color: isCredit ? const Color(0xFFFDA4AF) : AppColors.border,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _showReceiptDialog(context, bill),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.receipt_rounded, color: AppColors.primaryDark, size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            bill.billNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCredit
                                              ? const Color(0xFFFEF2F2)
                                              : const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          bill.paymentMode.toUpperCase(),
                                          style: TextStyle(
                                            color: isCredit ? AppColors.error : AppColors.primaryDark,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        bill.customerName.isEmpty ? 'Walk-in Customer' : bill.customerName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                      ),
                                      if (bill.customerPhone.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${bill.customerPhone})',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textMuted),
                                      const SizedBox(width: 6),
                                      Text(
                                        dateFormat.format(bill.createdAt),
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  if (bill.items.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '💊 ${bill.items.map((i) => "${i.medicineName} (${i.quantity})").join(', ')}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  const Divider(color: AppColors.border, height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${bill.items.length} Medicine Item(s)',
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                      Row(
                                        children: [
                                          const Text(
                                            'Net Total: ',
                                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                          Text(
                                            '₹${bill.netAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppColors.primaryDark,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
