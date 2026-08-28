import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/purchase_bill_model.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/medicine_master_model.dart';
import '../../../data/services/sqlite_service.dart';
import '../../../data/services/pdf_service.dart';
import '../../../data/services/license_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../common/widgets/custom_card.dart';

// Unused legacy screens removed.
// ================= 2. MEDICINE MASTER SCREEN (SQLite Browser) =================
class MedicineMasterScreen extends StatefulWidget {
  const MedicineMasterScreen({super.key});

  @override
  State<MedicineMasterScreen> createState() => _MedicineMasterScreenState();
}

class _MedicineMasterScreenState extends State<MedicineMasterScreen> {
  final _searchController = TextEditingController();
  List<MedicineMasterModel> _results = [];
  bool _isLoading = false;

  void _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final data = await SqliteService.instance.searchMedicines(query);
      setState(() {
        _results = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('2.5 Lakh Medicine Master Database', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Instantly query local pre-seeded SQLite database for retail brands and salt compositions.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search Medicine or Salt Composition...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: _search,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _search(_searchController.text),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32)),
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('Type query above (e.g. Paracetamol) and press Search.'))
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, idx) {
                            final med = _results[idx];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE6F4EA),
                                child: Icon(Icons.medication, color: AppColors.primary),
                              ),
                              title: Text(med.medicineName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(med.composition ?? 'No composition salt listed', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(med.manufacturer ?? 'Unknown Manufacturer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  const SizedBox(height: 4),
                                  Text('MRP: ₹${med.mrp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 3. EXPIRY MANAGEMENT SCREEN =================
class ExpiryManagementScreen extends StatelessWidget {
  const ExpiryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final nearExpiry = provider.nearExpiryMedicines;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Expiry Management Desk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: nearExpiry.isEmpty
                  ? const Center(child: Text('No medicines expiring soon!'))
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Medicine Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Batch Number', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Alert Level', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: nearExpiry.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(item.batchNumber)),
                              DataCell(Text(item.expiryDate, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                              DataCell(Text(item.quantity.toString())),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Near Expiry', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
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
    );
  }
}

// ================= 4. PURCHASE ORDERS & INWARD LEDGER SCREEN =================
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  String _searchQuery = '';

  // Local list of purchase bills recorded
  final List<Map<String, dynamic>> _purchaseBills = [];

  void _showNewPurchaseBillDialog(BuildContext context, DashboardProvider provider) {
    String selectedSupplierName = provider.suppliers.isNotEmpty ? provider.suppliers.first.name : '';
    String supplierPhone = provider.suppliers.isNotEmpty ? provider.suppliers.first.contact : '';
    final billNoController = TextEditingController(text: 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final billDateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final paidAmountController = TextEditingController(text: '0.0');
    final receiptNoController = TextEditingController(text: 'RCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    String paymentMode = 'Cash';
    bool generateReceipt = false;

    // Item input controllers
    final itemController = TextEditingController();
    final batchController = TextEditingController();
    final expiryController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final purchasePriceController = TextEditingController();
    final mrpController = TextEditingController();
    final salePriceController = TextEditingController();

    List<Map<String, dynamic>> billItems = [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double totalInvoiceAmount = billItems.fold(0.0, (sum, item) => sum + (item['qty'] * item['purchasePrice']));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text('Record Wholesaler Purchase Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: SizedBox(
                width: 880,
                height: 630,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Supplier & Bill Meta Details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DISTRIBUTOR & INVOICE DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: provider.suppliers.isNotEmpty
                                      ? DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          initialValue: selectedSupplierName.isNotEmpty ? selectedSupplierName : provider.suppliers.first.name,
                                          decoration: InputDecoration(
                                            labelText: 'Select Wholesaler / Supplier',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          ),
                                          items: provider.suppliers.map((sup) {
                                            return DropdownMenuItem(
                                              value: sup.name,
                                              child: Text('${sup.name} (${sup.contact})', overflow: TextOverflow.ellipsis),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setDialogState(() {
                                                selectedSupplierName = val;
                                                final matchedSup = provider.suppliers.firstWhere((s) => s.name == val);
                                                supplierPhone = matchedSup.contact;
                                              });
                                            }
                                          },
                                        )
                                      : TextField(
                                          onChanged: (val) => selectedSupplierName = val,
                                          decoration: InputDecoration(
                                            labelText: 'Distributor Name',
                                            hintText: 'e.g. Mankind Pharma Agency',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: billNoController,
                                    decoration: InputDecoration(
                                      labelText: 'Bill / Invoice No.',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: billDateController,
                                    decoration: InputDecoration(
                                      labelText: 'Invoice Date',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Add Item Form
                      const Text('ADD INCOMING MEDICINE BATCHES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Autocomplete<MedicineMasterModel>(
                              optionsBuilder: (TextEditingValue textEditingValue) async {
                                final query = textEditingValue.text.trim();
                                if (query.isEmpty) {
                                  return const Iterable<MedicineMasterModel>.empty();
                                }

                                // 1. Search SQLite Database (Master Medicine Catalogue)
                                final dbResults = await SqliteService.instance.searchMedicines(query);

                                // 2. Search In-Memory Inventory
                                final invMatches = provider.inventory
                                    .where((i) => i.medicineName.toLowerCase().contains(query.toLowerCase()))
                                    .map((i) => MedicineMasterModel(
                                          id: i.id != null ? int.tryParse(i.id!) ?? 0 : 0,
                                          medicineName: i.medicineName,
                                          mrp: i.mrp,
                                          composition: i.supplierName,
                                        ));

                                // Combine & Deduplicate
                                final Map<String, MedicineMasterModel> combined = {};
                                for (var item in dbResults) {
                                  combined[item.medicineName.toLowerCase()] = item;
                                }
                                for (var item in invMatches) {
                                  if (!combined.containsKey(item.medicineName.toLowerCase())) {
                                    combined[item.medicineName.toLowerCase()] = item;
                                  }
                                }

                                return combined.values.take(15);
                              },
                              displayStringForOption: (MedicineMasterModel option) => option.medicineName,
                              onSelected: (MedicineMasterModel selection) {
                                setDialogState(() {
                                  itemController.text = selection.medicineName;
                                  if (selection.mrp > 0) {
                                    mrpController.text = selection.mrp.toStringAsFixed(2);
                                    salePriceController.text = (selection.mrp * 0.9).toStringAsFixed(2);
                                    purchasePriceController.text = (selection.mrp * 0.75).toStringAsFixed(2);
                                  }
                                });
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                if (textEditingController.text != itemController.text && itemController.text.isNotEmpty && textEditingController.text.isEmpty) {
                                  textEditingController.text = itemController.text;
                                }
                                textEditingController.addListener(() {
                                  if (itemController.text != textEditingController.text) {
                                    itemController.text = textEditingController.text;
                                  }
                                });

                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Medicine / Item Name',
                                    hintText: 'Type 1 letter for suggestion...',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  onSubmitted: (val) => onFieldSubmitted(),
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 6.0,
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 320,
                                      constraints: const BoxConstraints(maxHeight: 220),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        separatorBuilder: (ctx, idx) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final MedicineMasterModel option = options.elementAt(index);
                                          return ListTile(
                                            dense: true,
                                            title: Text(option.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                                            subtitle: option.mrp > 0
                                                ? Text('MRP: ₹${option.mrp.toStringAsFixed(2)} ${option.composition != null && option.composition!.isNotEmpty ? "| ${option.composition}" : ""}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
                                                : null,
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
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: batchController,
                              decoration: InputDecoration(
                                labelText: 'Batch No.',
                                hintText: 'BT-102',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: expiryController,
                              decoration: InputDecoration(
                                labelText: 'Expiry (YYYY-MM)',
                                hintText: '2027-12',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Qty',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: purchasePriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Cost Price (₹)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: mrpController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'MRP (₹)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: salePriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Sale Rate (₹)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              final name = itemController.text.trim();
                              final batch = batchController.text.trim();
                              final exp = expiryController.text.trim();
                              final q = int.tryParse(qtyController.text.trim()) ?? 0;
                              final cost = double.tryParse(purchasePriceController.text.trim()) ?? 0.0;
                              final mrpVal = double.tryParse(mrpController.text.trim()) ?? 0.0;
                              final saleVal = double.tryParse(salePriceController.text.trim()) ?? 0.0;

                              if (name.isEmpty || batch.isEmpty || q <= 0 || cost <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.error,
                                    content: Text('Please enter valid item name, batch number, quantity and cost price.'),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                billItems.add({
                                  'medicineName': name,
                                  'batchNumber': batch,
                                  'expiryDate': exp.isNotEmpty ? exp : '2027-12',
                                  'qty': q,
                                  'purchasePrice': cost,
                                  'mrp': mrpVal > 0 ? mrpVal : cost * 1.2,
                                  'salePrice': saleVal > 0 ? saleVal : (mrpVal > 0 ? mrpVal : cost * 1.15),
                                });
                                itemController.clear();
                                batchController.clear();
                                expiryController.clear();
                                qtyController.text = '1';
                                purchasePriceController.clear();
                                mrpController.clear();
                                salePriceController.clear();
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Items Table
                      const Text('PURCHASE BILL ITEMS LIST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Container(
                        height: 135,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: billItems.isEmpty
                            ? const Center(child: Text('No items added to invoice yet.', style: TextStyle(color: AppColors.textMuted)))
                            : ListView.separated(
                                itemCount: billItems.length,
                                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final itm = billItems[idx];
                                  final lineTotal = itm['qty'] * itm['purchasePrice'];
                                  return ListTile(
                                    dense: true,
                                    title: Text('${itm['medicineName']} (Batch: ${itm['batchNumber']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('Qty: ${itm['qty']} | Cost: ₹${itm['purchasePrice']} | Sale: ₹${itm['salePrice']} | Exp: ${itm['expiryDate']}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('₹${lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                          onPressed: () {
                                            setDialogState(() {
                                              billItems.removeAt(idx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 14),

                      // Settlement & Payment Receipt Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Gross Amount
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Bill Amount', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text('₹${totalInvoiceAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ],
                                ),
                                // Amount Paid Now
                                SizedBox(
                                  width: 165,
                                  child: TextField(
                                    controller: paidAmountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Amount Paid Now (₹)',
                                      prefixText: '₹ ',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onChanged: (val) => setDialogState(() {}),
                                  ),
                                ),
                                // Calculated Pending Due
                                Builder(
                                  builder: (context) {
                                    final paidVal = double.tryParse(paidAmountController.text.trim()) ?? 0.0;
                                    final pendingVal = (totalInvoiceAmount - paidVal).clamp(0.0, 9999999.0);
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Pending Due (बकाया)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${pendingVal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: pendingVal > 0 ? AppColors.error : AppColors.success,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                // Payment Mode Dropdown
                                SizedBox(
                                  width: 140,
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: paymentMode,
                                    items: const [
                                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                      DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / Online')),
                                      DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                                      DropdownMenuItem(value: 'Credit', child: Text('Credit (Udhar)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => paymentMode = val);
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Payment Mode',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            // Payment Receipt Options
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: generateReceipt,
                                      activeColor: AppColors.primary,
                                      onChanged: (val) => setDialogState(() => generateReceipt = val ?? false),
                                    ),
                                    const Text('Generate & Print Payment Receipt Slip for Supplier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  ],
                                ),
                                if (generateReceipt)
                                  SizedBox(
                                    width: 190,
                                    child: TextField(
                                      controller: receiptNoController,
                                      decoration: InputDecoration(
                                        labelText: 'Receipt / Voucher No.',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final supName = selectedSupplierName.trim();
                    final billNo = billNoController.text.trim();
                    final paidNow = double.tryParse(paidAmountController.text.trim()) ?? 0.0;
                    final receiptNo = receiptNoController.text.trim();

                    if (supName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: AppColors.error, content: Text('Please select or enter Wholesaler Distributor Name.')),
                      );
                      return;
                    }
                    if (billItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: AppColors.error, content: Text('Please add at least one medicine batch item to the invoice.')),
                      );
                      return;
                    }

                    // 1. Auto-Save New Medicine Names to Master Database (for future search suggestions)
                    for (var itm in billItems) {
                      final medName = itm['medicineName'].toString().trim();
                      final mrpVal = (itm['mrp'] as num).toDouble();

                      // Auto-save new medicine name to Master DB for future suggestions
                      try {
                        final existing = await SqliteService.instance.searchMedicines(medName);
                        final bool exactFound = existing.any((m) => m.medicineName.trim().toLowerCase() == medName.toLowerCase());
                        if (!exactFound) {
                          await SqliteService.instance.insertMedicine(MedicineMasterModel(
                            id: DateTime.now().millisecondsSinceEpoch % 10000000,
                            medicineName: medName,
                            mrp: mrpVal,
                            manufacturer: supName,
                          ));
                        }
                      } catch (e) {
                        debugPrint('Error inserting new medicine master: $e');
                      }
                    }

                    // 2. Record Supplier Purchase & Update Due
                    final pendingDue = (totalInvoiceAmount - paidNow).clamp(0.0, 9999999.0);
                    SupplierModel? matchedSup;
                    final existingIndex = provider.suppliers.indexWhere(
                      (s) => s.name.trim().toLowerCase() == supName.toLowerCase(),
                    );
                    if (existingIndex != -1) {
                      matchedSup = provider.suppliers[existingIndex];
                    }

                    String supplierId = matchedSup?.id ?? '';
                    if (supplierId.isEmpty) {
                      await provider.addSupplier(SupplierModel(name: supName, contact: supplierPhone, due: 0.0));
                      final createdSup = provider.suppliers.firstWhere(
                        (s) => s.name.trim().toLowerCase() == supName.toLowerCase(),
                        orElse: () => SupplierModel(name: supName, contact: supplierPhone),
                      );
                      supplierId = createdSup.id ?? supName;
                    }

                    // Log purchase bill in supplier ledger if pending due > 0
                    if (pendingDue > 0) {
                      await provider.addSupplierPurchase(
                        supplierId,
                        pendingDue,
                        billNumber: billNo,
                        remarks: 'Bill $billNo total ₹$totalInvoiceAmount (Paid ₹$paidNow)',
                        paymentMode: paymentMode,
                      );
                    }

                    // Record payment voucher if paidNow > 0
                    if (paidNow > 0) {
                      await provider.paySupplier(
                        supplierId,
                        paidNow,
                        paymentMode: paymentMode,
                        referenceNumber: receiptNo,
                        remarks: 'Payment against Purchase Bill #$billNo',
                      );
                    }

                    // 3. Save purchase bill in Firebase
                    await provider.addPurchaseBill(PurchaseBillModel(
                      billNumber: billNo,
                      supplierName: supName,
                      supplierPhone: supplierPhone,
                      billDate: DateTime.tryParse(billDateController.text.trim()) ?? DateTime.now(),
                      itemsCount: billItems.length,
                      totalAmount: totalInvoiceAmount,
                      paidAmount: paidNow,
                      dueAmount: pendingDue,
                      paymentMode: paymentMode,
                      receiptNo: receiptNo,
                      items: billItems,
                      createdAt: DateTime.now(),
                    ));

                    // 4. Optionally Print Supplier Payment Receipt Slip
                    if (generateReceipt && paidNow > 0) {
                      try {
                        final pdfBytes = await PdfService.generatePaymentReceiptPdf(
                          voucherNumber: receiptNo,
                          partyName: supName,
                          partyPhone: supplierPhone,
                          amountPaid: paidNow,
                          paymentMode: paymentMode,
                          referenceNumber: billNo,
                          remarks: 'Wholesale Stock Purchase Payment Slip',
                          createdAt: DateTime.now(),
                          remainingBalance: pendingDue,
                        );
                        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
                      } catch (e) {
                        debugPrint('Error printing payment receipt PDF: $e');
                      }
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('✅ Purchase Invoice "$billNo" recorded & payment receipt generated!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Save Purchase Invoice'),
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
    final provider = Provider.of<DashboardProvider>(context);
    final suppliers = provider.suppliers;

    final purchaseBills = provider.purchaseBills;

    final filteredBills = purchaseBills.where((b) {
      final q = _searchQuery.toLowerCase().trim();
      return q.isEmpty ||
          b.billNumber.toLowerCase().contains(q) ||
          b.supplierName.toLowerCase().contains(q);
    }).toList();

    final totalPurchaseSum = purchaseBills.fold(0.0, (sum, b) => sum + b.totalAmount);
    final totalDueSum = suppliers.fold(0.0, (sum, s) => sum + s.due);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Purchase Bills & Inward Stock Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Record supplier invoices, seed incoming medicine batches, and track wholesaler dues', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showNewPurchaseBillDialog(context, provider),
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Record New Purchase Bill', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Top Metric Cards
          Row(
            children: [
              Expanded(
                child: CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Invoices Logged', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('${purchaseBills.length} Bills (₹${totalPurchaseSum.toStringAsFixed(0)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.local_shipping, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Wholesalers', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('${suppliers.length} Distributors', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance_wallet, color: AppColors.error, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Supplier Dues', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('₹${totalDueSum.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar & Table Container
          Expanded(
            child: CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search purchase bills by bill number or distributor name...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredBills.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                const Text('No Purchase Bills Recorded Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                const SizedBox(height: 6),
                                const Text('Click "Record New Purchase Bill" above to add distributor bills.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  onPressed: () => _showNewPurchaseBillDialog(context, provider),
                                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                                  label: const Text('Record First Purchase Bill'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text('Bill No & Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Distributor / Wholesaler', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Items Count', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Amount Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Due / Credit', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Receipt / Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: filteredBills.map((bill) {
                                  final due = bill.dueAmount;
                                  final paid = bill.paidAmount;
                                  final bDateStr = DateFormat('yyyy-MM-dd').format(bill.billDate);
                                  return DataRow(
                                    cells: [
                                      DataCell(Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(bDateStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        ],
                                      )),
                                      DataCell(Text(bill.supplierName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text('${bill.itemsCount} Batches')),
                                      DataCell(Text('₹${bill.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text('₹${paid.toStringAsFixed(2)}', style: TextStyle(color: paid > 0 ? AppColors.success : AppColors.textMuted, fontWeight: FontWeight.bold))),
                                      DataCell(Text('₹${due.toStringAsFixed(2)}', style: TextStyle(color: due > 0 ? AppColors.error : AppColors.textMuted, fontWeight: FontWeight.bold))),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text(bill.paymentMode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      )),
                                      DataCell(
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          icon: const Icon(Icons.print_outlined, size: 14),
                                          label: const Text('Print Receipt Slip', style: TextStyle(fontSize: 11)),
                                          onPressed: () async {
                                            try {
                                              final pdfBytes = await PdfService.generatePaymentReceiptPdf(
                                                voucherNumber: bill.receiptNo.isNotEmpty ? bill.receiptNo : 'RCP-${bill.billNumber}',
                                                partyName: bill.supplierName,
                                                partyPhone: bill.supplierPhone,
                                                amountPaid: paid,
                                                paymentMode: bill.paymentMode,
                                                referenceNumber: bill.billNumber,
                                                remarks: paid > 0 ? 'Wholesale Stock Purchase Payment Slip' : 'Wholesale Purchase Credit Invoice Voucher',
                                                createdAt: bill.createdAt,
                                                remainingBalance: due,
                                              );
                                              await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
                                            } catch (e) {
                                              debugPrint('Error printing receipt: $e');
                                            }
                                          },
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
    );
  }
}

// ================= 5. SUPPLIERS SCREEN =================
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddSupplierDialog(BuildContext context, DashboardProvider provider) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final dueController = TextEditingController(text: '0.0');
    final gstinController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.local_shipping, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text('Add New Wholesale Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Supplier / Agency Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Mankind Pharma Agency / Sun Stockist',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.business, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Contact Phone *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '10-digit mobile',
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
                            const Text('Initial Due Balance (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: dueController,
                              keyboardType: TextInputType.number,
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
                  const Text('GSTIN Number (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: gstinController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 06AAAAM1234A1Z5',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.badge, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Office / Market Address (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Shop 12, Medicine Market, Sirsa',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                final due = double.tryParse(dueController.text.trim()) ?? 0.0;
                final gstin = gstinController.text.trim();
                final address = addressController.text.trim();

                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('⚠️ Please fill required fields: Supplier Name & Phone Number.'),
                    ),
                  );
                  return;
                }

                final success = await provider.addSupplier(SupplierModel(
                  name: name,
                  contact: phone,
                  due: due,
                  gstin: gstin.isEmpty ? null : gstin,
                  address: address.isEmpty ? null : address,
                ));

                if (!context.mounted) return;
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('⚠️ Supplier "$name" with contact "$phone" already registered!'),
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.success,
                    content: Text('✅ Supplier "$name" added successfully!'),
                  ),
                );
              },
              child: const Text('Save Supplier'),
            ),
          ],
        );
      },
    );
  }

  void _showPaySupplierDialog(BuildContext context, DashboardProvider provider, SupplierModel supplier) {
    final amountController = TextEditingController(text: supplier.due > 0 ? supplier.due.toStringAsFixed(2) : '');
    final refController = TextEditingController();
    final remarksController = TextEditingController();
    String selectedMode = 'Cash';
    bool printReceipt = false;

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
                  Text('Wholesale Supplier Payment Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 420,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                              if (supplier.gstin != null && supplier.gstin!.isNotEmpty)
                                Text('GSTIN: ${supplier.gstin}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
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

                    // Amount Field
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

                    // Payment Mode & Receipt Ref No
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Remarks
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

                    // Print Slip Option Checkbox
                    CheckboxListTile(
                      value: printReceipt,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Generate & Print Payment Receipt Slip (Pink Slip Format)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onChanged: (val) => setDialogState(() => printReceipt = val ?? false),
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
                    final voucher = await provider.paySupplier(
                      supplier.id!,
                      amt,
                      paymentMode: selectedMode,
                      referenceNumber: refNo,
                      remarks: remarks,
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.success, content: Text('✅ Paid ₹${amt.toStringAsFixed(2)} to ${supplier.name}!')),
                    );

                    if (printReceipt && voucher != null) {
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final suppliers = provider.suppliers;

    final filteredSuppliers = suppliers.where((sup) {
      final q = _searchQuery.toLowerCase().trim();
      return q.isEmpty ||
          sup.name.toLowerCase().contains(q) ||
          sup.contact.contains(q) ||
          (sup.gstin != null && sup.gstin!.toLowerCase().contains(q));
    }).toList();

    final totalDue = suppliers.fold(0.0, (sum, sup) => sum + sup.due);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Suppliers Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Total Distributors: ${suppliers.length} | Total Pending Payable: ₹${totalDue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search Supplier Name, Contact or GSTIN...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSupplierDialog(context, provider),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Add Supplier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: filteredSuppliers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          suppliers.isEmpty ? 'No suppliers registered.' : 'No supplier found matching "$_searchQuery"',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Supplier / Agency Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Contact Number', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('GSTIN No.', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Total Orders', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Pending Payable', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredSuppliers.map((sup) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sup.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    if (sup.address != null && sup.address!.isNotEmpty)
                                      Text(sup.address!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              DataCell(Text(sup.contact)),
                              DataCell(Text(sup.gstin ?? 'N/A', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${sup.orders} Orders', style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(
                                '₹${sup.due.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: sup.due > 0 ? AppColors.error : AppColors.success),
                              )),
                              DataCell(
                                Row(
                                  children: [
                                    if (sup.due > 0) ...[
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        ),
                                        onPressed: () => _showPaySupplierDialog(context, provider, sup),
                                        icon: const Icon(Icons.payment, size: 14),
                                        label: const Text('Pay Due', style: TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                      tooltip: 'Delete Supplier Profile',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Supplier Profile?'),
                                            content: Text('Are you sure you want to remove ${sup.name}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                onPressed: () {
                                                  if (sup.id != null) {
                                                    provider.deleteSupplier(sup.id!);
                                                  }
                                                  Navigator.pop(ctx);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Supplier ${sup.name} removed.')),
                                                  );
                                                },
                                                child: const Text('Remove'),
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
        ],
      ),
    );
  }
}

// ================= 6. EXPENSES SCREEN =================
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> mockExpenses = [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Operating Expenses Desk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add Expense')),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: mockExpenses.isEmpty
                  ? const Center(child: Text('No expenses recorded.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Expense Title', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Amount Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: mockExpenses.map((exp) {
                          return DataRow(
                            cells: [
                              DataCell(Text(exp['title'], style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(exp['category'])),
                              DataCell(Text('₹${exp['amount'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(exp['date'])),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 7. PAYMENTS LEDGER =================
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Payments & Transactions History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: CustomCard(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.account_balance_wallet, size: 48, color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('All UPI, Cash, & Card statements are synced.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Go to Reports to view full ledger breakdowns and shifts balancing totals.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 8. USERS SCREEN =================
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> mockUsers = [
      {'name': 'Admin User', 'role': 'Administrator', 'status': 'Active', 'email': 'wisdomcoresolutions@gmail.com'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Staff & Permissions Panel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add User')),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('System Role', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Login Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: mockUsers.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(Text(user['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(user['role'])),
                        DataCell(Text(user['email'])),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(user['status'], style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
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
    );
  }
}

// ================= 9. SETTINGS SCREEN =================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _gstinController;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final provider = Provider.of<DashboardProvider>(context);
      _nameController = TextEditingController(text: provider.pharmacyName);
      _addressController = TextEditingController(text: provider.storeAddress);
      _gstinController = TextEditingController(text: provider.gstin);
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ERP System Configuration Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: CustomCard(
              child: ListView(
                children: [
                  const Text('General Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Pharmacy Name', hintText: 'WisdomPharma'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Store Address', hintText: '123, MG Road, Indore'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _gstinController,
                    decoration: const InputDecoration(labelText: 'GSTIN Registration', hintText: '23AAAAA1111A1Z1'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await provider.updateSettings(
                            name: _nameController.text.trim(),
                            address: _addressController.text.trim(),
                            gstin: _gstinController.text.trim(),
                          );
                          if (!context.mounted) return;
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Settings saved successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save General Details'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Hardware Setup & Prints', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Thermal Printer Receipt Width:', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(width: 16),
                      ChoiceChip(label: const Text('80mm (Standard)'), selected: true, onSelected: (_) {}),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('58mm (Mini)'), selected: false, onSelected: (_) {}),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // License Management Section
                  const Text('Software License & Remote Security', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
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
                                  'Client License ID: ${LicenseService.instance.clientId}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  LicenseService.instance.isBlocked
                                      ? 'Status: BLOCKED / EXPIRED'
                                      : 'Status: ACTIVE (Verified)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: LicenseService.instance.isBlocked ? AppColors.error : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final isOk = await LicenseService.instance.initializeAndVerify();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isOk ? '✓ Software License Active & Verified!' : '⚠️ License Check Failed: ${LicenseService.instance.blockReason}'),
                                    backgroundColor: isOk ? AppColors.success : AppColors.error,
                                  ),
                                );
                                setState(() {});
                              },
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Verify License Now'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clear Cache Section
                  const Text('App Cache & Local Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cleaning_services_rounded, color: Colors.orange, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Clear Local Cache', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                              SizedBox(height: 2),
                              Text(
                                'Phone ki temporary memory clear hogi. Firebase ka koi data delete nahi hoga.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                title: const Row(
                                  children: [
                                    Icon(Icons.cleaning_services_rounded, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Clear Cache?', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                                content: const Text(
                                  'Local temporary data clear hoga.\n\nFirebase pe stored Bills, Customers, Payments — sab safe rahenge.\n\nApp restart ke baad data wapas sync ho jayega.',
                                  style: TextStyle(fontSize: 13),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                    child: const Text('Haan, Clear Karo'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('offline_customers_json');
                              await prefs.remove('offline_payments_json');
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✓ Local cache cleared! Data Firebase se wapas sync hoga.'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                          label: const Text('Clear Cache'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Software & Agency Development Info', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 52,
                              height: 52,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 36),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Text('WisdomPharma', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  SizedBox(width: 8),
                                  Chip(
                                    label: Text('v1.0.0 Stable', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                    backgroundColor: Color(0xFF059669),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('Developed & Marketed by Wisdom Core Solutions', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 24,
                                runSpacing: 8,
                                children: const [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone_rounded, color: Color(0xFF34D399), size: 16),
                                      SizedBox(width: 6),
                                      Text('Support: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      Text('9050524678', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.language_rounded, color: Color(0xFF38BDF8), size: 16),
                                      SizedBox(width: 6),
                                      Text('Website: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      Text('wisdomcoresolution.store', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.email_rounded, color: Color(0xFFFBBF24), size: 16),
                                      SizedBox(width: 6),
                                      Text('Email: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      Text('wisdomcoresolutions@gmail.com', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
          ),
        ],
      ),
    );
  }
}
