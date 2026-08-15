import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/services/pdf_service.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/medicine_master_model.dart';
import '../../../data/services/sqlite_service.dart';
import '../../common/widgets/custom_card.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  int? _selectedMedicineId;
  String? _selectedMedicineComposition;
  String? _selectedMedicineCategory;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _receiptNoController = TextEditingController();
  String _paymentMode = 'Cash';

  @override
  void dispose() {
    _nameController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    _qtyController.dispose();
    _mrpController.dispose();
    _salePriceController.dispose();
    _purchasePriceController.dispose();
    _searchController.dispose();
    _supplierController.dispose();
    _paidAmountController.dispose();
    _receiptNoController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _batchController.clear();
    _expiryController.clear();
    _qtyController.clear();
    _mrpController.clear();
    _salePriceController.clear();
    _purchasePriceController.clear();
    _supplierController.clear();
    _paidAmountController.clear();
    _receiptNoController.clear();
    setState(() {
      _selectedMedicineId = null;
      _selectedMedicineComposition = null;
      _selectedMedicineCategory = null;
      _paymentMode = 'Cash';
    });
  }

  void _saveStockItem(DashboardProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final batch = _batchController.text.trim();
    final expiry = _expiryController.text.trim();
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final mrp = double.tryParse(_mrpController.text) ?? 0.0;
    final sale = double.tryParse(_salePriceController.text) ?? 0.0;
    final purchase = double.tryParse(_purchasePriceController.text) ?? 0.0;
    final supplier = _supplierController.text.trim();

    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
    final receiptNo = _receiptNoController.text.trim();

    final newItem = InventoryModel(
      medicineName: name,
      batchNumber: batch,
      expiryDate: expiry,
      quantity: qty,
      mrp: mrp,
      salePrice: sale,
      purchasePrice: purchase,
      supplierName: supplier,
    );

    await provider.addInventory(newItem);

    // If Supplier is specified, record the financial transaction & payment slip
    if (supplier.isNotEmpty) {
      final totalBill = qty * purchase;
      var supIdx = provider.suppliers.indexWhere((s) => s.name.trim().toLowerCase() == supplier.toLowerCase());
      if (supIdx == -1) {
        await provider.addSupplier(SupplierModel(name: supplier, contact: ''));
      }

      final remainingDue = totalBill - paidAmount;
      if (remainingDue > 0) {
        await provider.addSupplierDue(supplier, remainingDue);
      }

      if (paidAmount > 0) {
        final voucher = await provider.paySupplier(
          supplier,
          paidAmount,
          paymentMode: _paymentMode,
          referenceNumber: receiptNo,
          remarks: 'Stock Purchase: $name (Batch $batch, Qty $qty)',
        );

        if (voucher != null && mounted) {
          final supModel = provider.suppliers.firstWhere(
            (s) => s.name.trim().toLowerCase() == supplier.toLowerCase(),
            orElse: () => SupplierModel(name: supplier, contact: '', due: remainingDue),
          );

          final pdfBytes = await PdfService.generatePaymentReceiptPdf(
            voucherNumber: voucher.voucherNumber,
            partyName: supplier,
            partyPhone: supModel.contact,
            amountPaid: paidAmount,
            paymentMode: _paymentMode,
            referenceNumber: receiptNo,
            remarks: 'Stock Entry: $name (Batch $batch)',
            createdAt: DateTime.now(),
            remainingBalance: (supModel.due - paidAmount).clamp(0.0, 9999999.0),
            agencyName: supplier,
          );

          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: 'Payment_Receipt_${supplier}_${voucher.voucherNumber}',
          );
        }
      }
    }

    _clearForm();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stock for $name (Batch $batch) updated successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);

    // Apply search filter
    final filteredInventory = dashProvider.inventory.where((item) {
      final query = _searchController.text.toLowerCase().trim();
      return query.isEmpty ||
          item.medicineName.toLowerCase().contains(query) ||
          item.batchNumber.toLowerCase().contains(query) ||
          item.supplierName.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Inventory Table (Flex 7)
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search bar and Quick Alerts summary
                CustomCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search Stock Inventory by name, batch, or supplier...',
                            prefixIcon: Icon(Icons.search, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Low Stock Badge
                            _buildAlertBadge(
                              'Low Stock',
                              '${dashProvider.lowStockMedicines.length}',
                              dashProvider.lowStockMedicines.isNotEmpty ? AppColors.error : AppColors.success,
                            ),
                            const SizedBox(width: 12),
                            // Expiring Soon Badge
                            _buildAlertBadge(
                              'Near Expiry',
                              '${dashProvider.nearExpiryMedicines.length}',
                              dashProvider.nearExpiryMedicines.isNotEmpty ? Colors.orange : AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Inventory DataTable Card
                Expanded(
                  child: CustomCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Active Medicine Inventory Database',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                          ),
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        Expanded(
                          child: filteredInventory.isEmpty
                              ? const Center(
                                  child: Text('No stock items match your search filter.', style: TextStyle(color: AppColors.textMuted)),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(AppColors.border.withValues(alpha: 0.3)),
                                      columns: const [
                                        DataColumn(label: Text('Medicine Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Batch', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Supplier / Agency', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Expiry', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Cost Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Sale Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('MRP', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: filteredInventory.map((item) {
                                        final isLowStock = item.quantity < 15;
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                item.medicineName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: isLowStock ? AppColors.warning : AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(item.batchNumber)),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.supplierName.isNotEmpty ? item.supplierName : 'Direct Stock',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: item.supplierName.isNotEmpty ? Colors.blue.shade800 : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(item.expiryDate)),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isLowStock
                                                      ? AppColors.error.withValues(alpha: 0.15)
                                                      : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.quantity.toString(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isLowStock ? AppColors.error : AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text('₹${item.purchasePrice.toStringAsFixed(2)}')),
                                            DataCell(Text('₹${item.salePrice.toStringAsFixed(2)}')),
                                            DataCell(Text('₹${item.mrp.toStringAsFixed(2)}')),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: AppColors.primaryLight, size: 16),
                                                    onPressed: () {
                                                      // Load item to edit form
                                                      setState(() {
                                                        _nameController.text = item.medicineName;
                                                        _batchController.text = item.batchNumber;
                                                        _expiryController.text = item.expiryDate;
                                                        _qtyController.text = item.quantity.toString();
                                                        _mrpController.text = item.mrp.toString();
                                                        _salePriceController.text = item.salePrice.toString();
                                                        _purchasePriceController.text = item.purchasePrice.toString();
                                                        _supplierController.text = item.supplierName;
                                                      });
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: AppColors.error, size: 16),
                                                    onPressed: () => dashProvider.deleteStock(item.id!),
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
          const SizedBox(width: 20),

          // Right Side: Add/Edit Stock Form (Flex 4)
          Expanded(
            flex: 4,
            child: CustomCard(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Record New Purchase/Stock',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 16),
                      Autocomplete<MedicineMasterModel>(
                        optionsBuilder: (TextEditingValue textEditingValue) async {
                          if (textEditingValue.text.length < 2) {
                            return const Iterable<MedicineMasterModel>.empty();
                          }
                          return await SqliteService.instance.searchMedicines(textEditingValue.text);
                        },
                        displayStringForOption: (MedicineMasterModel option) => option.medicineName,
                        onSelected: (MedicineMasterModel selection) {
                          setState(() {
                            _nameController.text = selection.medicineName;
                            _selectedMedicineId = selection.id;
                            _selectedMedicineComposition = selection.composition;
                            _selectedMedicineCategory = selection.manufacturer;
                            
                            // Smart pre-fill defaults
                            _mrpController.text = selection.mrp.toStringAsFixed(2);
                            _salePriceController.text = (selection.mrp * 0.9).toStringAsFixed(2);
                            _purchasePriceController.text = (selection.mrp * 0.75).toStringAsFixed(2);
                          });
                        },
                        fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                          if (textEditingController.text != _nameController.text) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              textEditingController.text = _nameController.text;
                            });
                          }
                          textEditingController.addListener(() {
                            if (_nameController.text != textEditingController.text) {
                              _nameController.text = textEditingController.text;
                            }
                          });
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Medicine Brand Name',
                              prefixIcon: Icon(Icons.medication),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            onFieldSubmitted: (val) => onFieldSubmitted(),
                          );
                        },
                        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<MedicineMasterModel> onSelected, Iterable<MedicineMasterModel> options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 340,
                                constraints: const BoxConstraints(maxHeight: 280),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                                  itemBuilder: (BuildContext context, int index) {
                                    final MedicineMasterModel option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(
                                        option.medicineName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      subtitle: Text(
                                        'Salt: ${option.composition ?? "No composition"} | Cat: ${option.manufacturer ?? "Generic"}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_selectedMedicineId != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedMedicineComposition != null && _selectedMedicineComposition!.isNotEmpty)
                                Text(
                                  'Composition: $_selectedMedicineComposition',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              if (_selectedMedicineCategory != null && _selectedMedicineCategory!.isNotEmpty)
                                Text(
                                  'Category: $_selectedMedicineCategory',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _batchController,
                              decoration: const InputDecoration(labelText: 'Batch No.'),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _expiryController,
                              decoration: const InputDecoration(labelText: 'Expiry Date', hintText: 'YYYY-MM'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Required';
                                final regExp = RegExp(r'^\d{4}-\d{2}$');
                                if (!regExp.hasMatch(val)) return 'Use YYYY-MM';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final q = textEditingValue.text.toLowerCase().trim();
                          final suppliersList = dashProvider.suppliers.map((s) => s.name).toList();
                          if (q.isEmpty) return suppliersList;
                          return suppliersList.where((s) => s.toLowerCase().contains(q));
                        },
                        onSelected: (String selection) {
                          _supplierController.text = selection;
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          if (_supplierController.text.isNotEmpty && textEditingController.text.isEmpty) {
                            textEditingController.text = _supplierController.text;
                          }
                          textEditingController.addListener(() {
                            _supplierController.text = textEditingController.text;
                          });
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Supplier / Wholesale Agency (Optional)',
                              hintText: 'e.g. Hans Medical Agencies',
                              prefixIcon: Icon(Icons.business),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'In-Stock Quantity',
                          prefixIcon: Icon(Icons.production_quantity_limits),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final qty = int.tryParse(val);
                          if (qty == null || qty <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _purchasePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Distributor Purchase Rate (₹)',
                          prefixIcon: Icon(Icons.shopping_bag_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final price = double.tryParse(val);
                          if (price == null || price <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _salePriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Selling Price (₹)'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Required';
                                final price = double.tryParse(val);
                                if (price == null || price <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _mrpController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Max Retail MRP (₹)'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Required';
                                final price = double.tryParse(val);
                                if (price == null || price <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Wholesale Payment Settle & Receipt (Optional)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 320;
                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      TextFormField(
                                        controller: _paidAmountController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText: 'Amount Paid Now (₹)',
                                          hintText: 'e.g. 5000',
                                          prefixIcon: const Icon(Icons.payment, size: 18),
                                          fillColor: Colors.white,
                                          filled: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _receiptNoController,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText: 'Receipt Slip No.',
                                          hintText: 'e.g. 27822',
                                          prefixIcon: const Icon(Icons.receipt, size: 18),
                                          fillColor: Colors.white,
                                          filled: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _paidAmountController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText: 'Amount Paid Now (₹)',
                                          hintText: 'e.g. 5000',
                                          prefixIcon: const Icon(Icons.payment, size: 18),
                                          fillColor: Colors.white,
                                          filled: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _receiptNoController,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText: 'Receipt Slip No.',
                                          hintText: 'e.g. 27822',
                                          prefixIcon: const Icon(Icons.receipt, size: 18),
                                          fillColor: Colors.white,
                                          filled: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _paymentMode,
                              decoration: InputDecoration(
                                labelText: 'Payment Mode',
                                prefixIcon: const Icon(Icons.account_balance_wallet, size: 18),
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
                                if (val != null) setState(() => _paymentMode = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _clearForm,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Reset', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () => _saveStockItem(dashProvider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Save Stock'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
