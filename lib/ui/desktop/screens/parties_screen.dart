import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/voucher_model.dart';
import '../../../data/models/bill_model.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/medicine_master_model.dart';
import '../../../data/services/sqlite_service.dart';
import '../../../data/services/pdf_service.dart';
import '../../../core/utils/platform_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../common/widgets/custom_card.dart';

class PartyItem {
  final String id;
  final String name;
  final String phone;
  final double amount; // Positive = Due to pay (Supplier) or Pending to collect (Customer)
  final String partyType; // 'Supplier' or 'Customer'
  final String? gstin;
  final String? address;

  PartyItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.amount,
    required this.partyType,
    this.gstin,
    this.address,
  });
}

class PartyTransaction {
  final String id;
  final String type; // 'Purchase', 'Payment-Out', 'Sale', 'Payment-In', 'Opening Balance'
  final String refNumber;
  final DateTime date;
  final double totalAmount;
  final double balance;
  final String status;
  final String? remarks;
  final dynamic rawObject;

  PartyTransaction({
    required this.id,
    required this.type,
    required this.refNumber,
    required this.date,
    required this.totalAmount,
    required this.balance,
    required this.status,
    this.remarks,
    this.rawObject,
  });
}

class PartiesScreen extends StatefulWidget {
  final String initialFilter; // 'ALL', 'SUPPLIERS', 'CUSTOMERS'
  const PartiesScreen({super.key, this.initialFilter = 'ALL'});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  String _partySearchQuery = '';
  String _transactionSearchQuery = '';
  String _selectedCategoryFilter = 'ALL'; // 'ALL', 'SUPPLIERS', 'CUSTOMERS'
  
