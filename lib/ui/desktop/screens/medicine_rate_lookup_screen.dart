import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/purchase_bill_model.dart';
import '../../../providers/dashboard_provider.dart';
import '../../common/widgets/custom_card.dart';

/// Read-only counter screen for checking the selling price of stocked medicines.
class MedicineRateLookupScreen extends StatefulWidget {
  const MedicineRateLookupScreen({super.key});

  @override
  State<MedicineRateLookupScreen> createState() => _MedicineRateLookupScreenState();
}

class _MedicineRateLookupScreenState extends State<MedicineRateLookupScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _onlyAvailable = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryModel> _filteredItems(
    List<InventoryModel> inventory,
    List<PurchaseBillModel> purchaseBills,
    List<String> activeSupplierNames,
  ) {
    final query = _query.trim().toLowerCase();
    final activeSuppliers = activeSupplierNames
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    bool isVisibleSupplier(String supplierName) {
      final normalizedName = supplierName.trim().toLowerCase();
      return normalizedName.isEmpty || activeSuppliers.contains(normalizedName);
    }
    
    // Keep each supplier's batch/rate as a separate lookup result.
    final Map<String, InventoryModel> combinedItems = {};

    // 1. Add all items from current inventory
    for (var item in inventory) {
      if (!isVisibleSupplier(item.supplierName)) continue;
      final key = '${item.medicineName.toLowerCase()}_${item.batchNumber.toLowerCase()}_${item.supplierName.trim().toLowerCase()}';
      combinedItems[key] = item;
    }

    // 2. Add items from purchase bills if they are not already in inventory (to show historical rates)
    for (var bill in purchaseBills) {
      if (!isVisibleSupplier(bill.supplierName)) continue;
      for (var itemMap in bill.items) {
        final medName = (itemMap['medicineName'] ?? itemMap['name'] ?? '').toString();
        final batch = (itemMap['batchNumber'] ?? itemMap['batch'] ?? 'N/A').toString();
        final supplier = bill.supplierName.trim();
        final key = '${medName.toLowerCase()}_${batch.toLowerCase()}_${supplier.toLowerCase()}';

        if (!combinedItems.containsKey(key)) {
          combinedItems[key] = InventoryModel(
            medicineName: medName,
            batchNumber: batch,
            expiryDate: (itemMap['expiryDate'] ?? itemMap['expiry'] ?? 'N/A').toString(),
            quantity: 0, // Not in current stock inventory
            mrp: (itemMap['mrp'] as num?)?.toDouble() ?? 0.0,
            salePrice: (itemMap['salePrice'] as num?)?.toDouble() ?? 0.0,
            purchasePrice: (itemMap['purchasePrice'] as num?)?.toDouble() ?? 0.0,
            supplierName: bill.supplierName,
          );
        }
      }
    }

    final results = combinedItems.values.where((item) {
      final matchesQuery = query.isEmpty ||
          item.medicineName.toLowerCase().contains(query) ||
          item.batchNumber.toLowerCase().contains(query);
      return matchesQuery && (!_onlyAvailable || item.quantity > 0);
    }).toList();

    results.sort((a, b) => a.medicineName.toLowerCase().compareTo(b.medicineName.toLowerCase()));
    return results;
  }

  bool _isExpired(String expiry) {
    final parts = expiry.split('-');
    if (parts.length < 2) return false;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return false;
    return DateTime(year, month + 1, 0).isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final results = _filteredItems(
      provider.inventory,
      provider.purchaseBills,
      provider.suppliers.map((supplier) => supplier.name).toList(),
    );
    final totalStock = results.fold<int>(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Medicine Rate Lookup', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 5),
              const Text('Sirf medicine ka naam type karein — billing mein add kiye bina sale rate dekhein.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              CustomCard(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          labelText: 'Medicine name ya batch number',
                          hintText: 'Example: Dolo 650',
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilterChip(
                      label: const Text('Only available stock'),
                      selected: _onlyAvailable,
                      selectedColor: AppColors.primaryLight.withValues(alpha: 0.3),
                      onSelected: (value) => setState(() => _onlyAvailable = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('${results.length} batch${results.length == 1 ? '' : 'es'} found', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(width: 14),
                  Text('Total available units: $totalStock', style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: results.isEmpty
                    ? _EmptyState(hasQuery: _query.trim().isNotEmpty)
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => _RateCard(item: results[index], expired: _isExpired(results[index].expiryDate)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  final InventoryModel item;
  final bool expired;

  const _RateCard({required this.item, required this.expired});

  @override
  Widget build(BuildContext context) {
    final lowStock = item.quantity > 0 && item.quantity <= 10;
    final stockColor = expired || item.quantity == 0
        ? AppColors.error
        : lowStock
            ? AppColors.warning
            : AppColors.success;

    return CustomCard(
      borderColor: expired ? AppColors.error.withValues(alpha: 0.45) : null,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.medication_outlined, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.medicineName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Batch: ${item.batchNumber}  •  Expiry: ${item.expiryDate}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                if (item.supplierName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text('Supplier: ${item.supplierName}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
                const SizedBox(height: 3),
                Text(
                  'Purchase Rate: ₹${item.purchasePrice.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          _PriceDetail(label: 'MRP', value: item.mrp),
          const SizedBox(width: 22),
          _PriceDetail(label: 'Sale Rate', value: item.salePrice, highlight: true),
          const SizedBox(width: 22),
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${item.quantity} units', style: TextStyle(fontWeight: FontWeight.bold, color: stockColor)),
                const SizedBox(height: 4),
                Text(expired ? 'EXPIRED' : lowStock ? 'LOW STOCK' : 'IN STOCK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stockColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceDetail extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _PriceDetail({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        Text('₹${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: highlight ? AppColors.primaryDark : AppColors.textPrimary)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;

  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(hasQuery ? 'Is naam ka available stock nahi mila.' : 'Medicine ka naam search karke rate dekhein.', style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
