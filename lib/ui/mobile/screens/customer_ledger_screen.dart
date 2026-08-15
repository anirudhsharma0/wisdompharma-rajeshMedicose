import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/services/pdf_service.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _udharNoteController = TextEditingController();
  final TextEditingController _newCustNameController = TextEditingController();
  final TextEditingController _newCustPhoneController = TextEditingController();
  final TextEditingController _supNameController = TextEditingController();
  final TextEditingController _supContactController = TextEditingController();
  final TextEditingController _supGstinController = TextEditingController();

  String _activeCategory = 'CUSTOMERS'; // 'CUSTOMERS' or 'SUPPLIERS'
  String _filterTab = 'ALL'; // 'ALL', 'DUE', 'CLEAR'

  @override
  void dispose() {
    _searchController.dispose();
    _paymentController.dispose();
    _udharNoteController.dispose();
    _newCustNameController.dispose();
    _newCustPhoneController.dispose();
    _supNameController.dispose();
    _supContactController.dispose();
    _supGstinController.dispose();
    super.dispose();
  }

  void _collectPayment(BuildContext context, CustomerModel customer, DashboardProvider provider) {
    _paymentController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('Payment Collection', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pending Khata Balance:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Text(
                    '₹${customer.pendingBalance.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _paymentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Amount Received (₹)',
                labelStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primaryLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Record Received Cash'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              final amount = double.tryParse(_paymentController.text) ?? 0.0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid payment amount')),
                );
                return;
              }

              Navigator.pop(context);
              await provider.collectCustomerPayment(customer.id!, amount);
            },
          ),
        ],
      ),
    );
  }

  void _addCustomerCreditDialog(BuildContext context, CustomerModel customer, DashboardProvider provider) {
    _paymentController.clear();
    _udharNoteController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_shopping_cart, color: Colors.redAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('Add Customer Udhar / Credit', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Khata Balance:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      '₹${customer.pendingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _paymentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Udhar Amount Added (₹)',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.currency_rupee, color: Colors.redAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _udharNoteController,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Medicine / Note Details (Optional)',
                  hintText: 'e.g. Paracetamol 500mg, Disprin (2 strips)',
                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.medication_outlined, color: AppColors.primaryLight),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Add Udhar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              final amount = double.tryParse(_paymentController.text) ?? 0.0;
              final note = _udharNoteController.text.trim();
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid udhar amount')),
                );
                return;
              }

              Navigator.pop(context);
              await provider.addCustomerCredit(customer, amount, note: note);
            },
          ),
        ],
      ),
    );
  }

  void _addNewCustomerDialog(BuildContext context, DashboardProvider provider) {
    _newCustNameController.clear();
    _newCustPhoneController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1, color: AppColors.primaryLight),
            ),
            const SizedBox(width: 12),
            const Text('New Client Profile', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newCustNameController,
              decoration: InputDecoration(
                labelText: 'Full Customer Name',
                prefixIcon: const Icon(Icons.person, color: AppColors.primaryLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCustPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Phone Number',
                prefixIcon: const Icon(Icons.phone, color: AppColors.primaryLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Profile'),
            onPressed: () async {
              final name = _newCustNameController.text.trim();
              final phone = _newCustPhoneController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter customer name and phone number')),
                );
                return;
              }

              final success = await provider.addCustomer(CustomerModel(
                name: name,
                phone: phone,
                pendingBalance: 0.0,
              ));

              if (!context.mounted) return;
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.error,
                    content: Text('⚠️ Customer already registered with exact same name "$name" and phone "$phone"!'),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.success,
                  content: Text('✓ Khata Profile created for $name.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _addNewSupplierDialog(BuildContext context, DashboardProvider provider) {
    _supNameController.clear();
    _supContactController.clear();
    _supGstinController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.domain_add_rounded, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text('New Wholesale Supplier', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _supNameController,
              decoration: InputDecoration(
                labelText: 'Agency / Supplier Name',
                prefixIcon: const Icon(Icons.business_rounded, color: Colors.blue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supContactController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Contact Phone Number',
                prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supGstinController,
              decoration: InputDecoration(
                labelText: 'GSTIN Number (Optional)',
                prefixIcon: const Icon(Icons.receipt, color: Colors.blue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Supplier'),
            onPressed: () async {
              final name = _supNameController.text.trim();
              final contact = _supContactController.text.trim();
              final gstin = _supGstinController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter supplier agency name')),
                );
                return;
              }

              final success = await provider.addSupplier(SupplierModel(
                name: name,
                contact: contact.isEmpty ? 'N/A' : contact,
                gstin: gstin.isEmpty ? null : gstin,
                due: 0.0,
              ));

              if (!context.mounted) return;
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppColors.error, content: Text('⚠️ Supplier "$name" already registered!')),
                );
                return;
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(backgroundColor: AppColors.success, content: Text('✓ Supplier Agency $name registered.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _paySupplierDialog(BuildContext context, SupplierModel supplier, DashboardProvider provider) {
    final amountController = TextEditingController(text: supplier.due > 0 ? supplier.due.toStringAsFixed(2) : '');
    final refController = TextEditingController();
    final remarksController = TextEditingController();
    String selectedMode = 'Cash';
    bool printReceipt = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text('Pay Wholesale Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                if (supplier.gstin != null && supplier.gstin!.isNotEmpty)
                                  Text('GSTIN: ${supplier.gstin}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Pending Due', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text('₹${supplier.due.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Payment Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        hintText: 'Enter amount paid',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMode,
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / Online')),
                        DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedMode = val);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text('Receipt / Ref No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: refController,
                      decoration: InputDecoration(
                        hintText: 'e.g. 27822',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text('Remarks / Bill Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: remarksController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Paid against Bill No. A000937',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    CheckboxListTile(
                      value: printReceipt,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Generate & Print Receipt Slip (Pink Slip)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onChanged: (val) => setDialogState(() => printReceipt = val ?? true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid payment amount (> 0)')),
                      );
                      return;
                    }

                    final refNo = refController.text.trim();
                    final remarks = remarksController.text.trim();
                    final targetId = (supplier.id != null && supplier.id!.isNotEmpty) ? supplier.id! : supplier.name;
                    final shouldPrint = printReceipt;

                    // Close dialog immediately for instant UI feedback
                    Navigator.pop(ctx);

                    final voucher = await provider.paySupplier(
                      targetId,
                      amt,
                      paymentMode: selectedMode,
                      referenceNumber: refNo,
                      remarks: remarks,
                    );

                    if (shouldPrint && voucher != null) {
                      final remBal = (supplier.due - amt).clamp(0.0, 9999999.0);
                      final pdfBytes = await PdfService.generatePaymentReceiptPdf(
                        voucherNumber: voucher.voucherNumber,
                        partyName: supplier.name,
                        partyPhone: supplier.contact,
                        amountPaid: amt,
                        paymentMode: selectedMode,
                        referenceNumber: refNo,
                        remarks: remarks,
                        createdAt: DateTime.now(),
                        remainingBalance: remBal,
                        agencyName: supplier.name,
                        agencyAddress: supplier.address ?? 'Wholesale Distributor',
                      );

                      await Printing.layoutPdf(
                        onLayout: (PdfPageFormat format) async => pdfBytes,
                        name: 'Payment_Receipt_${supplier.name}_${voucher.voucherNumber}',
                      );
                    }
                  },
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Confirm Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addSupplierPurchaseDialog(BuildContext context, SupplierModel supplier, DashboardProvider provider) {
    final amountController = TextEditingController();
    final billNoController = TextEditingController();
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_shopping_cart, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('Add Purchase Bill (Stock Received)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Pending Due:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      '₹${supplier.due.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Stock Bill Amount (₹)',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.currency_rupee, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: billNoController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Invoice / Bill Number (Optional)',
                  hintText: 'e.g. INV-9981',
                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.numbers, color: Colors.blue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Remarks / Item Details (Optional)',
                  hintText: 'e.g. Cipla stock batch 2026',
                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.notes, color: AppColors.primaryLight),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Record Purchase Bill'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              final billNo = billNoController.text.trim();
              final remarks = remarksController.text.trim();
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid purchase bill amount')),
                );
                return;
              }

              Navigator.pop(context);
              final targetId = (supplier.id != null && supplier.id!.isNotEmpty) ? supplier.id! : supplier.name;
              await provider.addSupplierPurchase(
                targetId,
                amount,
                billNumber: billNo,
                remarks: remarks,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSupplierLedgerDialog(BuildContext context, SupplierModel supplier, DashboardProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final latestSup = provider.suppliers.firstWhere(
              (s) => s.id == supplier.id || s.name.toLowerCase() == supplier.name.toLowerCase(),
              orElse: () => supplier,
            );

            final supplierVouchers = provider.vouchers.where((v) =>
              (v.partyName.trim().toLowerCase() == latestSup.name.trim().toLowerCase()) ||
              (latestSup.contact.isNotEmpty && v.partyPhone == latestSup.contact)
            ).toList();

            supplierVouchers.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle & Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blue.withValues(alpha: 0.15),
                              child: Text(
                                latestSup.name.isNotEmpty ? latestSup.name[0].toUpperCase() : 'S',
                                style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(latestSup.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
                                  Text('📱 ${latestSup.contact}${latestSup.gstin != null && latestSup.gstin!.isNotEmpty ? ' | GSTIN: ${latestSup.gstin}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Summary Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: latestSup.due > 0
                                  ? LinearGradient(colors: [Colors.blue.shade900.withValues(alpha: 0.3), Colors.blue.shade800.withValues(alpha: 0.1)])
                                  : LinearGradient(colors: [Colors.green.shade900.withValues(alpha: 0.3), Colors.green.shade800.withValues(alpha: 0.1)]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: latestSup.due > 0 ? Colors.blue.shade400 : AppColors.success.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL PENDING AGENCY DUE',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white70),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      latestSup.due > 0 ? 'Payable to Supplier' : 'No Outstanding Balance',
                                      style: TextStyle(fontSize: 11, color: latestSup.due > 0 ? Colors.blue.shade200 : Colors.green.shade200),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹${latestSup.due.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: latestSup.due > 0 ? Colors.blue.shade300 : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Agency Voucher History',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                              ),
                              Text('${supplierVouchers.length} Vouchers', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Vouchers List
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: supplierVouchers.isEmpty
                                  ? const Center(
                                      child: Text('No transaction vouchers logged for this agency.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: supplierVouchers.length,
                                      separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                                      itemBuilder: (context, idx) {
                                        final v = supplierVouchers[idx];
                                        final isPurchase = v.type == 'PURCHASE';
                                        final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(v.createdAt);

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: isPurchase
                                                      ? Colors.green.withValues(alpha: 0.15)
                                                      : Colors.orange.withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isPurchase ? Icons.add_shopping_cart : Icons.call_made,
                                                  color: isPurchase ? Colors.green : Colors.orange,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isPurchase ? 'PURCHASE BILL (${v.voucherNumber})' : 'PAYMENT OUT (${v.paymentMode})',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: isPurchase ? Colors.green.shade800 : Colors.orange.shade800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      v.remarks.isNotEmpty ? v.remarks : formattedDate,
                                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${isPurchase ? '+' : '-'} ₹${v.amount.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isPurchase ? Colors.green.shade700 : Colors.orange.shade800,
                                                    ),
                                                  ),
                                                  Text(
                                                    formattedDate,
                                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Dual Action Bar inside Supplier History Modal
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _addSupplierPurchaseDialog(context, latestSup, provider);
                            },
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text('+ Purchase Bill'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _paySupplierDialog(context, latestSup, provider);
                            },
                            icon: const Icon(Icons.call_made, size: 16),
                            label: const Text('Pay Agency'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomerLedgerDialog(BuildContext context, CustomerModel customer, DashboardProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final latestCust = provider.customers.firstWhere(
              (c) => (customer.phone.isNotEmpty && c.phone == customer.phone) || c.name.toLowerCase() == customer.name.toLowerCase(),
              orElse: () => customer,
            );

            final customerBills = provider.bills.where((b) =>
              (latestCust.phone.isNotEmpty && b.customerPhone == latestCust.phone) ||
              (b.customerName.trim().toLowerCase() == latestCust.name.trim().toLowerCase())
            ).toList();

            final customerPayments = provider.customerPayments.where((p) =>
              p.customerId == latestCust.id ||
              (latestCust.phone.isNotEmpty && p.customerPhone == latestCust.phone) ||
              (p.customerName.trim().toLowerCase() == latestCust.name.trim().toLowerCase())
            ).toList();

            List<Map<String, dynamic>> txs = [];
            for (var bill in customerBills) {
              txs.add({
                'type': 'BILL',
                'ref': bill.billNumber,
                'amount': bill.netAmount,
                'date': bill.createdAt,
                'details': bill.items.map((e) => e.quantity == 1 && e.medicineName != 'Manual Udhar / Credit Entry' ? e.medicineName : '${e.medicineName} (${e.quantity})').join(', '),
              });
            }
            for (var pay in customerPayments) {
              txs.add({
                'type': 'PAYMENT',
                'ref': 'PAY-${pay.createdAt.millisecondsSinceEpoch.toString().substring(8)}',
                'amount': pay.amountPaid,
                'date': pay.createdAt,
                'details': 'Cash/UPI Payment Received',
              });
            }
            txs.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle & Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                latestCust.name.isNotEmpty ? latestCust.name[0].toUpperCase() : 'C',
                                style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(latestCust.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
                                  Text('📱 ${latestCust.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                              tooltip: 'Share Statement PDF',
                              onPressed: () {
                                final dash = Provider.of<DashboardProvider>(context, listen: false);
                                PdfService.generateAndShareCustomerStatement(
                                  latestCust,
                                  txs,
                                  pharmacyName: dash.pharmacyName,
                                  storeAddress: dash.storeAddress,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Statement Content Body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Outstanding Summary Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: latestCust.pendingBalance > 0
                                  ? LinearGradient(colors: [Colors.red.shade900.withValues(alpha: 0.3), Colors.red.shade800.withValues(alpha: 0.1)])
                                  : LinearGradient(colors: [Colors.green.shade900.withValues(alpha: 0.3), Colors.green.shade800.withValues(alpha: 0.1)]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: latestCust.pendingBalance > 0 ? Colors.redAccent.withValues(alpha: 0.4) : AppColors.success.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CURRENT KHATA BALANCE',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white70),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      latestCust.pendingBalance > 0 ? 'Payment Pending (Udhaar)' : 'Settled (No Balance Due)',
                                      style: TextStyle(fontSize: 11, color: latestCust.pendingBalance > 0 ? Colors.red.shade200 : Colors.green.shade200),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹${latestCust.pendingBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: latestCust.pendingBalance > 0 ? Colors.redAccent : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Ledger Timeline History',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                              ),
                              Text('${txs.length} Entries', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Timeline List
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: txs.isEmpty
                                  ? const Center(
                                      child: Text('No transaction history logged for this client.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: txs.length,
                                      separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                                      itemBuilder: (context, idx) {
                                        final tx = txs[idx];
                                        final isBill = tx['type'] == 'BILL';
                                        final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(tx['date'] as DateTime);

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: isBill ? Colors.red.withValues(alpha: 0.12) : AppColors.success.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isBill ? Icons.arrow_upward : Icons.arrow_downward,
                                                  size: 14,
                                                  color: isBill ? Colors.redAccent : AppColors.success,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: isBill ? Colors.red.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            isBill ? 'SALE BILL' : 'PAYMENT IN',
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                              color: isBill ? Colors.redAccent : AppColors.success,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'Ref: ${tx['ref']}',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      tx['details'],
                                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      formattedDate,
                                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                                    ),

                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${isBill ? "+" : "-"} ₹${(tx['amount'] as double).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: isBill ? Colors.redAccent : AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Dual Action Bar inside Modal
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _addCustomerCreditDialog(context, latestCust, provider);
                            },
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text('+ Give Udhar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _collectPayment(context, latestCust, provider);
                            },
                            icon: const Icon(Icons.account_balance_wallet, size: 16),
                            label: const Text('Collect Cash'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);

    final isCustomers = _activeCategory == 'CUSTOMERS';

    // Calculate metrics
    final totalCount = isCustomers ? dashProvider.customers.length : dashProvider.suppliers.length;
    final dueCount = isCustomers
        ? dashProvider.customers.where((c) => c.pendingBalance > 0).length
        : dashProvider.suppliers.where((s) => s.due > 0).length;
    final clearCount = totalCount - dueCount;

    final totalOutstanding = isCustomers
        ? dashProvider.totalOutstandingBalance
        : dashProvider.suppliers.fold<double>(0, (sum, s) => sum + s.due);

    // Filter lists
    final filteredCustomers = dashProvider.customers.where((cust) {
      final query = _searchController.text.toLowerCase().trim();
      final matchesQuery = query.isEmpty || cust.name.toLowerCase().contains(query) || cust.phone.contains(query);
      if (_filterTab == 'DUE') return matchesQuery && cust.pendingBalance > 0;
      if (_filterTab == 'CLEAR') return matchesQuery && cust.pendingBalance == 0;
      return matchesQuery;
    }).toList();

    final filteredSuppliers = dashProvider.suppliers.where((sup) {
      final query = _searchController.text.toLowerCase().trim();
      final matchesQuery = query.isEmpty || sup.name.toLowerCase().contains(query) || sup.contact.contains(query);
      if (_filterTab == 'DUE') return matchesQuery && sup.due > 0;
      if (_filterTab == 'CLEAR') return matchesQuery && sup.due == 0;
      return matchesQuery;
    }).toList();

    return CustomScrollView(
      slivers: [
        // Category Switcher Strip
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeCategory = 'CUSTOMERS'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isCustomers ? AppColors.primaryDark : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_rounded, size: 16, color: isCustomers ? Colors.white : AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Retail Customers',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCustomers ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeCategory = 'SUPPLIERS'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !isCustomers ? Colors.blue.shade700 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_rounded, size: 16, color: !isCustomers ? Colors.white : AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Wholesale Suppliers',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: !isCustomers ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Premium Stats Header Banner
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              gradient: isCustomers ? AppColors.emeraldGradient : AppColors.blueGradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCustomers ? 'Dukaan Customer Ledger' : 'Wholesale Supplier Agencies',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isCustomers ? 'Customer Udhaar & Statement Manager' : 'Agency Purchasing & Payable Ledger',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => isCustomers
                          ? _addNewCustomerDialog(context, dashProvider)
                          : _addNewSupplierDialog(context, dashProvider),
                      icon: Icon(isCustomers ? Icons.person_add_rounded : Icons.domain_add_rounded, size: 15, color: isCustomers ? AppColors.primaryDark : Colors.blue.shade800),
                      label: Text(
                        isCustomers ? '+ Add Client' : '+ Supplier',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCustomers ? AppColors.primaryDark : Colors.blue.shade800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCustomers ? 'TOTAL OUTSTANDING (UDHAAR)' : 'TOTAL PAYABLE TO SUPPLIERS',
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalOutstanding.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$dueCount ${isCustomers ? "Clients" : "Agencies"} Due', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('$clearCount Settled', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Search Input & Filter Pills Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: isCustomers ? 'Search client by Name or Phone...' : 'Search supplier agency by Name or Phone...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildFilterTab('ALL', 'All ($totalCount)'),
                    const SizedBox(width: 8),
                    _buildFilterTab('DUE', 'Balance Due ($dueCount)'),
                    const SizedBox(width: 8),
                    _buildFilterTab('CLEAR', 'Settled ($clearCount)'),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Content Area List
        if (isCustomers && filteredCustomers.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search_outlined, size: 54, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No khata clients found matching filter.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else if (!isCustomers && filteredSuppliers.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_outlined, size: 54, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No wholesale suppliers found.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else if (isCustomers)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final customer = filteredCustomers[index];
                  final hasBalance = customer.pendingBalance > 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasBalance ? Colors.amber.shade300 : AppColors.border,
                      ),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: InkWell(
                      onTap: () => _showCustomerLedgerDialog(context, customer, dashProvider),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: hasBalance ? Colors.amber.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                  style: TextStyle(
                                    color: hasBalance ? Colors.amber.shade800 : AppColors.primaryDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    customer.phone.isEmpty ? 'No Phone Listed' : customer.phone,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${customer.pendingBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: hasBalance ? AppColors.error : AppColors.primaryDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _addCustomerCreditDialog(context, customer, dashProvider),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                        ),
                                        child: const Text(
                                          '+ Udhar',
                                          style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (hasBalance) ...[
                                      InkWell(
                                        onTap: () => _collectPayment(context, customer, dashProvider),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryDark,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Collect',
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Client Profile?'),
                                            content: Text('Remove ${customer.name} from Khata Ledgers?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                onPressed: () {
                                                  if (customer.id != null) {
                                                    dashProvider.deleteCustomer(customer.id!);
                                                  }
                                                  Navigator.pop(ctx);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Client ${customer.name} removed.')),
                                                  );
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: filteredCustomers.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final supplier = filteredSuppliers[index];
                  final hasDue = supplier.due > 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasDue ? Colors.blue.shade300 : AppColors.border,
                      ),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: InkWell(
                      onTap: () => _showSupplierLedgerDialog(context, supplier, dashProvider),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'S',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    supplier.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '📱 ${supplier.contact}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  if (supplier.gstin != null && supplier.gstin!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'GSTIN: ${supplier.gstin}',
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${supplier.due.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: hasDue ? Colors.blue.shade700 : AppColors.primaryDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Supplier?'),
                                            content: Text('Remove wholesale supplier agency ${supplier.name}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                onPressed: () {
                                                  if (supplier.id != null) {
                                                    dashProvider.deleteSupplier(supplier.id!);
                                                  }
                                                  Navigator.pop(ctx);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Supplier ${supplier.name} removed.')),
                                                  );
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: filteredSuppliers.length,
              ),
            ),
          ),

        // Bottom spacing for FAB / navigation bar
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _filterTab == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filterTab = key);
      },
      selectedColor: AppColors.primaryDark,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}
