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
import '../../../data/models/purchase_bill_model.dart';
import '../../../data/models/bill_model.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/medicine_master_model.dart';
import '../../../data/services/sqlite_service.dart';
import '../../../data/services/pdf_service.dart';
import '../../../data/services/bill_ocr_service.dart';
import '../../../core/utils/platform_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../common/widgets/custom_card.dart';
import '../../common/widgets/loading_overlay.dart';

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

  static void showAddPurchaseBillDialogWithPreFill({
    required BuildContext context,
    required PartyItem party,
    required DashboardProvider provider,
    ScannedBillModel? initialScannedBill,
    VoidCallback? onBillSaved,
  }) => _PartiesScreenState.showAddPurchaseBillDialogWithPreFill(
    context: context,
    party: party,
    provider: provider,
    initialScannedBill: initialScannedBill,
    onBillSaved: onBillSaved,
  );

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
        amount: provider.getSupplierPendingDue(s),
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
        amount: provider.getCustomerPendingBalance(c),
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
        final bName = b.customerName.trim().toLowerCase();
        final matchesName = bName.isNotEmpty && bName == pName;
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
        final cName = p.customerName.trim().toLowerCase();
        final matchesName = cName.isNotEmpty && cName == pName;
        final matchesPhone = pPhone.isNotEmpty && p.customerPhone.trim() == pPhone;
        final matchesId = party.id.isNotEmpty && p.customerId == party.id;
        if (matchesName || matchesPhone || matchesId) {
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
        final vName = v.partyName.trim().toLowerCase();
        final matchesName = vName.isNotEmpty && vName == pName;
        final matchesPhone = pPhone.isNotEmpty && v.partyPhone.trim() == pPhone;
        if (matchesName || matchesPhone) {
          if (v.type == 'SALE') {
            list.add(PartyTransaction(
              id: v.id ?? 'vouch_s_${v.voucherNumber}',
              type: 'Sale',
              refNumber: v.voucherNumber,
              date: v.createdAt,
              totalAmount: v.amount,
              balance: v.amount,
              status: v.paymentMode == 'Credit' ? 'Unpaid' : 'Paid',
              remarks: v.remarks,
              rawObject: v,
            ));
          }
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
                    await provider.paySupplier(
                      party.id,
                      amt,
                      paymentMode: payMode,
                      referenceNumber: refCtrl.text.trim(),
                      remarks: remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'Paid to ${party.name}',
                    );
                  } else {
                    await provider.addVoucher(VoucherModel(
                      voucherNumber: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      type: 'PAYMENT',
                      partyName: party.name,
                      partyPhone: party.phone,
                      amount: amt,
                      paymentMode: payMode,
                      category: 'Misc Expense',
                      referenceNumber: refCtrl.text.trim(),
                      remarks: remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'Paid to ${party.name}',
                      createdAt: DateTime.now(),
                    ));
                  }
                } else {
                  if (party.partyType == 'Customer') {
                    await provider.collectCustomerPayment(
                      party.id,
                      amt,
                      paymentMode: payMode,
                      referenceNumber: refCtrl.text.trim(),
                      remarks: remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'Received from ${party.name}',
                    );
                  } else {
                    await provider.addVoucher(VoucherModel(
                      voucherNumber: 'RCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      type: 'RECEIPT',
                      partyName: party.name,
                      partyPhone: party.phone,
                      amount: amt,
                      paymentMode: payMode,
                      category: 'Misc Income',
                      referenceNumber: refCtrl.text.trim(),
                      remarks: remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'Received from ${party.name}',
                      createdAt: DateTime.now(),
                    ));
                  }
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

  void _showAddCustomerSaleDialog(BuildContext context, PartyItem party, DashboardProvider provider) {
    final amtCtrl = TextEditingController();
    final paidAmtCtrl = TextEditingController(text: '0.0');
    final refCtrl = TextEditingController(text: 'SAL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final remarkCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart, color: Colors.red, size: 24),
            const SizedBox(width: 10),
            Text('Add Sale / Udhar Entry (${party.name})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Pending Balance:', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  Text('₹${party.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total Sale Amount (₹) *',
                hintText: 'e.g. 450.00',
                prefixIcon: Icon(Icons.currency_rupee, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: paidAmtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount Paid Now (₹)',
                hintText: '0.0 for full credit/udhar',
                prefixIcon: Icon(Icons.payments_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                labelText: 'Bill / Ref Number',
                prefixIcon: Icon(Icons.numbers, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              decoration: const InputDecoration(
                labelText: 'Sale Description / Medicine Details (Optional)',
                hintText: 'e.g. Dawaat & Syrup Items',
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
              final paidNow = double.tryParse(paidAmtCtrl.text) ?? 0.0;

              if (amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid Sale Amount')),
                );
                return;
              }

              await provider.addCustomerSale(
                party.id,
                amt,
                amountPaidNow: paidNow,
                referenceNumber: refCtrl.text.trim(),
                remarks: remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'Udhar / Manual Sale to ${party.name}',
              );

              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.success,
                  content: Text('✓ Sale entry of ₹$amt added for ${party.name}!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Save Sale Entry'),
          ),
        ],
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



  void _showAddPurchaseBillDialog(BuildContext context, PartyItem party, DashboardProvider provider) {
    showAddPurchaseBillDialogWithPreFill(
      context: context,
      party: party,
      provider: provider,
    );
  }

  static void showAddPurchaseBillDialogWithPreFill({
    required BuildContext context,
    required PartyItem party,
    required DashboardProvider provider,
    ScannedBillModel? initialScannedBill,
    VoidCallback? onBillSaved,
  }) {
    final invNoCtrl = TextEditingController(
      text: (initialScannedBill != null && initialScannedBill.invoiceNumber.isNotEmpty)
          ? initialScannedBill.invoiceNumber
          : 'A${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
  final invDateCtrl = TextEditingController(
    text: (initialScannedBill != null && initialScannedBill.invoiceDate.isNotEmpty)
        ? initialScannedBill.invoiceDate
        : DateFormat('dd/MM/yyyy').format(DateTime.now()),
  );
  final billDiscCtrl = TextEditingController(
    text: (initialScannedBill != null && initialScannedBill.billDiscountPercent > 0)
        ? initialScannedBill.billDiscountPercent.toStringAsFixed(1)
        : '0.0',
  );
  final paidAmtCtrl = TextEditingController(text: '0.0');
  final rcptNoCtrl = TextEditingController();
  String selectedMode = 'Cash';
  bool printReceipt = false;
  bool isSavingBill = false;

  List<Map<String, TextEditingController>> itemRows = [];

  if (initialScannedBill != null && initialScannedBill.items.isNotEmpty) {
    for (var item in initialScannedBill.items) {
      double effectiveRate = item.purchaseRate;
      if (item.quantity > 1 && item.purchaseRate > 0) {
        if ((item.purchaseRate * item.quantity - item.netAmount).abs() > (item.netAmount * 0.4)) {
          effectiveRate = item.purchaseRate / item.quantity;
        } else if ((item.purchaseRate - item.netAmount).abs() < 1.0) {
          effectiveRate = item.purchaseRate / item.quantity;
        }
      }

      itemRows.add({
        'name': TextEditingController(text: item.productName),
        'qty': TextEditingController(text: '${item.quantity}${item.freeQty > 0 ? " + ${item.freeQty}" : ""}'),
        'pack': TextEditingController(text: item.pack.isNotEmpty ? item.pack : '1S'),
        'batch': TextEditingController(text: item.batchNumber),
        'exp': TextEditingController(text: item.expiryDate),
        'hsn': TextEditingController(text: item.hsn.isNotEmpty ? item.hsn : '3004'),
        'omrp': TextEditingController(text: item.mrp > 0 ? item.mrp.toStringAsFixed(2) : ''),
        'mrp': TextEditingController(text: item.mrp > 0 ? item.mrp.toStringAsFixed(2) : ''),
        'rate': TextEditingController(text: effectiveRate > 0 ? effectiveRate.toStringAsFixed(2) : ''),
        'sch': TextEditingController(text: item.schemeDiscount.toStringAsFixed(1)),
        'dis': TextEditingController(text: item.discountPercent.toStringAsFixed(1)),
        'gst': TextEditingController(text: item.gstPercent.toStringAsFixed(1)),
      });
    }
  } else {
    itemRows = [
      {
        'name': TextEditingController(),
        'qty': TextEditingController(text: '1'),
        'pack': TextEditingController(text: '1S'),
        'batch': TextEditingController(),
        'exp': TextEditingController(),
        'hsn': TextEditingController(text: '3004'),
        'omrp': TextEditingController(),
        'mrp': TextEditingController(),
        'rate': TextEditingController(),
        'sch': TextEditingController(text: '0.0'),
        'dis': TextEditingController(text: '0.0'),
        'gst': TextEditingController(text: '5.0'),
      }
    ];
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        double billDiscPercent = double.tryParse(billDiscCtrl.text) ?? 0.0;
        double totalSubTotal = 0.0;
        double totalDis = 0.0;
        double totalTaxable = 0.0;
        double totalTax = 0.0;

        for (var row in itemRows) {
          final qStr = row['qty']!.text.split('+').first.trim();
          final q = double.tryParse(qStr) ?? 0.0;
          final r = double.tryParse(row['rate']!.text) ?? 0.0;
          final sch = double.tryParse(row['sch']?.text ?? '0.0') ?? 0.0;
          final dis = double.tryParse(row['dis']!.text) ?? 0.0;
          final gst = double.tryParse(row['gst']!.text) ?? 0.0;

          final lineGross = q * r;
          final schDisAmt = lineGross * (sch / 100.0);
          final afterScheme = lineGross - schDisAmt;
          final tradeDisAmt = afterScheme * (dis / 100.0);
          final lineTaxable = afterScheme - tradeDisAmt;

          totalSubTotal += lineGross;
          totalDis += (schDisAmt + tradeDisAmt);
          totalTaxable += lineTaxable;

          if (gst > 0) {
            double effectiveTaxable = lineTaxable * (1.0 - (billDiscPercent / 100.0));
            totalTax += effectiveTaxable * (gst / 100.0);
          }
        }

        double billDiscAmount = totalTaxable * (billDiscPercent / 100.0);
        double netTaxableTotal = totalTaxable - billDiscAmount;

        double totalBillAmount = (initialScannedBill != null && initialScannedBill.grandTotal > 0 && billDiscPercent == initialScannedBill.billDiscountPercent)
            ? initialScannedBill.grandTotal
            : (netTaxableTotal + totalTax).roundToDouble();

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
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
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
                      const SizedBox(width: 12),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: billDiscCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Bill Disc (%)',
                            hintText: 'e.g. 4.0',
                            prefixIcon: Icon(Icons.percent, size: 18),
                          ),
                          onChanged: (_) => setDialogState(() {}),
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
                              'sch': TextEditingController(text: '0.0'),
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
                        Expanded(flex: 2, child: Text('Sch.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
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

                  Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      child: Column(
                        children: List.generate(itemRows.length, (idx) {
                          final row = itemRows[idx];

                          final qStr = row['qty']!.text.split('+').first.trim();
                          final qVal = double.tryParse(qStr) ?? 0.0;
                          final rVal = double.tryParse(row['rate']!.text) ?? 0.0;
                          final subtotal = qVal * rVal;
                          final rowTotal = subtotal;

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
                                    controller: row['sch'],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setDialogState(() {}),
                                    decoration: const InputDecoration(hintText: '0', isDense: true, contentPadding: EdgeInsets.all(6)),
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
                      ),
                    ),
                  ),
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
                            onChanged: (val) => setDialogState(() => printReceipt = val ?? false),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: isSavingBill
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(isSavingBill ? 'Saving Bill...' : 'Save Purchase Bill & Add Stock'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
              onPressed: isSavingBill ? null : () async {
                final invNo = invNoCtrl.text.trim();
                if (invNo.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Invoice Number')),
                  );
                  return;
                }

                setDialogState(() {
                  isSavingBill = true;
                });
                AppLoadingOverlay.show(context, message: 'Saving Purchase Bill & Updating Stock...');

                try {
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

                    final sch = double.tryParse(row['sch']?.text ?? '0.0') ?? 0.0;
                    final dis = double.tryParse(row['dis']!.text) ?? 0.0;
                    final gst = double.tryParse(row['gst']!.text) ?? 0.0;
                    final pack = row['pack']?.text.trim() ?? '1S';
                    final hsn = row['hsn']?.text.trim() ?? '3004';

                    itemSummaryLines.add('$medName (Qty: $q, Batch: $bNo, Exp: $exp, Rate: ₹${r.toStringAsFixed(2)}, Sch: ₹${sch.toStringAsFixed(2)}, MRP: ₹${m.toStringAsFixed(2)}, Dis: ${dis.toStringAsFixed(1)}%, GST: ${gst.toStringAsFixed(1)}%, Pack: $pack, HSN: $hsn)');

                    // Auto-Save New Medicine to Master Database (SQLite) if not present
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

                  final detailedRemarks = 'Purchase Invoice #$invNo (Agency: ${party.name}, $addedCount items):\n• ${itemSummaryLines.join('\n• ')}';

                  final mode = paidAmt > 0 ? (paidAmt >= totalBillAmount ? 'Cash' : 'Part Payment') : 'Credit';

                  final List<Map<String, dynamic>> purchaseItems = itemRows.map((r) {
                    final mName = r['name']!.text.trim();
                    final bNo = r['batch']!.text.trim().isNotEmpty ? r['batch']!.text.trim() : 'N/A';
                    final exp = r['exp']!.text.trim().isNotEmpty ? r['exp']!.text.trim() : 'N/A';
                    final qStr = r['qty']!.text.split('+').first.trim();
                    final qty = int.tryParse(qStr) ?? 1;
                    final rate = double.tryParse(r['rate']!.text) ?? 0.0;
                    final mrp = double.tryParse(r['mrp']!.text) ?? (rate > 0 ? rate * 1.2 : 0.0);
                    return {
                      'medicineName': mName,
                      'batchNumber': bNo,
                      'expiryDate': exp,
                      'qty': qty,
                      'purchasePrice': rate,
                      'mrp': mrp,
                      'salePrice': mrp,
                    };
                  }).where((i) => (i['medicineName'] as String).isNotEmpty).toList();

                  final pendingDue = (totalBillAmount - paidAmt).clamp(0.0, 9999999.0);
                  await provider.addPurchaseBill(PurchaseBillModel(
                    billNumber: invNo,
                    supplierName: party.name,
                    supplierPhone: party.phone,
                    billDate: DateTime.tryParse(invDateCtrl.text.trim()) ?? DateTime.now(),
                    itemsCount: purchaseItems.length,
                    totalAmount: totalBillAmount,
                    paidAmount: paidAmt,
                    dueAmount: pendingDue,
                    paymentMode: selectedMode,
                    receiptNo: rcptNoCtrl.text.trim().isNotEmpty ? rcptNoCtrl.text.trim() : invNo,
                    items: purchaseItems,
                    createdAt: DateTime.now(),
                  ));

                  if (party.partyType == 'Supplier') {
                    await provider.addSupplierPurchase(
                      party.id,
                      totalBillAmount,
                      billNumber: invNo,
                      remarks: detailedRemarks,
                      paymentMode: mode,
                      partyPhone: party.phone,
                    );
                  } else {
                    await provider.addVoucher(VoucherModel(
                      voucherNumber: invNo,
                      type: 'PURCHASE',
                      partyName: party.name,
                      partyPhone: party.phone,
                      amount: totalBillAmount,
                      paymentMode: mode,
                      category: 'Stock Purchase',
                      referenceNumber: invNo,
                      remarks: detailedRemarks,
                      createdAt: DateTime.now(),
                    ));
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

                  if (onBillSaved != null) {
                    onBillSaved();
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
                } catch (e) {
                  debugPrint('Error saving purchase bill: $e');
                  setDialogState(() {
                    isSavingBill = false;
                  });
                } finally {
                  if (context.mounted) {
                    AppLoadingOverlay.hide(context);
                  }
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

  static String _numberToIndianWords(double amount) {
    int n = amount.round();
    if (n <= 0) return "Zero";

    final units = [
      "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
      "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"
    ];
    final tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"];

    String convertLessThanThousand(int num) {
      String current = "";
      if (num % 100 < 20) {
        current = units[num % 100];
        num = num ~/ 100;
      } else {
        current = units[num % 10];
        num = num ~/ 10;
        current = tens[num % 10] + (current.isNotEmpty ? " $current" : "");
        num = num ~/ 10;
      }
      if (num == 0) return current;
      return "${units[num]} Hundred${current.isNotEmpty ? ' and $current' : ''}";
    }

    String result = "";
    if (n ~/ 10000000 > 0) {
      result += "${convertLessThanThousand(n ~/ 10000000)} Crore ";
      n %= 10000000;
    }
    if (n ~/ 100000 > 0) {
      result += "${convertLessThanThousand(n ~/ 100000)} Lakh ";
      n %= 100000;
    }
    if (n ~/ 1000 > 0) {
      result += "${convertLessThanThousand(n ~/ 1000)} Thousand ";
      n %= 1000;
    }
    if (n > 0) {
      result += convertLessThanThousand(n);
    }
    return result.trim();
  }

  void _showPaymentReceiptSlipDialog(
    BuildContext context,
    PartyItem party,
    PartyTransaction transaction,
  ) {
    final amountInWords = _numberToIndianWords(transaction.totalAmount);

    String agencyName = party.name;
    final agencyMatch = RegExp(r'Agency:\s*([^,\n\(\)]+)', caseSensitive: false).firstMatch(transaction.remarks ?? '');
    if (agencyMatch != null && agencyMatch.group(1) != null && agencyMatch.group(1)!.trim().isNotEmpty) {
      agencyName = agencyMatch.group(1)!.trim();
    }

    String billRef = '-';
    final billMatch = RegExp(r'(?:Bill|Invoice)\s*#?\s*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(transaction.remarks ?? '');
    if (billMatch != null && billMatch.group(1) != null) {
      billRef = billMatch.group(1)!;
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(transaction.date);

    final isPaymentOut = transaction.type == 'Payment-Out' || transaction.type.toUpperCase().contains('OUT');

    final headerTitle = isPaymentOut ? agencyName.toUpperCase() : 'M/s RAJESH MEDICOSE';
    final headerAddress = isPaymentOut
        ? ((party.address != null && party.address!.trim().isNotEmpty) ? party.address! : 'Wholesale Pharma Distributor')
        : 'CHARWALA, CHARWALA (SIRSA)';
    final headerContact = isPaymentOut
        ? (party.phone.trim().isNotEmpty ? 'Mob. ${party.phone}' : '')
        : 'Mob. 9050524678';

    final receivedFromText = isPaymentOut ? 'M/s RAJESH MEDICOSE' : 'M/s ${party.name}';
    final signatoryText = isPaymentOut ? agencyName.toUpperCase() : 'RAJESH MEDICOSE';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F5), // Traditional Pink Slip Tint
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.pink.shade700, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headerAddress,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        if (headerContact.isNotEmpty)
                          Text(
                            headerContact,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transaction.type.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('No. ${transaction.refNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Dated: $dateStr', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(thickness: 1.5, color: Colors.black54),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 170,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1.5),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.pink.shade100,
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('Bill No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(flex: 2, child: Text('Rs. P.', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(billRef, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text(transaction.totalAmount.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text('L. Disc.', style: TextStyle(fontSize: 10, color: Colors.black54))),
                              Expanded(flex: 2, child: Text('-', textAlign: TextAlign.right, style: TextStyle(fontSize: 10))),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black),
                        Container(
                          color: Colors.pink.shade50,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              const Expanded(flex: 3, child: Text('G. Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('₹${transaction.totalAmount.toStringAsFixed(0)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pink.shade900))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Colors.black, height: 1.6),
                            children: [
                              const TextSpan(text: 'Received with thanks from '),
                              TextSpan(text: '$receivedFromText\n', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const TextSpan(text: 'a sum of Rupees '),
                              TextSpan(text: '$amountInWords\n', style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                              TextSpan(text: 'on account of bill ${billRef != "-" ? "#$billRef" : ""} by Cash / Online Transfer.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('For : $signatoryText', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 24),
                              const Text('Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1, color: Colors.black38),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final pdfBytes = await PdfService.generatePaymentReceiptPdf(
                        voucherNumber: transaction.refNumber,
                        partyName: party.name,
                        partyPhone: party.phone,
                        amountPaid: transaction.totalAmount,
                        paymentMode: 'Cash / Online',
                        referenceNumber: billRef != '-' ? billRef : transaction.refNumber,
                        remarks: transaction.remarks ?? '',
                        createdAt: transaction.date,
                        remainingBalance: 0.0,
                        agencyName: agencyName,
                      );
                      await Printing.layoutPdf(
                        onLayout: (PdfPageFormat format) async => pdfBytes,
                        name: 'PaymentReceipt_${transaction.refNumber}',
                      );
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print Receipt Slip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade700,
                      foregroundColor: Colors.white,
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

  void _showTransactionDetailsDialog(
    BuildContext context,
    PartyItem party,
    PartyTransaction transaction,
    DashboardProvider provider,
  ) {
    if (transaction.type == 'Payment-Out' || transaction.type == 'Payment-In' || transaction.type.toUpperCase().contains('PAYMENT')) {
      _showPaymentReceiptSlipDialog(context, party, transaction);
      return;
    }

    double currBill = transaction.totalAmount;
    double cashReceived = 0.0;

    double prevBal = (party.amount - (transaction.type == 'Purchase' || transaction.type == 'Sale' ? currBill : -cashReceived)).clamp(0.0, 9999999.0);
    double totalOs = prevBal + currBill - cashReceived;

    List<Map<String, dynamic>> items = [];
    double subTotal = currBill;
    double totalDis = 0.0;
    double gst5Taxable = 0.0, gst5Tax = 0.0;
    double gst12Taxable = 0.0, gst12Tax = 0.0;
    double gst18Taxable = 0.0, gst18Tax = 0.0;
    double totalTaxable = 0.0, totalTax = 0.0;
    double roundOff = 0.0;
    int totalItems = 0;
    int totalQty = 0;

    final raw = transaction.rawObject;
    BillModel? bill;
    if (raw is BillModel) {
      bill = raw;
    } else {
      try {
        bill = provider.bills.firstWhere(
          (b) => b.billNumber == transaction.refNumber || (b.id != null && b.id == transaction.id),
        );
      } catch (_) {}
    }

    if (bill != null) {
      subTotal = bill.totalAmount;
      totalDis = bill.discount;
      totalTax = bill.gstAmount;
      currBill = bill.netAmount;
      totalTaxable = (subTotal - totalDis).clamp(0.0, 9999999.0);
      
      if (bill.gstPercentage == 5.0 || bill.gstPercentage == 0.0) {
        gst5Taxable = totalTaxable;
        gst5Tax = totalTax;
      } else if (bill.gstPercentage == 12.0) {
        gst12Taxable = totalTaxable;
        gst12Tax = totalTax;
      } else if (bill.gstPercentage == 18.0) {
        gst18Taxable = totalTaxable;
        gst18Tax = totalTax;
      }

      totalItems = bill.items.length;
      for (var item in bill.items) {
        totalQty += item.quantity;
        items.add({
          'name': item.medicineName,
          'batch': item.batchNumber,
          'exp': item.expiryDate,
          'qty': item.quantity,
          'free': item.freeQty,
          'pack': item.pack.isNotEmpty ? item.pack : '1S',
          'hsn': item.hsn.isNotEmpty ? item.hsn : '3004',
          'mrp': item.mrp,
          'rate': item.salePrice,
          'sch': item.schemeDiscPercent,
          'dis': item.tradeDiscPercent,
          'gst': item.gstPercent,
          'amount': item.grossAmount,
        });
      }

    } else {
      String remarksToParse = transaction.remarks ?? '';
      if (raw is VoucherModel && raw.remarks.isNotEmpty) {
        remarksToParse = raw.remarks;
      }

      final rawLines = remarksToParse.split(RegExp(r'[\n•]'));
      for (var line in rawLines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('Purchase Invoice') || trimmed.startsWith('Sales Invoice') || trimmed.contains('items):')) {
          continue;
        }

        final openParen = trimmed.indexOf('(');
        final closeParen = trimmed.lastIndexOf(')');

        if (openParen != -1 && closeParen > openParen) {
          final name = trimmed.substring(0, openParen).trim();
          final detailsStr = trimmed.substring(openParen + 1, closeParen);

          int qty = 1;
          String batch = 'B001';
          String exp = '12/28';
          double rate = 0.0;
          double sch = 0.0;
          double mrp = 0.0;
          double dis = 0.0;
          double gst = 0.0;
          String pack = '1S';
          String hsn = '3004';

          final pairs = detailsStr.split(',');
          for (var pair in pairs) {
            final parts = pair.split(':');
            if (parts.length >= 2) {
              final key = parts[0].trim().toLowerCase();
              final val = parts.sublist(1).join(':').trim().replaceAll('₹', '').replaceAll('%', '');

              if (key.contains('qty')) {
                final qVal = val.split('+').first.trim();
                qty = int.tryParse(qVal) ?? 1;
              } else if (key.contains('batch')) {
                batch = val.isNotEmpty ? val : 'B001';
              } else if (key.contains('exp')) {
                exp = val.isNotEmpty ? val : '12/28';
              } else if (key.contains('rate')) {
                rate = double.tryParse(val) ?? 0.0;
              } else if (key.contains('sch')) {
                sch = double.tryParse(val) ?? 0.0;
              } else if (key.contains('mrp')) {
                mrp = double.tryParse(val) ?? 0.0;
              } else if (key.contains('dis')) {
                dis = double.tryParse(val) ?? 0.0;
              } else if (key.contains('gst')) {
                gst = double.tryParse(val) ?? 0.0;
              } else if (key.contains('pack')) {
                pack = val.isNotEmpty ? val : '1S';
              } else if (key.contains('hsn')) {
                hsn = val.isNotEmpty ? val : '3004';
              }
            }
          }

          if (mrp == 0.0) mrp = rate;

          final grossLine = qty * rate;

          totalQty += qty;
          items.add({
            'name': name.isNotEmpty ? name : 'Medicine',
            'batch': batch,
            'exp': exp,
            'qty': qty,
            'free': 0,
            'pack': pack,
            'hsn': hsn,
            'mrp': mrp,
            'rate': rate,
            'sch': sch,
            'dis': dis,
            'gst': gst,
            'amount': grossLine,
          });

        }
      }

      if (items.isEmpty && remarksToParse.isNotEmpty && !remarksToParse.startsWith('Paid') && !remarksToParse.startsWith('Received')) {
        final lines = remarksToParse.split(RegExp(r'[\n,]'));
        for (var line in lines) {
          final clean = line.replaceAll(RegExp(r'^.*Invoice.*?:?'), '').replaceAll('•', '').trim();
          if (clean.isNotEmpty && clean.length > 2 && !clean.contains('items):')) {
            items.add({
              'name': clean,
              'batch': 'B001',
              'exp': '12/28',
              'qty': 1,
              'free': 0,
              'pack': '1S',
              'hsn': '3004',
              'mrp': currBill,
              'rate': currBill,
              'sch': 0.0,
              'dis': 0.0,
              'gst': 0.0,
              'amount': currBill,
            });
            totalQty += 1;
          }
        }
      }

      if (items.isEmpty) {
        final invItems = provider.inventory.where((i) => i.supplierName.trim().toLowerCase() == party.name.trim().toLowerCase()).toList();
        if (invItems.isNotEmpty) {
          for (var item in invItems) {
            totalQty += item.quantity;
            items.add({
              'name': item.medicineName,
              'batch': item.batchNumber,
              'exp': item.expiryDate,
              'qty': item.quantity,
              'free': 0,
              'pack': '1S',
              'hsn': '3004',
              'mrp': item.mrp,
              'rate': item.purchasePrice > 0 ? item.purchasePrice : item.salePrice,
              'dis': 0.0,
              'gst': 0.0,
              'amount': (item.purchasePrice > 0 ? item.purchasePrice : item.salePrice) * item.quantity,
            });
          }
        }
      }

      if (items.isNotEmpty) {
        double calcSubTotal = 0.0;
        double calcTotalDis = 0.0;
        double calcGst5Taxable = 0.0, calcGst5Tax = 0.0;
        double calcGst12Taxable = 0.0, calcGst12Tax = 0.0;
        double calcGst18Taxable = 0.0, calcGst18Tax = 0.0;

        for (var it in items) {
          final q = (it['qty'] as num?)?.toInt() ?? 1;
          final r = (it['rate'] as num?)?.toDouble() ?? 0.0;
          final sch = (it['sch'] as num?)?.toDouble() ?? 0.0;
          final d = (it['dis'] as num?)?.toDouble() ?? 0.0;
          final g = (it['gst'] as num?)?.toDouble() ?? 0.0;

          final grossLine = q * r;
          final afterScheme = grossLine * (1.0 - (sch / 100.0));
          final schDisAmt = grossLine * (sch / 100.0);
          final tradeDisAmt = afterScheme * (d / 100.0);
          final lineDis = schDisAmt + tradeDisAmt;
          final netLineTaxable = grossLine - lineDis;

          calcSubTotal += grossLine;
          calcTotalDis += lineDis;

          if (g == 5.0) {
            calcGst5Taxable += netLineTaxable;
            calcGst5Tax += netLineTaxable * 0.05;
          } else if (g == 12.0) {
            calcGst12Taxable += netLineTaxable;
            calcGst12Tax += netLineTaxable * 0.12;
          } else if (g == 18.0) {
            calcGst18Taxable += netLineTaxable;
            calcGst18Tax += netLineTaxable * 0.18;
          }
        }

        subTotal = calcSubTotal;

        double calcSchDis = 0.0;
        for (var it in items) {
          final q = (it['qty'] as num?)?.toInt() ?? 1;
          final r = (it['rate'] as num?)?.toDouble() ?? 0.0;
          final sch = (it['sch'] as num?)?.toDouble() ?? 0.0;
          calcSchDis += (q * r) * (sch / 100.0);
        }

        totalDis = calcSchDis > 0 ? calcSchDis : calcTotalDis;

        double netBase = (subTotal - totalDis).clamp(0.0, 9999999.0);
        totalTaxable = netBase;

        double finalGst5Tax = 0.0, finalGst12Tax = 0.0, finalGst18Tax = 0.0;
        for (var it in items) {
          final q = (it['qty'] as num?)?.toInt() ?? 1;
          final r = (it['rate'] as num?)?.toDouble() ?? 0.0;
          final sch = (it['sch'] as num?)?.toDouble() ?? 0.0;
          final g = (it['gst'] as num?)?.toDouble() ?? 0.0;

          final grossLine = q * r;
          final afterSch = grossLine * (1.0 - (sch / 100.0));

          if (g == 5.0) {
            gst5Taxable += afterSch;
            finalGst5Tax += afterSch * 0.05;
          } else if (g == 12.0) {
            gst12Taxable += afterSch;
            finalGst12Tax += afterSch * 0.12;
          } else if (g == 18.0) {
            gst18Taxable += afterSch;
            finalGst18Tax += afterSch * 0.18;
          }
        }

        gst5Tax = finalGst5Tax;
        gst12Tax = finalGst12Tax;
        gst18Tax = finalGst18Tax;
        totalTax = gst5Tax + gst12Tax + gst18Tax;

        if (transaction.totalAmount > 0) {
          currBill = transaction.totalAmount;
        } else {
          currBill = (subTotal - totalDis + totalTax).roundToDouble();
        }
        roundOff = currBill - (subTotal - totalDis + totalTax);
      }
      totalItems = items.length;
      if (totalQty == 0) totalQty = 1;
    }

    double cgst = totalTax / 2.0;
    double sgst = totalTax / 2.0;
    String displayPartyName = party.name;
    final agencyMatch = RegExp(r'Agency:\s*([^,\n\(\)]+)', caseSensitive: false).firstMatch(transaction.remarks ?? '');
    if (agencyMatch != null && agencyMatch.group(1) != null && agencyMatch.group(1)!.trim().isNotEmpty) {
      displayPartyName = agencyMatch.group(1)!.trim();
    }

    String amountInWords = _numberToIndianWords(currBill > 0 ? currBill : cashReceived);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 980,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.blue, size: 26),
                        const SizedBox(width: 8),
                        Text(
                          'Invoice Preview (${transaction.refNumber})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black87, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'M/s RAJESH MEDICOSE',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                                ),
                                const Text('CHARWALA, CHARWALA', style: TextStyle(fontSize: 11, color: Colors.black87)),
                                const Text('Ph.No.: 9050524678', style: TextStyle(fontSize: 11, color: Colors.black87)),
                                const Text('D.L.No.: 7970/7970-OBR | GST: 06AAAAA0000A1Z5', style: TextStyle(fontSize: 10, color: Colors.black87)),
                                const SizedBox(height: 6),
                                Text(
                                  'Agency / Supplier: $displayPartyName',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black54),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'GST INVOICE - CREDIT',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Invoice No.: ${transaction.refNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    'Date: ${DateFormat('dd-MM-yyyy').format(transaction.date)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    'Due Date: ${DateFormat('dd-MM-yyyy').format(transaction.date)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.black87)),
                        child: Column(
                          children: [
                            Container(
                              color: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: const Row(
                                children: [
                                  SizedBox(width: 24, child: Text('Sn.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 32, child: Text('Qty.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 32, child: Text('Free', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 50, child: Text('Pack', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 4, child: Text('Product', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Batch', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 40, child: Text('Exp.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 55, child: Text('HSN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 45, child: Text('MRP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 45, child: Text('Rate', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 35, child: Text('Sch.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 35, child: Text('Dis.%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 35, child: Text('GST%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 55, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.black87),

                            if (items.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Transaction Type: ${transaction.type} | Ref: ${transaction.refNumber} | Amount: ₹${transaction.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              Column(
                                children: items.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final it = entry.value;
                                  final schVal = (it['sch'] as num?)?.toDouble() ?? 0.0;
                                  final q = (it['qty'] as num?)?.toInt() ?? 1;
                                  final r = (it['rate'] as num?)?.toDouble() ?? 0.0;
                                  final lineGross = q * r;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 24, child: Text('${idx + 1}.', style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 32, child: Text('$q', style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 32, child: Text('${it['free']}', style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 50, child: Text('${it['pack']}', style: const TextStyle(fontSize: 10))),
                                        Expanded(flex: 4, child: Text('${it['name']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 2, child: Text('${it['batch']}', style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 40, child: Text('${it['exp']}', style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 55, child: Text('${it['hsn']}', style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 45, child: Text((it['mrp'] as double).toStringAsFixed(2), style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 45, child: Text(r.toStringAsFixed(2), style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 35, child: Text(schVal.toStringAsFixed(2), style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 35, child: Text((it['dis'] as double).toStringAsFixed(1), style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 35, child: Text((it['gst'] as double).toStringAsFixed(1), style: const TextStyle(fontSize: 10))),
                                        SizedBox(width: 55, child: Text(lineGross.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  );
                                }).toList(),

                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3F4F6),
                                border: Border(bottom: BorderSide(color: Colors.black)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('CASH RECEIVED: ${cashReceived.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text('PREV. BAL.: ${prevBal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text('CURR. BILL: ${currBill.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text('TOTAL O/S: ${totalOs.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                                ],
                              ),
                            ),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      border: Border(right: BorderSide(color: Colors.black)),
                                    ),
                                    child: Table(
                                      border: TableBorder.all(color: Colors.black45, width: 0.5),
                                      children: [
                                        const TableRow(
                                          decoration: BoxDecoration(color: Color(0xFFE5E7EB)),
                                          children: [
                                            Padding(padding: EdgeInsets.all(2), child: Text('GST%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                                            Padding(padding: EdgeInsets.all(2), child: Text('TAXABLE AMT.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                                            Padding(padding: EdgeInsets.all(2), child: Text('TAX AMT.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                        TableRow(children: [
                                          const Padding(padding: EdgeInsets.all(2), child: Text('GST 5.00', style: TextStyle(fontSize: 9))),
                                          Padding(padding: const EdgeInsets.all(2), child: Text(gst5Taxable.toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                                          Padding(padding: const EdgeInsets.all(2), child: Text(gst5Tax.toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                                        ]),
                                        TableRow(children: [
                                          const Padding(padding: EdgeInsets.all(2), child: Text('GST 12.00', style: TextStyle(fontSize: 9))),
                                          Padding(padding: const EdgeInsets.all(2), child: Text(gst12Taxable.toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                                          Padding(padding: const EdgeInsets.all(2), child: Text(gst12Tax.toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                                        ]),
                                        TableRow(children: [
                                          const Padding(padding: EdgeInsets.all(2), child: Text('GST 18.00', style: TextStyle(fontSize: 9))),
                                          Padding(padding: const EdgeInsets.all(2), child: Text(gst18Taxable.toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                                          Padding(padding: const EdgeInsets.all(2), child: Text(gst18Tax.toStringAsFixed(2), style: const TextStyle(fontSize: 9))),
                                        ]),
                                        const TableRow(children: [
                                          Padding(padding: EdgeInsets.all(2), child: Text('EXEMPT', style: TextStyle(fontSize: 9))),
                                          Padding(padding: EdgeInsets.all(2), child: Text('0.00', style: TextStyle(fontSize: 9))),
                                          Padding(padding: EdgeInsets.all(2), child: Text('0.00', style: TextStyle(fontSize: 9))),
                                        ]),
                                        TableRow(children: [
                                          const Padding(padding: EdgeInsets.all(2), child: Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(2), child: Text(totalTaxable.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(2), child: Text(totalTax.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                                        ]),
                                      ],
                                    ),
                                  ),
                                ),

                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      border: Border(right: BorderSide(color: Colors.black)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Total Items :-', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text('$totalItems', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Total Qty :-', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text('$totalQty', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('SUB TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text(subTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('DISCOUNT', style: TextStyle(fontSize: 10)),
                                            Text(totalDis.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('CGST PAYABLE', style: TextStyle(fontSize: 10)),
                                            Text(cgst.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('SGST PAYABLE', style: TextStyle(fontSize: 10)),
                                            Text(sgst.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('ROUND OFF', style: TextStyle(fontSize: 10)),
                                            Text(roundOff.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                        const Divider(height: 6, color: Colors.black),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('GRAND TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            Text(currBill.toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.black)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rs. ${amountInWords.isNotEmpty ? amountInWords : "Zero"} only',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Terms & Conditions:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                          Text('Goods once sold will not be taken back or exchanged.', style: TextStyle(fontSize: 8)),
                                          Text('All disputes subject to Jurisdiction only.', style: TextStyle(fontSize: 8)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('For ${party.name}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 16),
                                          const Text('Auth. Sign.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final pdfBytes = await PdfService.generateWholesaleInvoicePdf(
                          invoiceNumber: transaction.refNumber,
                          date: transaction.date,
                          partyName: party.name,
                          partyAddress: party.address ?? 'Wholesale Distributor',
                          items: items,
                          cashReceived: cashReceived,
                          prevBalance: prevBal,
                          currBill: currBill,
                          totalOutstanding: totalOs,
                          subTotal: subTotal,
                          discount: totalDis,
                          gst5Taxable: gst5Taxable,
                          gst5Tax: gst5Tax,
                          gst12Taxable: gst12Taxable,
                          gst12Tax: gst12Tax,
                          gst18Taxable: gst18Taxable,
                          gst18Tax: gst18Tax,
                          exemptTaxable: 0.0,
                          totalTaxable: totalTaxable,
                          totalTax: totalTax,
                          cgst: cgst,
                          sgst: sgst,
                          roundOff: roundOff,
                          grandTotal: currBill > 0 ? currBill : cashReceived,
                        );
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => pdfBytes,
                          name: 'Invoice_${transaction.refNumber}',
                        );
                      },
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print / Thermal PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
          // 1. CLEAN & MODERN TOP HEADER BAR
          Row(
            children: [
              // Dynamic Title based on Active Sidebar Selection / Category Filter
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedCategoryFilter == 'CUSTOMERS'
                        ? Icons.person_outline
                        : (_selectedCategoryFilter == 'SUPPLIERS' ? Icons.local_shipping_outlined : Icons.menu_book),
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedCategoryFilter == 'CUSTOMERS'
                        ? 'Customer Khata (ग्राहक खाता)'
                        : (_selectedCategoryFilter == 'SUPPLIERS' ? 'Wholesale Suppliers (थोक विक्रेता)' : 'Khata Ledger & Parties'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: TextField(
                          onChanged: (val) => setState(() => _transactionSearchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search Transactions...',
                            prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            isDense: true,
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showImportChoiceDialog(context, provider),
                      icon: const Icon(Icons.file_upload, size: 15, color: Colors.indigo),
                      label: const Text('Import CSV', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.indigo),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddPartyDialog(context, provider),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: Text(
                        _selectedCategoryFilter == 'CUSTOMERS' ? '+ New Customer' : (_selectedCategoryFilter == 'SUPPLIERS' ? '+ New Wholesaler' : '+ New Party'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
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
                        // Quick Search Row
                        TextField(
                          onChanged: (val) => setState(() => _partySearchQuery = val),
                          decoration: InputDecoration(
                            hintText: _selectedCategoryFilter == 'CUSTOMERS' ? 'Search Customer Name/Mobile...' : 'Search Wholesaler/Agency...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
                              Text('BAL DUE (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Parties List View
                        Expanded(
                          child: allParties.isEmpty
                              ? const Center(child: Text('No entries found.', style: TextStyle(color: AppColors.textMuted)))
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
                                                  Text(
                                                    p.phone.isNotEmpty ? 'Phone: ${p.phone}' : 'No Phone Number',
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
                                    // Header Bar with Specialized Buttons
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
                                                if (selectedParty.partyType == 'Customer') ...[
                                                  ElevatedButton.icon(
                                                    onPressed: () => _showAddCustomerSaleDialog(context, selectedParty, provider),
                                                    icon: const Icon(Icons.add_shopping_cart, size: 14),
                                                    label: const Text('+ Add Sale Entry (उधार)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red.shade700,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _showAddPaymentDialog(
                                                      context,
                                                      selectedParty,
                                                      provider,
                                                      isPaymentOut: false,
                                                    ),
                                                    icon: const Icon(Icons.call_received, size: 14),
                                                    label: const Text('+ Receive Payment (जमा)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.success,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  ElevatedButton.icon(
                                                    onPressed: () => _showAddPurchaseBillDialog(context, selectedParty, provider),
                                                    icon: const Icon(Icons.add_shopping_cart, size: 14),
                                                    label: const Text('+ Add Purchase Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.blue.shade700,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _showAddPaymentDialog(
                                                      context,
                                                      selectedParty,
                                                      provider,
                                                      isPaymentOut: true,
                                                    ),
                                                    icon: const Icon(Icons.call_made, size: 14),
                                                    label: const Text('+ Pay Supplier (भुगतान)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.orange,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    ),
                                                  ),
                                                ],
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
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: DataTable(
                                                  columnSpacing: 14,
                                                  showCheckboxColumn: false,
                                                  columns: const [
                                                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                                    DataColumn(label: Text('Ref Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                                    DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                                                    DataColumn(label: Text('Total (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
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