  String? _selectedPartyId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryFilter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(PartiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() {
        _selectedCategoryFilter = widget.initialFilter;
        _selectedPartyId = null;
      });
    }
  }

  List<PartyItem> _getAllParties(DashboardProvider provider) {
    List<PartyItem> parties = [];

    // 1. Add Suppliers (Agencies)
    for (var s in provider.suppliers) {
      parties.add(PartyItem(
        id: s.id ?? 'sup_${s.name}',
        name: s.name,
        phone: s.contact,
        amount: s.due,
        partyType: 'Supplier',
        gstin: s.gstin,
        address: s.address,
      ));
    }

    // 2. Add Customers
    for (var c in provider.customers) {
      parties.add(PartyItem(
        id: c.id ?? 'cust_${c.name}',
        name: c.name,
        phone: c.phone,
        amount: c.pendingBalance,
        partyType: 'Customer',
      ));
    }

    // Apply category filter
    if (_selectedCategoryFilter == 'SUPPLIERS') {
      parties = parties.where((p) => p.partyType == 'Supplier').toList();
    } else if (_selectedCategoryFilter == 'CUSTOMERS') {
      parties = parties.where((p) => p.partyType == 'Customer').toList();
    }

    // Apply search filter
    if (_partySearchQuery.trim().isNotEmpty) {
      final q = _partySearchQuery.trim().toLowerCase();
      parties = parties.where((p) =>
        p.name.toLowerCase().contains(q) || p.phone.contains(q)
      ).toList();
    }

    return parties;
  }

  List<PartyTransaction> _getPartyTransactions(PartyItem party, DashboardProvider provider) {
    List<PartyTransaction> list = [];
    final pName = party.name.trim().toLowerCase();
    final pPhone = party.phone.trim();

    if (party.partyType == 'Supplier') {
      // 1. Vouchers (Payment-Out to Supplier)
      for (var v in provider.vouchers) {
        final matchesName = v.partyName.trim().toLowerCase() == pName;
        final matchesPhone = pPhone.isNotEmpty && v.partyPhone.trim() == pPhone;
        if ((matchesName || matchesPhone) && v.type == 'PAYMENT') {
          list.add(PartyTransaction(
            id: v.id ?? 'vouch_${v.voucherNumber}',
            type: 'Payment-Out',
            refNumber: v.referenceNumber.isNotEmpty ? v.referenceNumber : v.voucherNumber,
            date: v.createdAt,
            totalAmount: v.amount,
            balance: v.amount,
            status: 'Cleared',
            remarks: v.remarks,
            rawObject: v,
          ));
        }
      }

      // 2. Purchases (Stock added from Supplier via Vouchers or Inventory)
      for (var v in provider.vouchers) {
        final matchesName = v.partyName.trim().toLowerCase() == pName;
        final matchesPhone = pPhone.isNotEmpty && v.partyPhone.trim() == pPhone;
        if ((matchesName || matchesPhone) && v.type == 'PURCHASE') {
          list.add(PartyTransaction(
            id: v.id ?? 'vouch_p_${v.voucherNumber}',
            type: 'Purchase',
            refNumber: v.referenceNumber.isNotEmpty ? v.referenceNumber : v.voucherNumber,
            date: v.createdAt,
            totalAmount: v.amount,
            balance: v.amount,
            status: 'Unpaid',
            remarks: v.remarks,
            rawObject: v,
          ));
        }
      }
    } else {
      // Customer Transactions
      for (var b in provider.bills) {
        final matchesName = b.customerName.trim().toLowerCase() == pName;
        final matchesPhone = pPhone.isNotEmpty && b.customerPhone.trim() == pPhone;
        if (matchesName || matchesPhone) {
          list.add(PartyTransaction(
            id: b.id ?? 'bill_${b.billNumber}',
            type: 'Sale',
            refNumber: b.billNumber,
            date: b.createdAt,
            totalAmount: b.netAmount,
            balance: b.paymentMode == 'Credit' ? b.netAmount : 0.0,
            status: b.paymentMode == 'Credit' ? 'Unpaid' : 'Paid',
            remarks: b.items.map((i) => i.medicineName).join(', '),
            rawObject: b,
          ));
        }
      }

      for (var p in provider.customerPayments) {
        final matchesName = p.customerName.trim().toLowerCase() == pName;
        final matchesPhone = pPhone.isNotEmpty && p.customerPhone.trim() == pPhone;
        if (matchesName || matchesPhone) {
          list.add(PartyTransaction(
            id: p.id ?? 'pay_${p.createdAt.millisecondsSinceEpoch}',
            type: 'Payment-In',
            refNumber: 'REC-${p.createdAt.millisecondsSinceEpoch.toString().substring(7)}',
            date: p.createdAt,
            totalAmount: p.amountPaid,
            balance: 0.0,
            status: 'Received',
            remarks: 'Received against outstanding balance',
            rawObject: p,
          ));
        }
      }

      for (var v in provider.vouchers) {
        final matchesName = v.partyName.trim().toLowerCase() == pName;
        final matchesPhone = pPhone.isNotEmpty && v.partyPhone.trim() == pPhone;
        if ((matchesName || matchesPhone) && v.type == 'RECEIPT') {
          list.add(PartyTransaction(
            id: v.id ?? 'vouch_${v.voucherNumber}',
            type: 'Payment-In',
            refNumber: v.voucherNumber,
            date: v.createdAt,
            totalAmount: v.amount,
            balance: 0.0,
            status: 'Received',
            remarks: v.remarks,
            rawObject: v,
          ));
        }
      }
    }

    // Sort newest first
    list.sort((a, b) => b.date.compareTo(a.date));

    // Apply transaction search filter
    if (_transactionSearchQuery.trim().isNotEmpty) {
      final tq = _transactionSearchQuery.trim().toLowerCase();
      list = list.where((t) =>
        t.refNumber.toLowerCase().contains(tq) ||
        t.type.toLowerCase().contains(tq) ||
        (t.remarks != null && t.remarks!.toLowerCase().contains(tq))
      ).toList();
    }

    return list;
  }

  void _showAddPartyDialog(BuildContext context, DashboardProvider provider) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0.0');
    final gstinCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String pType = _selectedCategoryFilter == 'CUSTOMERS' ? 'Customer' : 'Supplier';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text('Add New Party / Agency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'Supplier',
                          label: Text('Wholesale Agency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          icon: Icon(Icons.business, size: 16),
                        ),
                        ButtonSegment<String>(
                          value: 'Customer',
                          label: Text('Customer (Khata)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          icon: Icon(Icons.person, size: 16),
                        ),
                      ],
                      selected: {pType},
                      onSelectionChanged: (newSelection) {
                        setDialogState(() => pType = newSelection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: pType == 'Supplier' ? 'Agency / Wholesaler Name *' : 'Customer Name *',
                      hintText: pType == 'Supplier' ? 'e.g. Hans Medical Agencies' : 'e.g. Ramesh Kumar',
                      prefixIcon: const Icon(Icons.business, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: 'e.g. 9053902222',
                      prefixIcon: Icon(Icons.phone, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: pType == 'Supplier' ? 'Opening Balance Due (To Pay ₹)' : 'Opening Balance Pending (To Collect ₹)',
                      prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                    ),
                  ),
                  if (pType == 'Supplier') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: gstinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN Number (Optional)',
                        hintText: 'e.g. 06AAAAM1234A1Z5',
                        prefixIcon: Icon(Icons.receipt, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City / Address (Optional)',
                        hintText: 'e.g. Fatehabad, Sirsa Road',
                        prefixIcon: Icon(Icons.location_on, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final balance = double.tryParse(balanceCtrl.text) ?? 0.0;

                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Party Name and Phone Number')),
                  );
                  return;
                }

                if (pType == 'Supplier') {
                  final success = await provider.addSupplier(SupplierModel(
                    name: name,
                    contact: phone,
                    due: balance,
                    gstin: gstinCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                  ));
                  if (!context.mounted) return;
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Supplier "$name" with phone "$phone" already exists!')),
                    );
                    return;
                  }
                } else {
                  final success = await provider.addCustomer(CustomerModel(
                    name: name,
                    phone: phone,
                    pendingBalance: balance,
                  ));
                  if (!context.mounted) return;
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Customer "$name" with phone "$phone" already exists!')),
                    );
                    return;
                  }
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppColors.success, content: Text('✓ $pType "$name" added successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Party'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, PartyItem party, DashboardProvider provider, {required bool isPaymentOut}) {
    final amtCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final remarkCtrl = TextEditingController();
    String payMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isPaymentOut ? Icons.call_made : Icons.call_received, color: isPaymentOut ? Colors.orange : AppColors.success, size: 24),
              const SizedBox(width: 10),
              Text(isPaymentOut ? 'Payment-Out (Paid to ${party.name})' : 'Payment-In (Received from ${party.name})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current Balance Due:', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    Text('₹${party.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.accent)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Paid / Received (₹) *',
                  hintText: 'Enter amount...',
                  prefixIcon: Icon(Icons.currency_rupee, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: payMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  prefixIcon: Icon(Icons.payment, size: 18),
                ),
                items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) => setDialogState(() => payMode = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ref No. / Cheque No. / Invoice No. (Optional)',
                  hintText: 'e.g. Bill #3777',
                  prefixIcon: Icon(Icons.numbers, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes / Remarks (Optional)',
                  hintText: 'e.g. Paid for medicine batch purchase',
                  prefixIcon: Icon(Icons.notes, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text) ?? 0.0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                if (isPaymentOut) {
                  if (party.partyType == 'Supplier') {
                    await provider.paySupplier(party.id, amt);
                  }
                  await provider.addVoucher(VoucherModel(
                    voucherNumber: 'V-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    type: 'PAYMENT',
                    partyName: party.name,
                    partyPhone: party.phone,
                    amount: amt,
                    paymentMode: payMode,
                    category: 'Supplier Payment',
                    referenceNumber: refCtrl.text.trim(),
                    remarks: remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'Paid to ${party.name}',
                    createdAt: DateTime.now(),
                  ));
                } else {
                  if (party.partyType == 'Customer') {
                    await provider.collectCustomerPayment(party.id, amt);
                  }
                  await provider.addVoucher(VoucherModel(
                    voucherNumber: 'V-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    type: 'RECEIPT',
                    partyName: party.name,
                    partyPhone: party.phone,
                    amount: amt,
                    paymentMode: payMode,
                    category: 'Customer Khata',
                    referenceNumber: refCtrl.text.trim(),
                    remarks: remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'Received from ${party.name}',
                    createdAt: DateTime.now(),
                  ));
                }

                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppColors.success, content: Text('✓ Transaction of ₹$amt recorded for ${party.name}.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: isPaymentOut ? Colors.orange : AppColors.success),
              child: Text(isPaymentOut ? 'Record Payment-Out' : 'Record Payment-In'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteParty(BuildContext context, PartyItem party, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            const SizedBox(width: 10),
            Text('Delete ${party.partyType}?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to delete "${party.name}"? This action will remove the party profile from your directory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete Party'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (party.partyType == 'Supplier') {
                await provider.deleteSupplier(party.id);
              } else {
                await provider.deleteCustomer(party.id);
              }
              if (!context.mounted) return;
              Navigator.pop(ctx);
              setState(() {
                _selectedPartyId = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red.shade700,
                  content: Text('✓ ${party.partyType} "${party.name}" deleted successfully.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailsDialog(BuildContext context, PartyItem party, PartyTransaction t, DashboardProvider provider) {
    VoucherModel? voucher;
    BillModel? saleBill;

    if (t.type == 'Purchase' || t.type == 'Payment-Out' || t.type == 'Payment-In') {
      try {
        voucher = provider.vouchers.firstWhere(
          (v) => (v.id != null && v.id == t.id) || v.voucherNumber == t.refNumber || v.referenceNumber == t.refNumber,
        );
      } catch (_) {}
    } else if (t.type == 'Sale') {
      try {
        saleBill = provider.bills.firstWhere(
          (b) => (b.id != null && b.id == t.id) || b.billNumber == t.refNumber,
        );
      } catch (_) {}
    }

    final isOut = t.type == 'Purchase' || t.type == 'Payment-Out';
    final paidAmount = (t.type == 'Payment-Out' || t.type == 'Payment-In')
        ? t.totalAmount
        : (t.status == 'Paid' || t.status == 'Cleared' ? t.totalAmount : 0.0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  t.type == 'Purchase'
                      ? Icons.shopping_bag
                      : (t.type == 'Sale' ? Icons.receipt_long : Icons.account_balance_wallet),
                  color: isOut ? Colors.orange.shade800 : AppColors.success,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.type} Details (${t.refNumber})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Party: ${party.name} (${party.partyType})', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Financial Summary Card with 3 Breakdown Boxes
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isOut ? Colors.orange : AppColors.primary).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isOut ? Colors.orange : AppColors.primary).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Transaction Date & Time:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(DateFormat('dd/MM/yyyy, hh:mm a').format(t.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 16),
                      
                      // 3 Financial Boxes Grid: Total Amount | Paid Amount | Party Net Pending Due
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: [
                                  const Text('Total Bill Value', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('₹${t.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: [
                                  Text(t.type == 'Payment-Out' || t.type == 'Payment-In' ? 'Amount Paid' : 'Paid in Bill', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('₹${paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: party.amount > 0 ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: party.amount > 0 ? Colors.orange.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: [
                                  Text(party.partyType == 'Supplier' ? 'Party Net Due' : 'Pending Collect', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${party.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: party.amount > 0 ? Colors.orange.shade800 : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Mode / Status:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: t.status == 'Cleared' || t.status == 'Paid' || t.status == 'Received'
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              voucher != null ? '${voucher.paymentMode} (${t.status})' : t.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: t.status == 'Cleared' || t.status == 'Paid' || t.status == 'Received'
                                    ? Colors.green.shade800
                                    : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Purchased Items List (if Sale Bill)
                if (saleBill != null && saleBill.items.isNotEmpty) ...[
                  const Text('Items Included in Bill:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.grey.shade100,
                          child: Row(
                            children: const [
                              Expanded(flex: 4, child: Text('Medicine Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Batch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        ...saleBill.items.map((item) => Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 4, child: Text(item.medicineName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text(item.batchNumber, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                              Expanded(flex: 1, child: Text('${item.quantity}', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text('₹${item.salePrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text('₹${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Purchased Items List (if Purchase Entry)
                if (t.type == 'Purchase') ...[
                  const Text('Purchased Medicines & Bill Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      t.remarks != null && t.remarks!.isNotEmpty ? t.remarks! : 'Stock Purchase Bill #${t.refNumber}',
                      style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Details & Remarks Box
                const Text('Transaction Notes & Remarks:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Reference No / Bill No: ${t.refNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (voucher != null && voucher.category.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('• Category: ${voucher.category}', style: const TextStyle(fontSize: 12)),
                      ],
                      const SizedBox(height: 4),
                      Text('• Remarks: ${t.remarks != null && t.remarks!.isNotEmpty ? t.remarks : 'No additional remarks'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Printing transaction voucher for ${t.refNumber}...')),
              );
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print Receipt'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddPurchaseBillDialog(BuildContext context, PartyItem party, DashboardProvider provider) {
    final invNoCtrl = TextEditingController(text: 'A${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final invDateCtrl = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
    final paidAmtCtrl = TextEditingController(text: '0.0');
    final rcptNoCtrl = TextEditingController();
    String selectedMode = 'Cash';
    bool printReceipt = true;

    // Empty initial row with all 11 fields
    List<Map<String, TextEditingController>> itemRows = [
      {
        'name': TextEditingController(),
        'qty': TextEditingController(text: '1'),
        'batch': TextEditingController(),
        'exp': TextEditingController(),
        'omrp': TextEditingController(),
        'mrp': TextEditingController(),
        'rate': TextEditingController(),
        'dis': TextEditingController(text: '0.0'),
        'gst': TextEditingController(text: '5.0'),
      }
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalBillAmount = 0.0;
          for (var row in itemRows) {
            final qStr = row['qty']!.text.split('+').first.trim();
            final q = double.tryParse(qStr) ?? 0.0;
            final r = double.tryParse(row['rate']!.text) ?? 0.0;
            final dis = double.tryParse(row['dis']!.text) ?? 0.0;
            final gst = double.tryParse(row['gst']!.text) ?? 0.0;

            final subtotal = q * r * (1.0 - (dis / 100.0));
            final lineTotal = subtotal * (1.0 + (gst / 100.0));
            totalBillAmount += lineTotal;
          }
          final paidAmt = double.tryParse(paidAmtCtrl.text) ?? 0.0;
          final netBalanceAdded = (totalBillAmount - paidAmt).clamp(0.0, 9999999.0);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.blue, size: 24),
                const SizedBox(width: 10),
                Text('Add Purchase Bill (${party.name})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: invNoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Invoice / Bill No. *',
                              hintText: 'e.g. A000937',
                              prefixIcon: Icon(Icons.numbers, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: invDateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Invoice Date',
                              hintText: 'e.g. 30/07/2026',
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Purchased Medicines List:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              itemRows.add({
                                'name': TextEditingController(),
                                'qty': TextEditingController(text: '1'),
                                'batch': TextEditingController(),
                                'exp': TextEditingController(),
                                'omrp': TextEditingController(),
                                'mrp': TextEditingController(),
                                'rate': TextEditingController(),
                                'dis': TextEditingController(text: '0.0'),
                                'gst': TextEditingController(text: '5.0'),
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ Add Medicine Row'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(width: 24, child: Text('Sr.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          Expanded(flex: 7, child: Text('Medicine / Product Name & Packing', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 3, child: Text('Qty + Free', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 3, child: Text('Batch No.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 3, child: Text('Expiry Date', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 3, child: Text('O.MRP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 3, child: Text('MRP (₹)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 3, child: Text('Rate (₹)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 2, child: Text('Dis%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 2, child: Text('GST%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 4),
                          Expanded(flex: 3, child: Text('Total (₹)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          SizedBox(width: 32),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    ...List.generate(itemRows.length, (idx) {
                      final row = itemRows[idx];

                      final qStr = row['qty']!.text.split('+').first.trim();
                      final qVal = double.tryParse(qStr) ?? 0.0;
                      final rVal = double.tryParse(row['rate']!.text) ?? 0.0;
                      final disVal = double.tryParse(row['dis']!.text) ?? 0.0;
                      final gstVal = double.tryParse(row['gst']!.text) ?? 0.0;
                      final subtotal = qVal * rVal * (1.0 - (disVal / 100.0));
                      final rowTotal = subtotal * (1.0 + (gstVal / 100.0));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text('${idx + 1}.', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              flex: 7,
                              child: Autocomplete<MedicineMasterModel>(
                                optionsBuilder: (TextEditingValue textEditingValue) async {
                                  final query = textEditingValue.text.trim();
                                  if (query.isEmpty) return const Iterable<MedicineMasterModel>.empty();

                                  List<MedicineMasterModel> results = [];
                                  if (PlatformUtils.isDesktop) {
                                    final dbRes = await SqliteService.instance.searchMedicines(query);
                                    results.addAll(dbRes);
                                  }
                                  final invRes = provider.inventory.where((i) =>
                                    i.medicineName.toLowerCase().contains(query.toLowerCase())
                                  );
                                  for (var i in invRes) {
                                    if (!results.any((r) => r.medicineName.toLowerCase() == i.medicineName.toLowerCase())) {
                                      results.add(MedicineMasterModel(
                                        id: 0,
                                        medicineName: i.medicineName,
                                        composition: i.batchNumber,
                                        manufacturer: '',
                                        mrp: i.mrp,
                                      ));
                                    }
                                  }
                                  return results;
                                },
                                displayStringForOption: (MedicineMasterModel option) => option.medicineName,
                                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                  if (row['name']!.text.isNotEmpty && textEditingController.text.isEmpty) {
                                    textEditingController.text = row['name']!.text;
                                  }
                                  textEditingController.addListener(() {
                                    row['name']!.text = textEditingController.text;
                                  });
                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      hintText: 'Search or type medicine name...',
                                      isDense: true,
                                      contentPadding: EdgeInsets.all(6),
                                    ),
                                  );
                                },
                                onSelected: (MedicineMasterModel selection) {
                                  setDialogState(() {
                                    row['name']!.text = selection.medicineName;
                                    if (selection.mrp > 0) {
                                      row['mrp']!.text = selection.mrp.toStringAsFixed(2);
                                      row['omrp']!.text = selection.mrp.toStringAsFixed(2);
                                    }
                                  });
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4.0,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 280,
                                        constraints: const BoxConstraints(maxHeight: 180),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context, int index) {
                                            final option = options.elementAt(index);
                                            return ListTile(
                                              dense: true,
                                              title: Text(option.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              subtitle: Text('MRP: ₹${option.mrp.toStringAsFixed(2)}${option.manufacturer != null && option.manufacturer!.isNotEmpty ? ' | ${option.manufacturer}' : ''}', style: const TextStyle(fontSize: 10)),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row['qty'],
                                onChanged: (_) => setDialogState(() {}),
                                decoration: const InputDecoration(hintText: '1', isDense: true, contentPadding: EdgeInsets.all(6)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row['batch'],
                                decoration: const InputDecoration(hintText: 'Batch No.', isDense: true, contentPadding: EdgeInsets.all(6)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row['exp'],
                                decoration: const InputDecoration(hintText: 'MM/YY', isDense: true, contentPadding: EdgeInsets.all(6)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row['omrp'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(hintText: 'Old MRP', isDense: true, contentPadding: EdgeInsets.all(6)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row['mrp'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(hintText: 'MRP', isDense: true, contentPadding: EdgeInsets.all(6)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row['rate'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setDialogState(() {}),
                                decoration: const InputDecoration(hintText: 'Rate', isDense: true, contentPadding: EdgeInsets.all(6)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row['dis'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setDialogState(() {}),
                                decoration: const InputDecoration(hintText: '0', isDense: true, contentPadding: EdgeInsets.all(6)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row['gst'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setDialogState(() {}),
                                decoration: const InputDecoration(hintText: '5', isDense: true, contentPadding: EdgeInsets.all(6)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '₹${rowTotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue),
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                onPressed: itemRows.length > 1
                                    ? () => setDialogState(() => itemRows.removeAt(idx))
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Invoice Amount (₹):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('₹${totalBillAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Net Balance Added to Due (₹):', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  Text(
                                    '₹${netBalanceAdded.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: paidAmtCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Paid Amount Now (₹)',
                                    hintText: '0.0 (Enter cash paid if any)',
                                    prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                                    isDense: true,
                                    fillColor: Colors.white,
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedMode,
                                  decoration: InputDecoration(
                                    labelText: 'Payment Mode',
                                    prefixIcon: const Icon(Icons.account_balance_wallet, size: 16),
                                    isDense: true,
                                    fillColor: Colors.white,
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                    DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / Online')),
                                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedMode = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: rcptNoCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Receipt Slip No.',
                                    hintText: 'e.g. 27822',
                                    prefixIcon: const Icon(Icons.receipt, size: 16),
                                    isDense: true,
                                    fillColor: Colors.white,
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (paidAmt > 0) ...[
                            const SizedBox(height: 6),
                            CheckboxListTile(
                              value: printReceipt,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              title: const Text('Generate & Print Receipt Slip (Pink Slip)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                              onChanged: (val) => setDialogState(() => printReceipt = val ?? true),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Save Purchase Bill & Add Stock'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                onPressed: () async {
                  final invNo = invNoCtrl.text.trim();
                  if (invNo.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter Invoice Number')),
                    );
                    return;
                  }

                  int addedCount = 0;
                  List<String> itemSummaryLines = [];
                  for (var row in itemRows) {
                    final medName = row['name']!.text.trim();
                    if (medName.isEmpty) continue;
                    final bNo = row['batch']!.text.trim().isNotEmpty ? row['batch']!.text.trim() : 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                    final exp = row['exp']!.text.trim().isNotEmpty ? row['exp']!.text.trim() : '12/28';

                    final qStr = row['qty']!.text.split('+').first.trim();
                    final q = int.tryParse(qStr) ?? 1;
                    final r = double.tryParse(row['rate']!.text) ?? 0.0;
                    final m = double.tryParse(row['mrp']!.text) ?? (r > 0 ? r * 1.2 : 100.0);

                    // 1. Add to active store Inventory stock with Supplier Name linked
                    await provider.addInventory(InventoryModel(
                      medicineName: medName,
                      batchNumber: bNo,
                      expiryDate: exp,
                      quantity: q,
                      mrp: m,
                      salePrice: m,
                      purchasePrice: r,
                      supplierName: party.name,
                    ));

                    itemSummaryLines.add('$medName (Qty: $q, Batch: $bNo, Exp: $exp, Rate: ₹${r.toStringAsFixed(2)}, MRP: ₹${m.toStringAsFixed(2)})');

                    // 2. Auto-Save New Medicine to Master Database (SQLite) if not present
                    if (PlatformUtils.isDesktop) {
                      final existing = await SqliteService.instance.searchMedicines(medName);
                      final exactMatch = existing.any((item) => item.medicineName.trim().toLowerCase() == medName.toLowerCase());
                      if (!exactMatch) {
                        await SqliteService.instance.insertMedicine(MedicineMasterModel(
                          id: 0,
                          medicineName: medName,
                          composition: 'Batch $bNo',
                          manufacturer: party.name,
                          mrp: m,
                        ));
                      }
                    }

                    addedCount++;
                  }

                  final detailedRemarks = 'Purchase Invoice #$invNo ($addedCount items):\n• ${itemSummaryLines.join('\n• ')}';

                  await provider.addVoucher(VoucherModel(
                    voucherNumber: invNo,
                    type: 'PURCHASE',
                    partyName: party.name,
                    partyPhone: party.phone,
                    amount: totalBillAmount,
                    paymentMode: paidAmt > 0 ? (paidAmt >= totalBillAmount ? 'Cash' : 'Part Payment') : 'Credit',
                    category: 'Stock Purchase',
                    referenceNumber: invNo,
                    remarks: detailedRemarks,
                    createdAt: DateTime.now(),
                  ));

                  if (party.partyType == 'Supplier') {
                    await provider.addSupplierDue(party.id, totalBillAmount);
                  }

                  // If immediate payment is made, settle paid amount and generate voucher / receipt
                  VoucherModel? paymentVoucher;
                  if (paidAmt > 0 && party.partyType == 'Supplier') {
                    final rcptNo = rcptNoCtrl.text.trim().isNotEmpty ? rcptNoCtrl.text.trim() : invNo;
                    paymentVoucher = await provider.paySupplier(
                      party.id,
                      paidAmt,
                      paymentMode: selectedMode,
                      referenceNumber: rcptNo,
                      remarks: 'Paid against Bill #$invNo',
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('✓ Purchase Bill #$invNo saved! $addedCount medicines added to stock & master DB.'),
                    ),
                  );

                  if (printReceipt && paidAmt > 0 && paymentVoucher != null) {
                    final remBal = (netBalanceAdded).clamp(0.0, 9999999.0);
                    final pdfBytes = await PdfService.generatePaymentReceiptPdf(
                      voucherNumber: paymentVoucher.voucherNumber,
                      partyName: party.name,
                      partyPhone: party.phone,
                      amountPaid: paidAmt,
                      paymentMode: selectedMode,
                      referenceNumber: rcptNoCtrl.text.trim().isNotEmpty ? rcptNoCtrl.text.trim() : invNo,
                      remarks: 'Paid against Bill #$invNo',
                      createdAt: DateTime.now(),
                      remainingBalance: remBal,
                      agencyName: party.name,
                      agencyAddress: 'Wholesale Distributor',
                    );

                    await Printing.layoutPdf(
                      onLayout: (PdfPageFormat format) async => pdfBytes,
                      name: 'Payment_Receipt_${party.name}_${paymentVoucher.voucherNumber}',
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteTransaction(BuildContext context, PartyItem party, PartyTransaction transaction, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Text('Delete Transaction?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this ${transaction.type} transaction for ${party.name}?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type: ${transaction.type}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Ref #: ${transaction.refNumber}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Amount: ₹${transaction.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '✓ Deleting this transaction will automatically update the party khata due balance.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final obj = transaction.rawObject;
              if (obj is VoucherModel) {
                await provider.deleteVoucher(obj);
              } else if (obj is BillModel) {
                await provider.deleteBill(obj);
              } else if (obj is CustomerPaymentModel) {
                await provider.deleteCustomerPayment(obj);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('✓ Transaction deleted and ledger balance updated.'),
                  ),
                );
              }
            },
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }



  Future<void> _importCsvFile(BuildContext context, DashboardProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      final filePath = result.files.first.path;

      String csvString = '';
      if (filePath != null) {
        final file = File(filePath);
        csvString = await file.readAsString();
      } else if (fileBytes != null) {
        csvString = utf8.decode(fileBytes);
      }

      if (csvString.trim().isEmpty) return;

      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(csvString);
      if (rows.isEmpty) return;

      int nameIdx = -1, phoneIdx = -1, addrIdx = -1, getIdx = -1, giveIdx = -1;
      bool hasHeader = false;

      final firstRow = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      for (int i = 0; i < firstRow.length; i++) {
        final h = firstRow[i];
        if (h.contains('party name') || h.contains('customer name') || (nameIdx == -1 && h.contains('name'))) {
          nameIdx = i;
          hasHeader = true;
        } else if (h.contains('phone no & address') || h.contains('phone') || h.contains('mobile') || h.contains('contact')) {
          phoneIdx = i;
          hasHeader = true;
        } else if (h.contains('address') && !h.contains('phone')) {
          addrIdx = i;
          hasHeader = true;
        } else if (h.contains('receivable') || h.contains('get')) {
          getIdx = i;
          hasHeader = true;
        } else if (h.contains('payable') || h.contains('give') || h.contains('due')) {
          giveIdx = i;
          hasHeader = true;
        }
      }

      if (nameIdx == -1) nameIdx = 1;
      if (phoneIdx == -1) phoneIdx = 2;
      if (addrIdx == -1) addrIdx = 3;
      if (getIdx == -1) getIdx = 4;
      if (giveIdx == -1) giveIdx = 5;

      final dataRows = hasHeader ? rows.sublist(1) : rows;
      List<CustomerModel> imported = [];

      for (var row in dataRows) {
        if (row.isEmpty) continue;
        final name = nameIdx < row.length ? row[nameIdx].toString().trim() : '';
        if (name.isEmpty) continue;

        final phonePart = phoneIdx >= 0 && phoneIdx < row.length ? row[phoneIdx].toString().trim() : '';
        final addrPart = addrIdx >= 0 && addrIdx < row.length ? row[addrIdx].toString().trim() : '';

        String contactDetails = '';
        if (phonePart.isNotEmpty && addrPart.isNotEmpty) {
          contactDetails = phonePart.contains(addrPart) ? phonePart : '$phonePart - $addrPart';
        } else if (phonePart.isNotEmpty) {
          contactDetails = phonePart;
        } else if (addrPart.isNotEmpty) {
          contactDetails = addrPart;
        } else {
          contactDetails = 'N/A';
        }

        final getStr = getIdx >= 0 && getIdx < row.length ? row[getIdx].toString().replaceAll(',', '').trim() : '0';
        final giveStr = giveIdx >= 0 && giveIdx < row.length ? row[giveIdx].toString().replaceAll(',', '').trim() : '0';

        final getAmt = double.tryParse(getStr) ?? 0.0;
        final giveAmt = double.tryParse(giveStr) ?? 0.0;
        final netBal = getAmt - giveAmt;

        imported.add(CustomerModel(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}_${imported.length}',
          name: name,
          phone: contactDetails,
          pendingBalance: netBal,
        ));
      }

      if (imported.isNotEmpty) {
        await provider.importCustomerList(imported);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('✓ Successfully imported ${imported.length} customers into Cloud & Local Database!'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error importing CSV: $e'),
        ),
      );
    }
  }

  Future<void> _importSupplierCsvFile(BuildContext context, DashboardProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      final filePath = result.files.first.path;

      String csvString = '';
      if (filePath != null) {
        final file = File(filePath);
        csvString = await file.readAsString();
      } else if (fileBytes != null) {
        csvString = utf8.decode(fileBytes);
      }

      if (csvString.trim().isEmpty) return;

      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(csvString);
      if (rows.isEmpty) return;

      int nameIdx = -1, phoneIdx = -1, dueIdx = -1, gstinIdx = -1, addressIdx = -1;
      bool hasHeader = false;

      final firstRow = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      for (int i = 0; i < firstRow.length; i++) {
        final h = firstRow[i];
        if (h.contains('party name') || h.contains('supplier name') || (nameIdx == -1 && h.contains('name'))) {
          nameIdx = i;
          hasHeader = true;
        } else if (h.contains('phone no & address') || h.contains('phone') || h.contains('contact') || h.contains('mobile')) {
          phoneIdx = i;
          hasHeader = true;
        } else if (h.contains('payable') || h.contains('due') || h.contains('balance') || h.contains('amount')) {
          dueIdx = i;
          hasHeader = true;
        } else if (h.contains('gst')) {
          gstinIdx = i;
          hasHeader = true;
        } else if (h.contains('address') && !h.contains('phone')) {
          addressIdx = i;
          hasHeader = true;
        }
      }

      if (nameIdx == -1) nameIdx = 1;
      if (phoneIdx == -1) phoneIdx = 2;
      if (dueIdx == -1) dueIdx = 5; // Default to Payable Balance for Wholesale Suppliers

      final dataRows = hasHeader ? rows.sublist(1) : rows;
      List<SupplierModel> imported = [];

      for (var row in dataRows) {
        if (row.isEmpty) continue;
        final name = nameIdx < row.length ? row[nameIdx].toString().trim() : '';
        if (name.isEmpty) continue;

        final phonePart = phoneIdx >= 0 && phoneIdx < row.length ? row[phoneIdx].toString().trim() : '';
        final addrPart = addressIdx >= 0 && addressIdx < row.length ? row[addressIdx].toString().trim() : '';

        String contactInfo = '';
        if (phonePart.isNotEmpty && addrPart.isNotEmpty) {
          contactInfo = phonePart.contains(addrPart) ? phonePart : '$phonePart - $addrPart';
        } else if (phonePart.isNotEmpty) {
          contactInfo = phonePart;
        } else if (addrPart.isNotEmpty) {
          contactInfo = addrPart;
        } else {
          contactInfo = 'N/A';
        }

        final dueStr = dueIdx >= 0 && dueIdx < row.length ? row[dueIdx].toString().replaceAll(',', '').trim() : '0';
        final gstin = gstinIdx >= 0 && gstinIdx < row.length ? row[gstinIdx].toString().trim() : null;

        final dueAmt = double.tryParse(dueStr) ?? 0.0;

        imported.add(SupplierModel(
          id: 'sup_${DateTime.now().millisecondsSinceEpoch}_${imported.length}',
          name: name,
          contact: contactInfo,
          due: dueAmt,
          gstin: gstin,
          address: addrPart.isNotEmpty ? addrPart : null,
        ));
      }

      if (imported.isNotEmpty) {
        await provider.importSupplierList(imported);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('✓ Successfully imported ${imported.length} Wholesale Suppliers/Agencies!'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error importing Wholesale Suppliers CSV: $e'),
        ),
      );
    }
  }

  void _showImportChoiceDialog(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.file_upload, color: Colors.indigo, size: 26),
            SizedBox(width: 10),
            Text('Choose Excel/CSV Import Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aap kis type ka data import karna chahte hain? Inme se option select karein:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _importCsvFile(context, provider);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.person, color: Colors.blue, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('👨‍💼 Customer Khata Ledgers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                          SizedBox(height: 2),
                          Text('Import customer names, mobile, receivable (Len-den) amounts', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _importSupplierCsvFile(context, provider);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.business, color: Colors.orange, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🏭 Wholesale Suppliers / Agencies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                          SizedBox(height: 2),
                          Text('Import distributor agencies, contact numbers, GST, and due payments', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final allParties = _getAllParties(provider);

    if (_selectedPartyId == null && allParties.isNotEmpty) {
      _selectedPartyId = allParties.first.id;
    }

    final selectedParty = allParties.firstWhere(
      (p) => p.id == _selectedPartyId,
      orElse: () => allParties.isNotEmpty ? allParties.first : PartyItem(id: '', name: 'No Party', phone: '', amount: 0.0, partyType: 'Supplier'),
    );

    final transactions = selectedParty.id.isNotEmpty ? _getPartyTransactions(selectedParty, provider) : <PartyTransaction>[];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategoryFilter,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Parties & Agencies')),
                      DropdownMenuItem(value: 'SUPPLIERS', child: Text('Wholesale Suppliers / Agencies')),
                      DropdownMenuItem(value: 'CUSTOMERS', child: Text('Customers (Khata Ledgers)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategoryFilter = val;
                          _selectedPartyId = null;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          onChanged: (val) => setState(() => _transactionSearchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search Ref No., Type...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: selectedParty.id.isNotEmpty && selectedParty.partyType == 'Supplier'
                            ? () => _showAddPurchaseBillDialog(context, selectedParty, provider)
                            : null,
                        icon: const Icon(Icons.add_shopping_cart, size: 16, color: Colors.blue),
                        label: const Text('+ Add Purchase Bill', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: selectedParty.id.isNotEmpty
                            ? () => _showAddPaymentDialog(context, selectedParty, provider, isPaymentOut: true)
                            : null,
                        icon: const Icon(Icons.call_made, size: 16, color: Colors.orange),
                        label: const Text('Payment Out', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: selectedParty.id.isNotEmpty
                            ? () => _showAddPaymentDialog(context, selectedParty, provider, isPaymentOut: false)
                            : null,
                        icon: const Icon(Icons.call_received, size: 16, color: AppColors.success),
                        label: const Text('Payment In', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.success),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showImportChoiceDialog(context, provider),
                        icon: const Icon(Icons.file_upload, size: 16, color: Colors.indigo),
                        label: const Text('Import CSV/Excel', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.indigo),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddPartyDialog(context, provider),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('+ Add Party', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ================= 2. MAIN 2-COLUMN SPLIT PANEL =================
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- LEFT COLUMN: PARTIES DIRECTORY LIST ----------------
                SizedBox(
                  width: 340,
                  child: CustomCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Quick Add Party & Search Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _partySearchQuery = val),
                                decoration: InputDecoration(
                                  hintText: 'Search Party Name...',
                                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _showAddPartyDialog(context, provider),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person_add, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // List Table Headers
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('PARTY NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight)),
                              Text('AMOUNT (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Parties List View
                        Expanded(
                          child: allParties.isEmpty
                              ? const Center(child: Text('No parties found.', style: TextStyle(color: AppColors.textMuted)))
                              : ListView.builder(
                                  itemCount: allParties.length,
                                  itemBuilder: (context, idx) {
                                    final p = allParties[idx];
                                    final isSelected = p.id == _selectedPartyId;

                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedPartyId = p.id;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                                          border: Border(
                                            left: BorderSide(
                                              color: isSelected ? AppColors.primary : Colors.transparent,
                                              width: 4,
                                            ),
                                            bottom: const BorderSide(color: AppColors.border, width: 0.5),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    p.name,
                                                    style: TextStyle(
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                      fontSize: 13,
                                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (p.phone.isNotEmpty)
                                                    Text(
                                                      '${p.partyType} • ${p.phone}',
                                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              p.amount > 0 ? p.amount.toStringAsFixed(2) : '0.00',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: p.amount > 0
                                                    ? (p.partyType == 'Supplier' ? Colors.orange : AppColors.warning)
                                                    : AppColors.success,
                                              ),
                                            ),
                                          ],
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
                const SizedBox(width: 16),

                // ---------------- RIGHT COLUMN: SELECTED PARTY LEDGER DETAILS ----------------
                Expanded(
                  child: selectedParty.id.isEmpty
                      ? const CustomCard(
                          child: Center(child: Text('Select a party from the left directory to view details.')),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // A. PARTY PROFILE HEADER CARD
                            CustomCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                selectedParty.name,
                                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: selectedParty.partyType == 'Supplier'
                                                    ? Colors.purple.withValues(alpha: 0.15)
                                                    : Colors.blue.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                selectedParty.partyType.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: selectedParty.partyType == 'Supplier' ? Colors.purple : Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              Text('Phone: ${selectedParty.phone.isNotEmpty ? selectedParty.phone : 'N/A'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                              if (selectedParty.gstin != null && selectedParty.gstin!.isNotEmpty) ...[
                                                const SizedBox(width: 16),
                                                const Icon(Icons.receipt, size: 14, color: AppColors.textSecondary),
                                                const SizedBox(width: 4),
                                                Text('GSTIN: ${selectedParty.gstin}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                              ],
                                              if (selectedParty.address != null && selectedParty.address!.isNotEmpty) ...[
                                                const SizedBox(width: 16),
                                                const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                                                const SizedBox(width: 4),
                                                Text('Loc: ${selectedParty.address}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quick Action Card Right Side + Delete Party Button
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: selectedParty.amount > 0
                                              ? (selectedParty.partyType == 'Supplier' ? Colors.orange.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1))
                                              : AppColors.success.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: selectedParty.amount > 0
                                                ? (selectedParty.partyType == 'Supplier' ? Colors.orange : AppColors.warning)
                                                : AppColors.success,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              selectedParty.partyType == 'Supplier' ? 'Net Due to Pay:' : 'Net Pending to Collect:',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '₹${selectedParty.amount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: selectedParty.amount > 0
                                                    ? (selectedParty.partyType == 'Supplier' ? Colors.orange : AppColors.warning)
                                                    : AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever_outlined, color: Colors.red, size: 24),
                                        tooltip: 'Delete Party Profile',
                                        onPressed: () => _confirmDeleteParty(context, selectedParty, provider),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // B. TRANSACTIONS LEDGER TABLE CARD
                            Expanded(
                              child: CustomCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Header Bar
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Transactions Ledger (${transactions.length})',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.print, size: 18, color: AppColors.primary),
                                                  tooltip: 'Print Ledger Statement',
                                                  onPressed: () {
                                                    // Print statement
                                                  },
                                                ),
                                                if (selectedParty.partyType == 'Supplier') ...[
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _showAddPurchaseBillDialog(context, selectedParty, provider),
                                                    icon: const Icon(Icons.add_shopping_cart, size: 14),
                                                    label: const Text('+ Add Purchase Bill', style: TextStyle(fontSize: 11)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.blue.shade700,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed: () => _showAddPaymentDialog(
                                                    context,
                                                    selectedParty,
                                                    provider,
                                                    isPaymentOut: selectedParty.partyType == 'Supplier',
                                                  ),
                                                  icon: Icon(selectedParty.partyType == 'Supplier' ? Icons.call_made : Icons.call_received, size: 14),
                                                  label: Text(selectedParty.partyType == 'Supplier' ? '+ Add Payment Out' : '+ Add Payment In', style: const TextStyle(fontSize: 11)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: selectedParty.partyType == 'Supplier' ? Colors.orange : AppColors.success,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),

                                    // Table View
                                    Expanded(
                                      child: transactions.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No transactions recorded for this party yet.',
                                                style: TextStyle(color: AppColors.textMuted),
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: DataTable(
                                                  columnSpacing: 18,
                                                  showCheckboxColumn: false,
                                                  columns: const [
                                                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                                    DataColumn(label: Text('Ref Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                                    DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                                                    DataColumn(label: Text('Total (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                                    DataColumn(label: Text('Status / Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                                                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                                  ],
                                                rows: transactions.map((t) {
                                                  final isOut = t.type == 'Payment-Out' || t.type == 'Purchase';
                                                  return DataRow(
                                                    onSelectChanged: (_) => _showTransactionDetailsDialog(context, selectedParty, t, provider),
                                                    cells: [
                                                      DataCell(
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: isOut ? Colors.orange.withValues(alpha: 0.12) : AppColors.success.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            t.type,
                                                            style: TextStyle(
                                                              color: isOut ? Colors.orange.shade800 : AppColors.success,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(Text(t.refNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                                                      DataCell(Text(DateFormat('dd/MM/yyyy, hh:mm a').format(t.date), style: const TextStyle(fontSize: 12))),
                                                      DataCell(Text('₹${t.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                      DataCell(
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text(t.status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                                            if (t.remarks != null && t.remarks!.isNotEmpty)
                                                              Text(t.remarks!, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                          ],
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                                                              tooltip: 'View Transaction Details',
                                                              onPressed: () => _showTransactionDetailsDialog(context, selectedParty, t, provider),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                              tooltip: 'Delete Transaction',
                                                              onPressed: () => _deleteTransaction(context, selectedParty, t, provider),
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
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
