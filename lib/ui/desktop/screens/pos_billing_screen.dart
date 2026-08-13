import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/medicine_master_model.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/bill_model.dart';
import '../../../data/models/customer_model.dart';
import '../../common/widgets/custom_card.dart';
import '../../common/widgets/receipt_preview.dart';
import '../../../data/services/pdf_service.dart';


class PosBillingScreen extends StatefulWidget {
  const PosBillingScreen({super.key});

  static void openQuickSaleDialog(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);
    final posProvider = Provider.of<PosProvider>(context, listen: false);

    final TextEditingController custNameCtrl = TextEditingController();
    final TextEditingController custPhoneCtrl = TextEditingController();
    final TextEditingController directAmtCtrl = TextEditingController();
    final TextEditingController remarkCtrl = TextEditingController();
    final TextEditingController discountCtrl = TextEditingController(text: '0');

    String selectedPaymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final amt = double.tryParse(directAmtCtrl.text) ?? 0.0;
            final disc = double.tryParse(discountCtrl.text) ?? 0.0;
            final netAmt = (amt - disc).clamp(0.0, 9999999.0);

            Future<void> processQuickSaleCheckout({bool shouldPrint = false}) async {
              if (amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid Sale Amount (₹)')),
                );
                return;
              }

              final name = custNameCtrl.text.trim();
              final phone = custPhoneCtrl.text.trim();
              final remark = remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'General Medical Sale';

              posProvider.resetCart();
              posProvider.setCustomerName(name.isEmpty ? 'Walk-in Customer' : name);
              posProvider.setCustomerPhone(phone);
              posProvider.setDiscount(disc);
              posProvider.setPaymentMode(selectedPaymentMode);

              posProvider.addItemToCart(
                name: remark,
                batch: 'MANUAL',
                expiry: 'N/A',
                quantity: 1,
                mrp: amt,
                salePrice: amt,
                category: 'Manual Quick Sale',
              );

              final result = await posProvider.checkout();

