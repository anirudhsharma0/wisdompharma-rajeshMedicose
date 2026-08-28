import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/services/bill_ocr_service.dart';
import '../../../providers/dashboard_provider.dart';
import '../../desktop/screens/parties_screen.dart';
import '../widgets/loading_overlay.dart';

class PendingBillsScreen extends StatefulWidget {
  const PendingBillsScreen({super.key});

  @override
  State<PendingBillsScreen> createState() => _PendingBillsScreenState();
}

class _PendingBillsScreenState extends State<PendingBillsScreen> {
  List<ScannedBillModel> _pendingBills = [];
  bool _isLoading = true;
  final Map<String, String> _selectedSupplierIds = {};
  StreamSubscription<List<ScannedBillModel>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadPendingBills();
    _subscription = BillOcrService.instance.streamPendingBills().listen((list) {
      if (mounted) {
        setState(() {
          _pendingBills = list;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingBills() async {
    setState(() => _isLoading = true);
    final list = await BillOcrService.instance.getPendingBills();
    setState(() {
      _pendingBills = list;
      _isLoading = false;
    });
  }

  Future<void> _deletePendingBill(String id) async {
    await AppLoadingOverlay.runWithLoading(
      context,
      message: 'Removing Pending Bill...',
      task: () async {
        await BillOcrService.instance.removePendingBill(id);
        _loadPendingBills();
      },
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pending bill removed.')),
      );
    }
  }

  void _showSupplierSearchDialog(
    BuildContext context,
    List<SupplierModel> suppliers,
    String billId,
    SupplierModel? currentSelected,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = suppliers.where((s) {
              if (searchQuery.trim().isEmpty) return true;
              final q = searchQuery.trim().toLowerCase();
              final nameMatch = s.name.toLowerCase().contains(q);
              final contactMatch = s.contact.toLowerCase().contains(q);
              final addressMatch = (s.address ?? '').toLowerCase().contains(q);
              final gstinMatch = (s.gstin ?? '').toLowerCase().contains(q);
              return nameMatch || contactMatch || addressMatch || gstinMatch;
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Row(
                children: const [
                  Icon(Icons.business_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Select Agency / Supplier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '🔍 Search agency by Name, Phone, City, GSTIN...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setDialogState(() {
                                    searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                searchQuery.isEmpty ? 'No suppliers available.' : 'No agency matching "$searchQuery"',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, idx) {
                                final s = filtered[idx];
                                final isSelected = s.id == currentSelected?.id;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  tileColor: isSelected ? Colors.blue.shade50 : null,
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected ? AppColors.primary : Colors.blue.shade100,
                                    child: Text(
                                      s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.blue.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    s.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected ? AppColors.primary : AppColors.slate800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '📱 ${s.contact.isNotEmpty ? s.contact : "No Phone"}${s.address != null && s.address!.isNotEmpty ? " • ${s.address}" : ""}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                                      : const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                                  onTap: () {
                                    if (s.id != null) {
                                      setState(() {
                                        _selectedSupplierIds[billId] = s.id!;
                                      });
                                    }
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openPurchaseBillDialog(ScannedBillModel bill, SupplierModel selectedSupplier, DashboardProvider provider) {
    // Convert SupplierModel to PartyItem expected by PartiesScreen
    final party = PartyItem(
      id: selectedSupplier.id ?? 'sup_${selectedSupplier.name}',
      name: selectedSupplier.name,
      phone: selectedSupplier.contact,
      amount: selectedSupplier.due,
      gstin: selectedSupplier.gstin,
      address: selectedSupplier.address,
      partyType: 'Supplier',
    );

    PartiesScreen.showAddPurchaseBillDialogWithPreFill(
      context: context,
      party: party,
      provider: provider,
      initialScannedBill: bill,
      onBillSaved: () async {
        await BillOcrService.instance.removePendingBill(bill.id);
        _loadPendingBills();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final suppliers = provider.suppliers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Admin Pending Scanned Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Queue',
            onPressed: _loadPendingBills,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingBills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 70, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No Pending Scanned Bills',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Scan a bill from AI Scanner to add it to the approval queue.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingBills.length,
                  itemBuilder: (context, index) {
                    final bill = _pendingBills[index];
                    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(bill.scannedAt);

                    // Find auto-matched supplier or default to first supplier
                    SupplierModel? currentSelectedSupplier;
                    final selectedId = _selectedSupplierIds[bill.id];
                    if (selectedId != null) {
                      currentSelectedSupplier = suppliers.firstWhere(
                        (s) => s.id == selectedId,
                        orElse: () => suppliers.isNotEmpty ? suppliers.first : SupplierModel(id: 'temp', name: bill.supplierName, contact: '', due: 0.0),
                      );
                    } else if (suppliers.isNotEmpty) {
                      currentSelectedSupplier = suppliers.firstWhere(
                        (s) => s.name.toLowerCase().contains(bill.supplierName.toLowerCase()) || bill.supplierName.toLowerCase().contains(s.name.toLowerCase()),
                        orElse: () => suppliers.first,
                      );
                    }

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          border: Border.all(color: Colors.orange.shade300),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.orange),
                                            SizedBox(width: 4),
                                            Text('Pending Admin Approval', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Invoice #${bill.invoiceNumber.isNotEmpty ? bill.invoiceNumber : "N/A"}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Reject & Delete Request',
                                  onPressed: () => _deletePendingBill(bill.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Scanned on $dateStr • ${bill.items.length} items parsed', style: const TextStyle(fontSize: 12, color: Colors.grey)),

                            const Divider(height: 20),

                            // Supplier Select Section
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Select Agency / Supplier:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  const SizedBox(height: 6),
                                  suppliers.isEmpty
                                      ? const Text('No suppliers found in database. Add a supplier in Parties screen first.', style: TextStyle(color: Colors.red, fontSize: 12))
                                      : InkWell(
                                          onTap: () => _showSupplierSearchDialog(context, suppliers, bill.id, currentSelectedSupplier),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.blue.shade300),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.business_rounded, color: AppColors.primary, size: 20),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        currentSelectedSupplier != null
                                                            ? '${currentSelectedSupplier.name} (${currentSelectedSupplier.contact.isNotEmpty ? currentSelectedSupplier.contact : "No Contact"})'
                                                            : 'Click to select / search agency...',
                                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate800),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (currentSelectedSupplier?.address != null && currentSelectedSupplier!.address!.isNotEmpty)
                                                        Text(
                                                          currentSelectedSupplier.address!,
                                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: Colors.blue.shade200),
                                                  ),
                                                  child: Row(
                                                    children: const [
                                                      Icon(Icons.search, size: 14, color: AppColors.primary),
                                                      SizedBox(width: 4),
                                                      Text('Search Agency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Items Table Preview
                            const Text('Items Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 14,
                                  headingRowHeight: 36,
                                  dataRowMinHeight: 36,
                                  dataRowMaxHeight: 40,
                                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                                  columns: const [
                                    DataColumn(label: Text('Sn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Product Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Qty + Free', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Batch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Exp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('MRP (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Rate (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Sch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Dis %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('GST %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Amount (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                  ],
                                  rows: bill.items.asMap().entries.map((e) {
                                    final item = e.value;
                                    return DataRow(cells: [
                                      DataCell(Text('${e.key + 1}', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(item.productName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                      DataCell(Text('${item.quantity}${item.freeQty > 0 ? " + ${item.freeQty}" : ""}', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(item.batchNumber, style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(item.expiryDate, style: const TextStyle(fontSize: 11))),
                                      DataCell(Text('₹${item.mrp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text('₹${item.purchaseRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(item.schemeDiscount > 0 ? item.schemeDiscount.toStringAsFixed(1) : '0.0', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text('${item.discountPercent}%', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text('${item.gstPercent}%', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text('₹${item.netAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue))),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Bottom Approve & Fill Purchase Bill Button
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                Text(
                                  'Grand Total: ₹${bill.grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.bolt, color: Colors.white, size: 18),
                                  label: const Text('⚡ Approve & Open Purchase Bill'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: currentSelectedSupplier == null
                                      ? null
                                      : () => _openPurchaseBillDialog(bill, currentSelectedSupplier!, provider),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