              if (result['success'] == true) {
                final BillModel completedBill = result['bill'];
                if (result['isOffline'] == true) {
                  dashProvider.addLocalBill(completedBill);
                }

                if (shouldPrint) {
                  try {
                    await PdfService.printReceipt(
                      completedBill,
                      pharmacyName: dashProvider.pharmacyName,
                      storeAddress: dashProvider.storeAddress,
                    );
                  } catch (e) {
                    debugPrint('Print error: $e');
                  }
                }

                Navigator.pop(dialogCtx);

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.background,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          shouldPrint ? 'Bill Saved & Sent to Printer' : 'Bill Saved Successfully',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    content: SizedBox(
                      width: 400,
                      child: ReceiptPreview(bill: completedBill),
                    ),
                    actions: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Print Receipt'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () {
                          PdfService.printReceipt(
                            completedBill,
                            pharmacyName: dashProvider.pharmacyName,
                            storeAddress: dashProvider.storeAddress,
                          );
                        },
                      ),
                      TextButton(
                        child: const Text('Done'),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Checkout failed: ${result['message']}')),
                );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 540,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bolt, color: Colors.amber, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  '⚡ Quick Manual Sale / Direct Bill',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  'Fast sale entry without searching inventory',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textMuted),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Customer Info (Name & Phone)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: custNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name',
                                hintText: 'Walk-in Customer',
                                prefixIcon: Icon(Icons.person, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: custPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Customer Phone',
                                hintText: '98765xxxxx',
                                prefixIcon: Icon(Icons.phone, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Direct Sale Amount & Remark Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: directAmtCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                                    autofocus: true,
                                    onChanged: (val) => setDialogState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Direct Sale Amount (₹)*',
                                      hintText: 'e.g. 500',
                                      prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: remarkCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Sale Description / Items',
                                      hintText: 'General Medical Sale',
                                      prefixIcon: Icon(Icons.edit_note),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Discount & Payment Mode
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: discountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (val) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Discount Deduction (₹)',
                                prefixIcon: Icon(Icons.local_offer, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedPaymentMode,
                              decoration: const InputDecoration(
                                labelText: 'Payment Mode',
                                prefixIcon: Icon(Icons.payment, size: 18),
                                isDense: true,
                              ),
                              items: ['Cash', 'UPI', 'Card', 'Credit']
                                  .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m == 'Credit' ? 'Udhar (Credit)' : m, style: const TextStyle(fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedPaymentMode = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Net Payable Tally Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gross: ₹${amt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                Text('Discount: ₹${disc.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('NET PAYABLE AMOUNT', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                Text(
                                  '₹${netAmt.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons: Cancel | Save / Submit Bill | Save & Print
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Clear / Cancel'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => processQuickSaleCheckout(shouldPrint: false),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Save / Submit Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => processQuickSaleCheckout(shouldPrint: true),
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Save & Print', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  State<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends State<PosBillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _mrpController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final TextEditingController _custNameController = TextEditingController();
  final TextEditingController _custPhoneController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _directAmountController = TextEditingController();
  final TextEditingController _directRemarkController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _custNameFocusNode = FocusNode();
  final FocusNode _mrpFocusNode = FocusNode();

  MedicineMasterModel? _selectedMasterMedicine;
  InventoryModel? _matchedInventoryItem;

  List<CustomerModel> _filteredCustomers = [];
  bool _showCustomerSuggestions = false;

  @override
  void initState() {
    super.initState();
    _qtyController.addListener(_recalculatePriceAndMrp);

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {});
          }
        });
      } else {
        setState(() {});
      }
    });

    _custNameFocusNode.addListener(() {
      if (!_custNameFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _showCustomerSuggestions = false;
            });
          }
        });
      } else {
        _filterCustomerSuggestions(_custNameController.text);
      }
    });

    _custNameController.addListener(() {
      if (_custNameFocusNode.hasFocus) {
        _filterCustomerSuggestions(_custNameController.text);
      }
    });
  }

  void _filterCustomerSuggestions(String val) {
    final query = val.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = [];
        _showCustomerSuggestions = false;
      });
    } else {
      final customers = Provider.of<DashboardProvider>(context, listen: false).customers;
      final matches = customers.where((c) =>
        c.name.toLowerCase().contains(query) ||
        c.phone.contains(query)
      ).toList();
      setState(() {
        _filteredCustomers = matches;
        _showCustomerSuggestions = matches.isNotEmpty;
      });
    }
  }

  void _selectCustomer(CustomerModel customer) {
    setState(() {
      _custNameController.text = customer.name;
      _custPhoneController.text = customer.phone;
      _showCustomerSuggestions = false;
      _filteredCustomers = [];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _medicineNameController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    _qtyController.dispose();
    _mrpController.dispose();
    _priceController.dispose();
    _custNameController.dispose();
    _custPhoneController.dispose();
    _discountController.dispose();
    _directAmountController.dispose();
    _directRemarkController.dispose();
    _searchFocusNode.dispose();
    _qtyFocusNode.dispose();
    _custNameFocusNode.dispose();
    _mrpFocusNode.dispose();
    super.dispose();
  }

  void _addDirectAmountToCart(PosProvider posProvider) {
    final amt = double.tryParse(_directAmountController.text) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid sale amount (₹)')),
      );
      return;
    }
    final remark = _directRemarkController.text.trim().isNotEmpty
        ? _directRemarkController.text.trim()
        : 'General Medical Sale';

    posProvider.addItemToCart(
      name: remark,
      batch: 'MANUAL',
      expiry: 'N/A',
      quantity: 1,
      mrp: amt,
      salePrice: amt,
      category: 'Manual Sale',
    );

    _directAmountController.clear();
    _directRemarkController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ₹$amt ($remark) to cart.')),
    );
  }

  void _recalculatePriceAndMrp() {
    // Basic reactive behavior if needed
  }

  void _selectMedicine(MedicineMasterModel medicine, List<InventoryModel> inventory) {
    setState(() {
      _selectedMasterMedicine = medicine;
      _medicineNameController.text = medicine.medicineName;
      _searchController.text = medicine.medicineName;
      _mrpController.text = medicine.mrp.toStringAsFixed(2);
      _priceController.text = (medicine.mrp * 0.9).toStringAsFixed(2); // 10% default discount rate
      _batchController.text = 'BATCH-${DateTime.now().year % 100}${DateTime.now().month}';
      _expiryController.text = '${DateTime.now().year + 2}-${DateTime.now().month.toString().padLeft(2, '0')}';

      // Check if this medicine is already in Firestore inventory
      final matched = inventory.where(
        (item) => item.medicineName.toLowerCase() == medicine.medicineName.toLowerCase()
      );
      if (matched.isNotEmpty) {
        _matchedInventoryItem = matched.first;
        // Autofill details from stock
        _batchController.text = _matchedInventoryItem!.batchNumber;
        _expiryController.text = _matchedInventoryItem!.expiryDate;
        _mrpController.text = _matchedInventoryItem!.mrp.toStringAsFixed(2);
        _priceController.text = _matchedInventoryItem!.salePrice.toStringAsFixed(2);
      } else {
        _matchedInventoryItem = null;
      }
    });
    // Request focus on quantity
    _qtyFocusNode.requestFocus();
  }

  void _showQuickSaleModalDialog(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);
    final posProvider = Provider.of<PosProvider>(context, listen: false);

    final TextEditingController custNameCtrl = TextEditingController();
    final TextEditingController custPhoneCtrl = TextEditingController();
    final TextEditingController directAmtCtrl = TextEditingController();
    final TextEditingController remarkCtrl = TextEditingController();
    final TextEditingController discountCtrl = TextEditingController(text: '0');

    String selectedPaymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final amt = double.tryParse(directAmtCtrl.text) ?? 0.0;
            final disc = double.tryParse(discountCtrl.text) ?? 0.0;
            final netAmt = (amt - disc).clamp(0.0, 9999999.0);

            Future<void> processQuickSaleCheckout({bool shouldPrint = false}) async {
              if (amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid Sale Amount (₹)')),
                );
                return;
              }

              final name = custNameCtrl.text.trim();
              final phone = custPhoneCtrl.text.trim();
              final remark = remarkCtrl.text.trim().isNotEmpty ? remarkCtrl.text.trim() : 'General Medical Sale';

              posProvider.resetCart();
              posProvider.setCustomerName(name.isEmpty ? 'Walk-in Customer' : name);
              posProvider.setCustomerPhone(phone);
              posProvider.setDiscount(disc);
              posProvider.setPaymentMode(selectedPaymentMode);

              posProvider.addItemToCart(
                name: remark,
                batch: 'MANUAL',
                expiry: 'N/A',
                quantity: 1,
                mrp: amt,
                salePrice: amt,
                category: 'Manual Quick Sale',
              );

              Navigator.pop(dialogCtx);
              _triggerCheckout(posProvider, dashProvider, shouldPrint: shouldPrint);
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 540,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bolt, color: Colors.amber, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  '⚡ Quick Manual Sale / Direct Bill',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  'Fast sale entry without searching inventory',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textMuted),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Customer Info (Name & Phone)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: custNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name',
                                hintText: 'Walk-in Customer',
                                prefixIcon: Icon(Icons.person, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: custPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Customer Phone',
                                hintText: '98765xxxxx',
                                prefixIcon: Icon(Icons.phone, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Direct Sale Amount & Remark Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: directAmtCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                                    autofocus: true,
                                    onChanged: (val) => setDialogState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Direct Sale Amount (₹)*',
                                      hintText: 'e.g. 500',
                                      prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: remarkCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Sale Description / Items',
                                      hintText: 'General Medical Sale',
                                      prefixIcon: Icon(Icons.edit_note),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Discount & Payment Mode
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: discountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (val) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Discount Deduction (₹)',
                                prefixIcon: Icon(Icons.local_offer, size: 18),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedPaymentMode,
                              decoration: const InputDecoration(
                                labelText: 'Payment Mode',
                                prefixIcon: Icon(Icons.payment, size: 18),
                                isDense: true,
                              ),
                              items: ['Cash', 'UPI', 'Card', 'Credit']
                                  .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m == 'Credit' ? 'Udhar (Credit)' : m, style: const TextStyle(fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedPaymentMode = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Net Payable Tally Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gross: ₹${amt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                Text('Discount: ₹${disc.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('NET PAYABLE AMOUNT', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                Text(
                                  '₹${netAmt.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons: Cancel | Save / Submit Bill | Save & Print
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Clear / Cancel'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => processQuickSaleCheckout(shouldPrint: false),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Save / Submit Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => processQuickSaleCheckout(shouldPrint: true),
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Save & Print', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddManualItemDialog(BuildContext context, PosProvider posProvider) {
    final TextEditingController nameCtrl = TextEditingController(text: 'Manual Item');
    final TextEditingController priceCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text('Add Manual Item / Amount', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name / Description',
                  hintText: 'e.g. Generic Medicine, Consultation, etc.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount / Price (₹)',
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: '1',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                final qty = int.tryParse(qtyCtrl.text) ?? 1;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an item name')),
                  );
                  return;
                }
                if (price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid price')),
                  );
                  return;
                }
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid quantity')),
                  );
                  return;
                }

                posProvider.addItemToCart(
                  name: name,
                  batch: 'MANUAL',
                  expiry: 'N/A',
                  quantity: qty,
                  mrp: price,
                  salePrice: price,
                  category: 'Manual Entry',
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added "$name" (₹$price) to cart')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Add to Cart'),
            ),
          ],
        );
      },
    );
  }

  void _addItemToCart(PosProvider posProvider) {
    final name = _medicineNameController.text.trim().isNotEmpty
        ? _medicineNameController.text.trim()
        : (_selectedMasterMedicine?.medicineName ?? _searchController.text.trim());

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a medicine name')),
      );
      return;
    }

    final batch = _batchController.text.trim().isEmpty ? 'GENERIC' : _batchController.text.trim();
    final expiry = _expiryController.text.trim().isEmpty ? '2028-12' : _expiryController.text.trim();
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final mrp = double.tryParse(_mrpController.text) ?? 0.0;
    final salePrice = double.tryParse(_priceController.text) ?? mrp;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity greater than 0')),
      );
      return;
    }
    if (mrp <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid MRP/Price')),
      );
      return;
    }

    posProvider.addItemToCart(
      name: name,
      batch: batch,
      expiry: expiry,
      quantity: qty,
      mrp: mrp,
      salePrice: salePrice,
      substitutes: _selectedMasterMedicine?.composition,
      category: _selectedMasterMedicine?.manufacturer,
    );

    // Reset input fields
    setState(() {
      _selectedMasterMedicine = null;
      _matchedInventoryItem = null;
      _medicineNameController.clear();
      _searchController.clear();
      _batchController.clear();
      _expiryController.clear();
      _qtyController.text = '1';
      _mrpController.clear();
      _priceController.clear();
    });

    _searchFocusNode.requestFocus();
  }

  void _triggerCheckout(PosProvider posProvider, DashboardProvider dashProvider, {bool shouldPrint = false}) async {
    // Sync customer fields
    posProvider.setCustomerName(_custNameController.text);
    posProvider.setCustomerPhone(_custPhoneController.text);
    posProvider.setDiscount(double.tryParse(_discountController.text) ?? 0.0);

    if (posProvider.cartItems.isEmpty) {
      final directAmt = double.tryParse(_directAmountController.text) ?? double.tryParse(_priceController.text) ?? 0.0;
      if (directAmt > 0) {
        final remark = _directRemarkController.text.trim().isNotEmpty
            ? _directRemarkController.text.trim()
            : 'General Medical Sale';
        posProvider.addItemToCart(
          name: remark,
          batch: 'MANUAL',
          expiry: 'N/A',
          quantity: 1,
          mrp: directAmt,
          salePrice: directAmt,
          category: 'Manual Sale',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Cart is Empty! Please add medicines or enter a Direct Sale Amount (₹).'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Checkout
    final result = await posProvider.checkout();

    if (result['success'] == true) {
      final BillModel completedBill = result['bill'];

      // If it was local fallback, update local dashboard list
      if (result['isOffline'] == true) {
        dashProvider.addLocalBill(completedBill);
      }

      // Clear local UI text inputs
      _custNameController.clear();
      _custPhoneController.clear();
      _discountController.text = '0';
      _directAmountController.clear();

      // Trigger PDF print dialog ONLY if explicitly requested by clicking "Save & Print"
      if (shouldPrint) {
        try {
          await PdfService.printReceipt(
            completedBill,
            pharmacyName: dashProvider.pharmacyName,
            storeAddress: dashProvider.storeAddress,
          );
        } catch (e) {
          debugPrint('Print error: $e');
        }
      }

      // Show Invoice dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shouldPrint ? 'Bill Saved & Sent to Printer' : 'Bill Saved Successfully',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: SizedBox(
            width: 400,
            child: ReceiptPreview(bill: completedBill),
          ),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                PdfService.printReceipt(
                  completedBill,
                  pharmacyName: dashProvider.pharmacyName,
                  storeAddress: dashProvider.storeAddress,
                );
              },
            ),
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ${result['message']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final dashProvider = Provider.of<DashboardProvider>(context);

    // Compute active warnings
    bool showLowStockWarning = false;
    bool showExpiryWarning = false;
    int currentStockCount = 0;

    if (_matchedInventoryItem != null) {
      currentStockCount = _matchedInventoryItem!.quantity;
      showLowStockWarning = currentStockCount < 15;

      try {
        final expParts = _matchedInventoryItem!.expiryDate.split('-');
        if (expParts.isNotEmpty) {
          final year = int.parse(expParts[0]);
          final month = expParts.length > 1 ? int.parse(expParts[1]) : 1;
          final expiry = DateTime(year, month);
          final threeMonthsFromNow = DateTime.now().add(const Duration(days: 90));
          showExpiryWarning = expiry.isBefore(threeMonthsFromNow);
        }
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT PANEL: Medicines Search & Details Form (Flex 5)
          Expanded(
            flex: 5,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pinned Search Card
                    CustomCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Medicines Master Lookup',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showAddManualItemDialog(context, posProvider),
                                icon: const Icon(Icons.add_circle, size: 14, color: AppColors.primary),
                                label: const Text(
                                  'Add Manual Amount',
                                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: posProvider.searchMedicines,
                            decoration: InputDecoration(
                              hintText: 'Search brand name or salt composition...',
                              prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        posProvider.searchMedicines('');
                                        setState(() {
                                          _selectedMasterMedicine = null;
                                          _matchedInventoryItem = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          ),
                          if (posProvider.isSearching)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Scrollable Details Card
                    Expanded(
                      child: CustomCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Billing Item Details',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                  ),
                                  if (_selectedMasterMedicine != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Master Seed Match',
                                        style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              if (_selectedMasterMedicine != null) ...[
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
                                      Text(
                                        'Selected: ${_selectedMasterMedicine!.medicineName}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                      ),
                                      if (_selectedMasterMedicine!.composition != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Salt: ${_selectedMasterMedicine!.composition}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                      if (_selectedMasterMedicine!.manufacturer != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Mfr: ${_selectedMasterMedicine!.manufacturer}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                 const SizedBox(height: 8),
                              ],

                              // Manual / Selected Item Name Input
                              TextField(
                                controller: _medicineNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Medicine / Item Name (Type or Select)',
                                  hintText: 'e.g. Paracetamol 500mg, Bandage, Syrup...',
                                  prefixIcon: Icon(Icons.medication, size: 18, color: AppColors.primary),
                                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Fields: Batch No, Expiry, Qty
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _batchController,
                                      decoration: const InputDecoration(
                                        labelText: 'Batch Number',
                                        hintText: 'e.g. BT-9382',
                                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _expiryController,
                                      decoration: const InputDecoration(
                                        labelText: 'Expiry Date',
                                        hintText: 'YYYY-MM',
                                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: _qtyController,
                                      focusNode: _qtyFocusNode,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Quantity',
                                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Fields: MRP, Sale Rate
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _mrpController,
                                      focusNode: _mrpFocusNode,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'MRP (₹)',
                                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _priceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Sale Rate (₹)',
                                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Warnings Section (Low Stock / Expiring)
                              if (_matchedInventoryItem != null) ...[
                                const Text(
                                  'Active Stock Intelligence Alerts:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                if (showLowStockWarning)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning, color: AppColors.warning, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Low Stock: Only $currentStockCount pack(s) remaining.',
                                            style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (showExpiryWarning) ...[
                                  if (showLowStockWarning) const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.timer_sharp, color: AppColors.error, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Expiry Alert: batch expiring soon (${_matchedInventoryItem!.expiryDate}).',
                                            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (!showLowStockWarning && !showExpiryWarning)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Stock Healthy: $currentStockCount pack(s) available.',
                                          style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),
                              ] else ...[
                                const SizedBox(height: 10),
                                if (_searchController.text.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.info, color: AppColors.info, size: 18),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'New stock will be registered in Firestore Inventory upon checkout.',
                                            style: TextStyle(color: AppColors.info, fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),
                              ],

                              // Add to Cart Button
                              ElevatedButton.icon(
                                onPressed: () => _addItemToCart(posProvider),
                                icon: const Icon(Icons.add_shopping_cart, size: 18),
                                label: const Text('Add to Cart'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Floating Dropdown Overlay
                if (_searchFocusNode.hasFocus &&
                    !posProvider.isSearching &&
                    _searchController.text.trim().isNotEmpty &&
                    _selectedMasterMedicine == null)
                  Positioned(
                    top: 92, // Positioned exactly below search field
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 220, // Max height as requested
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: posProvider.searchResults.length + 1,
                        separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (context, index) {
                          final queryText = _searchController.text.trim();
                          if (index == 0) {
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.add, color: AppColors.primaryLight, size: 20),
                              title: Text(
                                'Use "$queryText" manually',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                              ),
                              subtitle: const Text(
                                'Tap to enter custom price/details manually',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedMasterMedicine = null;
                                  _matchedInventoryItem = null;
                                  
                                  // Pre-fill defaults for convenience
                                  _batchController.text = 'BATCH-${DateTime.now().year % 100}${DateTime.now().month}';
                                  _expiryController.text = '${DateTime.now().year + 2}-${DateTime.now().month.toString().padLeft(2, '0')}';
                                  _mrpController.clear();
                                  _priceController.clear();
                                });
                                posProvider.searchMedicines('');
                                _mrpFocusNode.requestFocus();
                              },
                            );
                          }

                          final med = posProvider.searchResults[index - 1];
                          final hasStock = dashProvider.inventory.any(
                            (item) => item.medicineName.toLowerCase() == med.medicineName.toLowerCase()
                          );

                          return ListTile(
                            dense: true,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    med.medicineName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                if (hasStock)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'In Stock',
                                      style: TextStyle(color: AppColors.success, fontSize: 9),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              'Composition: ${med.composition ?? "N/A"} | Manufacturer: ${med.manufacturer ?? "Unknown"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                            trailing: Text(
                              '₹${med.mrp.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              _selectMedicine(med, dashProvider.inventory);
                              posProvider.searchMedicines('');
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // RIGHT PANEL: Cart & Billing Details (Flex 7)
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Listing Items added to Cart
                Expanded(
                  child: CustomCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Active Billing Receipt Cart',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                              ),
                              Text(
                                '${posProvider.cartItems.length} Item(s) Selected',
                                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                              )
                            ],
                          ),
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        Expanded(
                          child: posProvider.cartItems.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.shopping_basket_outlined, size: 64, color: AppColors.textMuted),
                                      SizedBox(height: 12),
                                      Text(
                                        'Your POS Cart is Empty.\nUse the left panel lookup to add items.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                                      )
                                    ],
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(AppColors.border.withValues(alpha: 0.3)),
                                    columnSpacing: 16,
                                    columns: const [
                                      DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Batch', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('MRP', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: List.generate(
                                      posProvider.cartItems.length,
                                      (index) {
                                        final item = posProvider.cartItems[index];
                                        return DataRow(
                                          cells: [
                                            DataCell(Text((index + 1).toString())),
                                            DataCell(
                                              SizedBox(
                                                width: 180,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      item.medicineName,
                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (item.substitutes != null && item.substitutes!.isNotEmpty)
                                                      Text(
                                                        'Salt: ${item.substitutes}',
                                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    if (item.category != null && item.category!.isNotEmpty)
                                                      Text(
                                                        'Mfr: ${item.category}',
                                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(item.batchNumber)),
                                            DataCell(
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppColors.primaryLight),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () => posProvider.updateItemQuantity(index, item.quantity - 1),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                                    child: Text(item.quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primaryLight),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () => posProvider.updateItemQuantity(index, item.quantity + 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(Text('₹${item.mrp.toStringAsFixed(2)}')),
                                            DataCell(Text('₹${item.salePrice.toStringAsFixed(2)}')),
                                            DataCell(Text('₹${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold))),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                                                onPressed: () => posProvider.removeItem(index),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Customer Info and Checkout Calculations
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Customer fields + payment mode
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _custNameController,
                                  focusNode: _custNameFocusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer Name',
                                    hintText: 'Walk-in Customer',
                                    prefixIcon: Icon(Icons.person, size: 18, color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _custPhoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer Phone',
                                    hintText: 'e.g. 98765xxxxx',
                                    prefixIcon: Icon(Icons.phone, size: 18, color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Direct Quick Amount Entry (Bina Medicine Sale + Description)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt, color: Colors.amber, size: 20),
                                const SizedBox(width: 6),
                                const Text(
                                  'Direct Sale Amount:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryLight),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _directAmountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: 'Enter ₹ Amount...',
                                      isDense: true,
                                      prefixIcon: Icon(Icons.currency_rupee, size: 15, color: AppColors.accent),
                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _directRemarkController,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                    decoration: const InputDecoration(
                                      hintText: 'Description / Bought Items (e.g. Syrup, Bandage)...',
                                      isDense: true,
                                      prefixIcon: Icon(Icons.edit_note, size: 16, color: AppColors.primaryLight),
                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _addDirectAmountToCart(posProvider),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Add Amount', style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _discountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Discount Deduction (₹)',
                                    prefixIcon: Icon(Icons.local_offer, size: 18, color: AppColors.textSecondary),
                                  ),
                                  onChanged: (val) {
                                    posProvider.setDiscount(double.tryParse(val) ?? 0.0);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: posProvider.paymentMode,
                                  decoration: const InputDecoration(
                                    labelText: 'Payment Mode',
                                    prefixIcon: Icon(Icons.payment, size: 18, color: AppColors.textSecondary),
                                  ),
                                  dropdownColor: AppColors.surface,
                                  items: ['Cash', 'UPI', 'Card', 'Credit']
                                      .map((mode) => DropdownMenuItem(
                                            value: mode,
                                            child: Text(mode == 'Credit' ? 'Udhar' : mode, style: const TextStyle(fontSize: 13)),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      posProvider.setPaymentMode(val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Financial Tally Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gross: ₹${posProvider.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Discount: ₹${posProvider.discount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'NET PAYABLE AMOUNT',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  Text(
                                    '₹${posProvider.netAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                                 Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: () {
                                    posProvider.resetCart();
                                    _custNameController.clear();
                                    _custPhoneController.clear();
                                    _discountController.text = '0';
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.border),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Clear Bill', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () => _triggerCheckout(posProvider, dashProvider, shouldPrint: false),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text('Save / Submit Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () => _triggerCheckout(posProvider, dashProvider, shouldPrint: true),
                                  icon: const Icon(Icons.print, size: 18),
                                  label: const Text('Save & Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_showCustomerSuggestions && _filteredCustomers.isNotEmpty)
                      Positioned(
                        top: 52, // Positioned exactly below the Customer Name field
                        left: 12,
                        width: 320, // Match width of name textfield
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _filteredCustomers.length,
                            separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                            itemBuilder: (context, index) {
                              final cust = _filteredCustomers[index];
                              return ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(0xFFE6F4EA),
                                  child: Icon(Icons.person, size: 14, color: AppColors.primary),
                                ),
                                title: Text(
                                  cust.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                                subtitle: Text(
                                  cust.phone,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                trailing: cust.pendingBalance > 0
                                    ? Text(
                                        'Bal: ₹${cust.pendingBalance.toStringAsFixed(0)}',
                                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                                      )
                                    : null,
                                onTap: () => _selectCustomer(cust),
                              );
                            },
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
    );
  }
}
