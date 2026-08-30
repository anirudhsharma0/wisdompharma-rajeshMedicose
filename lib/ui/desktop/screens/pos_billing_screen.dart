import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/medicine_master_model.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/bill_model.dart';
import '../../../data/models/customer_model.dart';
import '../../common/widgets/custom_card.dart';
import '../../common/widgets/receipt_preview.dart';
import '../../common/widgets/loading_overlay.dart';
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

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }

                if (context.mounted) {
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
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Checkout failed: ${result['message']}')),
                  );
                }
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
                              onSubmitted: (_) => processQuickSaleCheckout(shouldPrint: true),
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
                              onSubmitted: (_) => processQuickSaleCheckout(shouldPrint: true),
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
                                    onSubmitted: (_) => processQuickSaleCheckout(shouldPrint: true),
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
                                    onSubmitted: (_) => processQuickSaleCheckout(shouldPrint: true),
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
                              onSubmitted: (_) => processQuickSaleCheckout(shouldPrint: true),
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
                              initialValue: selectedPaymentMode,
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

  final FocusNode _screenFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _batchFocusNode = FocusNode();
  final FocusNode _expiryFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _mrpFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _custNameFocusNode = FocusNode();
  final FocusNode _custPhoneFocusNode = FocusNode();
  final FocusNode _discountFocusNode = FocusNode();
  final FocusNode _directAmountFocusNode = FocusNode();
  final FocusNode _directRemarkFocusNode = FocusNode();

  int _activeBillingMode = 0; // 0 = Quick Direct Cash Sale, 1 = Detailed Medicine Billing

  MedicineMasterModel? _selectedMasterMedicine;
  InventoryModel? _matchedInventoryItem;

  List<CustomerModel> _filteredCustomers = [];
  bool _showCustomerSuggestions = false;
  bool _showVirtualNumpad = false;

  Future<void> _selectBillDate(BuildContext context, PosProvider posProvider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: posProvider.billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      posProvider.setBillDate(picked);
    }
  }

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

  void _onNumpadPressed(String val) {
    TextEditingController targetCtrl;
    if (_searchFocusNode.hasFocus) {
      targetCtrl = _searchController;
    } else if (_qtyFocusNode.hasFocus) {
      targetCtrl = _qtyController;
    } else if (_mrpFocusNode.hasFocus) {
      targetCtrl = _mrpController;
    } else if (_priceFocusNode.hasFocus) {
      targetCtrl = _priceController;
    } else if (_custNameFocusNode.hasFocus) {
      targetCtrl = _custNameController;
    } else if (_custPhoneFocusNode.hasFocus) {
      targetCtrl = _custPhoneController;
    } else if (_discountFocusNode.hasFocus) {
      targetCtrl = _discountController;
    } else if (_directAmountFocusNode.hasFocus) {
      targetCtrl = _directAmountController;
    } else {
      targetCtrl = _qtyController;
    }

    if (val == 'CLEAR') {
      targetCtrl.clear();
    } else if (val == 'BACK') {
      if (targetCtrl.text.isNotEmpty) {
        targetCtrl.text = targetCtrl.text.substring(0, targetCtrl.text.length - 1);
      }
    } else if (val == 'ENTER') {
      final posProvider = Provider.of<PosProvider>(context, listen: false);
      final dashProvider = Provider.of<DashboardProvider>(context, listen: false);
      if (targetCtrl == _searchController || targetCtrl == _qtyController || targetCtrl == _mrpController || targetCtrl == _priceController) {
        _addItemToCart(posProvider);
      } else if (targetCtrl == _directAmountController) {
        _addDirectAmountToCart(posProvider);
      } else {
        _triggerCheckout(posProvider, dashProvider, shouldPrint: true);
      }
    } else if (val == '+') {
      final curVal = int.tryParse(targetCtrl.text) ?? 1;
      targetCtrl.text = (curVal + 1).toString();
    } else if (val == '-') {
      final curVal = int.tryParse(targetCtrl.text) ?? 1;
      if (curVal > 1) {
        targetCtrl.text = (curVal - 1).toString();
      }
    } else {
      targetCtrl.text = targetCtrl.text + val;
    }
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

    _screenFocusNode.dispose();
    _searchFocusNode.dispose();
    _batchFocusNode.dispose();
    _expiryFocusNode.dispose();
    _qtyFocusNode.dispose();
    _mrpFocusNode.dispose();
    _priceFocusNode.dispose();
    _custNameFocusNode.dispose();
    _custPhoneFocusNode.dispose();
    _discountFocusNode.dispose();
    _directAmountFocusNode.dispose();
    _directRemarkFocusNode.dispose();
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

    final res = posProvider.addItemToCart(
      name: name,
      batch: batch,
      expiry: expiry,
      quantity: qty,
      mrp: mrp,
      salePrice: salePrice,
      availableStock: _matchedInventoryItem?.quantity,
      substitutes: _selectedMasterMedicine?.composition,
      category: _selectedMasterMedicine?.manufacturer,
    );

    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Stock limit error'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

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

    // Checkout with inventory stock revalidation
    AppLoadingOverlay.show(context, message: 'Generating POS Bill & Updating Stock...');
    Map<String, dynamic> result;
    try {
      result = await posProvider.checkout(currentInventory: dashProvider.inventory);
    } finally {
      if (mounted) {
        AppLoadingOverlay.hide(context);
      }
    }

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
      _directRemarkController.clear();

      // Automatically reset focus back to Customer Name input field for rapid next bill entry
      Future.microtask(() {
        if (mounted) {
          _custNameFocusNode.requestFocus();
        }
      });

      // Trigger PDF print & Invoice Dialog ONLY if explicitly requested by clicking "Save & Print"
      if (shouldPrint) {
        try {
          await PdfService.printReceipt(
            completedBill,
            pharmacyName: dashProvider.pharmacyName,
            storeAddress: dashProvider.storeAddress,
            gstin: dashProvider.gstin,
          );
        } catch (e) {
          debugPrint('Print error: $e');
        }

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bill Saved & Sent to Printer',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
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
        // FAST DIRECT SALE: Floating green success notification
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✅ Bill Saved Successfully! (#${completedBill.billNumber}) — Total: ₹${completedBill.netAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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

    return KeyboardListener(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.f2) {
            _searchFocusNode.requestFocus();
          } else if (key == LogicalKeyboardKey.f3) {
            _custNameFocusNode.requestFocus();
          } else if (key == LogicalKeyboardKey.f4) {
            PosBillingScreen.openQuickSaleDialog(context);
          } else if (key == LogicalKeyboardKey.f9) {
            _triggerCheckout(posProvider, dashProvider, shouldPrint: false);
          } else if (key == LogicalKeyboardKey.f12) {
            _triggerCheckout(posProvider, dashProvider, shouldPrint: true);
          } else if (key == LogicalKeyboardKey.escape) {
            posProvider.resetCart();
            _custNameController.clear();
            _custPhoneController.clear();
            _discountController.text = '0';
            _searchFocusNode.requestFocus();
          }
        }
      },
      child: Column(
        children: [
          _buildKeyboardShortcutsHeader(context),
          _buildModeTabBar(),
          if (_showVirtualNumpad)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: _buildVirtualNumpadDrawer(posProvider, dashProvider),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: _activeBillingMode == 0
                  ? _buildQuickBillingView(posProvider, dashProvider)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // LEFT / MAIN PANEL: Medicine Details Form + Cart Items Table (Flex 4 - Compact)
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Pinned Card: Billing Item Details & Medicine Lookup
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomCard(
                              padding: const EdgeInsets.all(14),
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
                                      TextButton.icon(
                                        onPressed: () => _showAddManualItemDialog(context, posProvider),
                                        icon: const Icon(Icons.add_circle, size: 15, color: AppColors.primary),
                                        label: const Text(
                                          'Add Manual Amount',
                                          style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Search & Medicine Name Input
                                  TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    onChanged: posProvider.searchMedicines,
                                    onSubmitted: (_) => _addItemToCart(posProvider),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      labelText: 'Medicine / Item Name (Type or Search brand/salt)',
                                      hintText: 'Search brand name or salt composition...',
                                      prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                                              onPressed: () {
                                                _searchController.clear();
                                                _medicineNameController.clear();
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
                                      padding: EdgeInsets.only(top: 6.0),
                                      child: Center(child: LinearProgressIndicator(minHeight: 2)),
                                    ),

                                  if (_selectedMasterMedicine != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Selected: ${_selectedMasterMedicine!.medicineName}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                                ),
                                                Text(
                                                  'Salt: ${_selectedMasterMedicine!.composition ?? "N/A"} | Mfr: ${_selectedMasterMedicine!.manufacturer ?? "N/A"}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),

                                  // Item Attributes: Batch, Expiry, Qty, MRP, Sale Price
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: _batchController,
                                          focusNode: _batchFocusNode,
                                          onSubmitted: (_) => _addItemToCart(posProvider),
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
                                          focusNode: _expiryFocusNode,
                                          onSubmitted: (_) => _addItemToCart(posProvider),
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
                                          onSubmitted: (_) => _addItemToCart(posProvider),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(
                                            labelText: 'Qty',
                                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: _mrpController,
                                          focusNode: _mrpFocusNode,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onSubmitted: (_) => _addItemToCart(posProvider),
                                          decoration: const InputDecoration(
                                            labelText: 'MRP (₹)',
                                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: _priceController,
                                          focusNode: _priceFocusNode,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onSubmitted: (_) => _addItemToCart(posProvider),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                                          decoration: const InputDecoration(
                                            labelText: 'Sale Rate (₹)',
                                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Warnings & Intelligence
                                  if (_matchedInventoryItem != null) ...[
                                    if (showLowStockWarning)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text('⚠️ Low Stock Alert: Only $currentStockCount pack(s) remaining in stock.', style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    if (showExpiryWarning)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text('🚨 Expiry Alert: Batch expiring soon (${_matchedInventoryItem!.expiryDate}).', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    const SizedBox(height: 8),
                                  ],

                                  // Add to Cart Action Button
                                  ElevatedButton.icon(
                                    onPressed: () => _addItemToCart(posProvider),
                                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                                    label: const Text('Add to Cart [Enter]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Floating Search Dropdown Overlay
                            if (_searchFocusNode.hasFocus &&
                                !posProvider.isSearching &&
                                _searchController.text.trim().isNotEmpty &&
                                _selectedMasterMedicine == null)
                              Positioned(
                                top: 85,
                                left: 14,
                                right: 14,
                                child: Container(
                                  height: 220,
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
                                          subtitle: const Text('Tap to enter custom price/details manually', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                          onTap: () {
                                            setState(() {
                                              _selectedMasterMedicine = null;
                                              _matchedInventoryItem = null;
                                              _medicineNameController.text = queryText;
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
                                                child: const Text('In Stock', style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        subtitle: Text('Composition: ${med.composition ?? "N/A"} | Manufacturer: ${med.manufacturer ?? "Unknown"}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                        trailing: Text('₹${med.mrp.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
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
                        const SizedBox(height: 12),

                        // Bottom Cart Table Card (Under Billing Item Details)
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
                                      Row(
                                        children: [
                                          const Icon(Icons.shopping_cart, color: AppColors.primary, size: 20),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Active Billing Receipt Cart',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${posProvider.cartItems.length} Item(s) Added',
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
                                              Icon(Icons.shopping_basket_outlined, size: 54, color: AppColors.textMuted),
                                              SizedBox(height: 10),
                                              Text(
                                                'Your POS Cart is Empty.\nSearch or enter medicine details above and press Enter / Numpad Enter.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // RIGHT PANEL: Customer Details & Checkout Sidebar (Flex 6 - MAIN & ENLARGED UI)
                  Expanded(
                    flex: 6,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomCard(
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header
                                Row(
                                  children: const [
                                    Icon(Icons.person_pin, color: AppColors.primary, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      'Customer & Bill Checkout',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text('Enter customer details manually and complete settlement', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                const Divider(color: AppColors.border, height: 24),

                                // Customer Details Section (ENLARGED)
                                const Text('CUSTOMER INFORMATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight, letterSpacing: 0.5)),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _custNameController,
                                  focusNode: _custNameFocusNode,
                                  onSubmitted: (_) => _triggerCheckout(posProvider, dashProvider, shouldPrint: false),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name (Type or Select)',
                                    hintText: 'e.g. Rahul Sharma / Walk-in Customer',
                                    prefixIcon: const Icon(Icons.person, size: 20, color: AppColors.primary),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _custPhoneController,
                                  focusNode: _custPhoneFocusNode,
                                  keyboardType: TextInputType.phone,
                                  onSubmitted: (_) => _triggerCheckout(posProvider, dashProvider, shouldPrint: false),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    labelText: 'Customer Mobile Phone',
                                    hintText: 'Enter 10-digit phone number',
                                    prefixIcon: const Icon(Icons.phone, size: 20, color: AppColors.primary),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const Divider(color: AppColors.border, height: 24),

                                // Direct Quick Amount Entry (ENLARGED)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.bolt, color: Colors.amber, size: 20),
                                          SizedBox(width: 6),
                                          Text(
                                            'Direct Sale (Quick Amount)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextField(
                                              controller: _directAmountController,
                                              focusNode: _directAmountFocusNode,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              onSubmitted: (_) => _addDirectAmountToCart(posProvider),
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 16),
                                              decoration: InputDecoration(
                                                hintText: 'Enter ₹ Amount',
                                                prefixIcon: const Icon(Icons.currency_rupee, size: 18, color: AppColors.accent),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 4,
                                            child: TextField(
                                              controller: _directRemarkController,
                                              onSubmitted: (_) => _addDirectAmountToCart(posProvider),
                                              style: const TextStyle(fontSize: 13),
                                              decoration: InputDecoration(
                                                hintText: 'Description / Item',
                                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _addDirectAmountToCart(posProvider),
                                          icon: const Icon(Icons.add_circle, size: 16),
                                          label: const Text('Add Direct Amount to Cart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: AppColors.border, height: 24),

                                // Settlement Details (ENLARGED DROPDOWNS & INPUTS)
                                const Text('DISCOUNT & PAYMENT MODE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight, letterSpacing: 0.5)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _discountController,
                                        focusNode: _discountFocusNode,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onSubmitted: (_) => _triggerCheckout(posProvider, dashProvider, shouldPrint: true),
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          labelText: 'Discount (₹)',
                                          prefixIcon: const Icon(Icons.local_offer, size: 18, color: AppColors.textSecondary),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onChanged: (val) {
                                          posProvider.setDiscount(double.tryParse(val) ?? 0.0);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<double>(
                                        initialValue: posProvider.gstPercentage,
                                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          labelText: 'GST Rate',
                                          prefixIcon: const Icon(Icons.percent, size: 18, color: AppColors.textSecondary),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        dropdownColor: AppColors.surface,
                                        items: [0.0, 5.0, 12.0, 18.0, 28.0]
                                            .map((rate) => DropdownMenuItem(
                                                  value: rate,
                                                  child: Text(rate == 0.0 ? 'Exempt (0%)' : 'GST ${rate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 13)),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            posProvider.setGstPercentage(val);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: posProvider.paymentMode,
                                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'Payment Mode',
                                    prefixIcon: const Icon(Icons.payment, size: 20, color: AppColors.primary),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  dropdownColor: AppColors.surface,
                                  items: ['Cash', 'UPI', 'Card', 'Credit']
                                      .map((mode) => DropdownMenuItem(
                                            value: mode,
                                            child: Text(mode == 'Credit' ? 'Udhar (Credit Customer Ledger)' : mode, style: const TextStyle(fontSize: 14)),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      posProvider.setPaymentMode(val);
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Financial Tally Summary Box (ENLARGED)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Subtotal / Gross:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                          Text('₹${posProvider.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Discount Applied:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                          Text('-₹${posProvider.discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                                        ],
                                      ),
                                      if (posProvider.gstAmount > 0) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('GST (${posProvider.gstPercentage.toStringAsFixed(0)}%):', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                            Text('+₹${posProvider.gstAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 14)),
                                          ],
                                        ),
                                      ],
                                      const Divider(color: AppColors.border, height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: const [
                                              Text('NET PAYABLE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                              Text('FINAL AMOUNT', style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w900)),
                                            ],
                                          ),
                                          Text(
                                            '₹${posProvider.netAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Action Checkout Buttons
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
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Clear [Esc]', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _triggerCheckout(posProvider, dashProvider, shouldPrint: false),
                                        icon: const Icon(Icons.check_circle_outline, size: 18),
                                        label: const Text('Save Bill [F9]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _triggerCheckout(posProvider, dashProvider, shouldPrint: true),
                                        icon: const Icon(Icons.print, size: 18),
                                        label: const Text('Save & Print [F12]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Customer Search Autocomplete Overlay
                        if (_showCustomerSuggestions && _filteredCustomers.isNotEmpty)
                          Positioned(
                            top: 130,
                            left: 16,
                            right: 16,
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
                                            'Udhar: ₹${cust.pendingBalance.toStringAsFixed(0)}',
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardShortcutsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.keyboard, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('KEYBOARD:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.primary, letterSpacing: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: const [
                  _ShortcutTag(keyLabel: 'F2', actionLabel: 'Search Med'),
                  _ShortcutTag(keyLabel: 'F3', actionLabel: 'Customer Name'),
                  _ShortcutTag(keyLabel: 'F4', actionLabel: 'Quick Sale'),
                  _ShortcutTag(keyLabel: 'F9', actionLabel: 'Save Bill'),
                  _ShortcutTag(keyLabel: 'F12 / Numpad Enter', actionLabel: 'Save & Print'),
                  _ShortcutTag(keyLabel: 'Esc', actionLabel: 'Clear Cart'),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _showVirtualNumpad = !_showVirtualNumpad),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _showVirtualNumpad ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.dialpad, size: 14, color: _showVirtualNumpad ? Colors.white : AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _showVirtualNumpad ? 'Hide Numpad' : 'Numpad Buttons',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _showVirtualNumpad ? Colors.white : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<PosProvider>(
            builder: (context, posProvider, _) {
              return InkWell(
                onTap: () => _selectBillDate(context, posProvider),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: posProvider.isCustomBillDate ? Colors.orange.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: posProvider.isCustomBillDate ? Colors.orange : AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 13, color: posProvider.isCustomBillDate ? Colors.orange.shade900 : AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '📅 Date: ${DateFormat('dd/MM/yyyy').format(posProvider.billDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: posProvider.isCustomBillDate ? Colors.orange.shade900 : AppColors.primary,
                        ),
                      ),
                      if (posProvider.isCustomBillDate) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => posProvider.setBillDate(null),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualNumpadDrawer(PosProvider posProvider, DashboardProvider dashProvider) {
    final buttons = [
      ['7', '8', '9', '⌫'],
      ['4', '5', '6', 'CLEAR'],
      ['1', '2', '3', '00'],
      ['0', '.', '+', 'ENTER'],
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.dialpad, size: 16, color: Colors.amber),
                  SizedBox(width: 6),
                  Text('Virtual Numeric Keypad (Touch / Click Numpad)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                onPressed: () => setState(() => _showVirtualNumpad = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: buttons.map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: row.map((btn) {
                    final isAction = btn == 'ENTER' || btn == 'CLEAR' || btn == '⌫';
                    final isEnter = btn == 'ENTER';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEnter
                                ? const Color(0xFF10B981)
                                : isAction
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF334155),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            if (btn == '⌫') {
                              _onNumpadPressed('BACK');
                            } else {
                              _onNumpadPressed(btn);
                            }
                          },
                          child: Text(
                            btn,
                            style: TextStyle(
                              fontSize: isAction && btn.length > 2 ? 11 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeBillingMode = 0;
                });
                _custNameFocusNode.requestFocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeBillingMode == 0 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, color: _activeBillingMode == 0 ? Colors.white : Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '⚡ Quick Direct Cash Sale (Fast Counter Billing)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _activeBillingMode == 0 ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeBillingMode = 1;
                });
                _searchFocusNode.requestFocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeBillingMode == 1 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medication, color: _activeBillingMode == 1 ? Colors.white : AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '💊 Detailed Itemized Medicine Billing',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _activeBillingMode == 1 ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBillingView(PosProvider posProvider, DashboardProvider dashProvider) {
    final amt = double.tryParse(_directAmountController.text) ?? 0.0;
    final disc = double.tryParse(_discountController.text) ?? 0.0;
    final netAmt = (amt - disc).clamp(0.0, 9999999.0);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 750),
        child: CustomCard(
          padding: const EdgeInsets.all(24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt, color: Colors.amber, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                '⚡ Direct Sale / Fast Counter Billing Mode',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              Text(
                                'Press ENTER on keyboard to jump to next input & auto-save bill!',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 16),

                    // 1. Customer Info
                    const Text('CUSTOMER INFORMATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _custNameController,
                            focusNode: _custNameFocusNode,
                            autofocus: true,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: '1. Customer Name',
                              hintText: 'Walk-in Customer (Type to search...)',
                              prefixIcon: const Icon(Icons.person, size: 20, color: AppColors.primary),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onSubmitted: (_) {
                              if (_showCustomerSuggestions && _filteredCustomers.isNotEmpty) {
                                _selectCustomer(_filteredCustomers.first);
                              }
                              _custPhoneFocusNode.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _custPhoneController,
                            focusNode: _custPhoneFocusNode,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: '2. Customer Mobile Phone',
                              hintText: '98765xxxxx (Press Enter)',
                              prefixIcon: const Icon(Icons.phone, size: 20, color: AppColors.primary),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onSubmitted: (_) => _directAmountFocusNode.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () => _selectBillDate(context, posProvider),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: posProvider.isCustomBillDate ? Colors.orange.shade600 : Colors.grey.shade400, width: posProvider.isCustomBillDate ? 1.5 : 1),
                                borderRadius: BorderRadius.circular(10),
                                color: posProvider.isCustomBillDate ? Colors.orange.shade50.withValues(alpha: 0.5) : Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 18, color: posProvider.isCustomBillDate ? Colors.orange.shade800 : AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          posProvider.isCustomBillDate ? 'Invoice Date (Custom)' : 'Invoice Date',
                                          style: TextStyle(fontSize: 10, color: posProvider.isCustomBillDate ? Colors.orange.shade900 : AppColors.textSecondary, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(posProvider.billDate),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: posProvider.isCustomBillDate ? Colors.orange.shade900 : AppColors.textPrimary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (posProvider.isCustomBillDate)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16, color: Colors.orange),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Reset to Today',
                                      onPressed: () => posProvider.setBillDate(null),
                                    )
                                  else
                                    const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Direct Sale Amount & Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DIRECT SALE AMOUNT & DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight, letterSpacing: 0.5)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _directAmountController,
                                  focusNode: _directAmountFocusNode,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                                  decoration: InputDecoration(
                                    labelText: '3. Sale Amount (₹)*',
                                    hintText: 'e.g. 500',
                                    prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _directRemarkFocusNode.requestFocus(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: _directRemarkController,
                                  focusNode: _directRemarkFocusNode,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: '4. Description / Item Name',
                                    hintText: 'General Medical Sale',
                                    prefixIcon: const Icon(Icons.edit_note),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onSubmitted: (_) => _discountFocusNode.requestFocus(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                // 3. Discount & Payment Mode
                const Text('DISCOUNT & PAYMENT MODE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        focusNode: _discountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: '5. Discount Deduction (₹)',
                          prefixIcon: const Icon(Icons.local_offer, size: 18, color: AppColors.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _triggerCheckout(posProvider, dashProvider, shouldPrint: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: posProvider.paymentMode,
                        decoration: InputDecoration(
                          labelText: 'Payment Mode',
                          prefixIcon: const Icon(Icons.payment, size: 18, color: AppColors.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: ['Cash', 'UPI', 'Card', 'Credit']
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m == 'Credit' ? 'Udhar (Credit Customer Ledger)' : m, style: const TextStyle(fontSize: 13)),
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
                const SizedBox(height: 20),

                // Net Payable Live Tally Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gross Amount: ₹${amt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('Discount Deducted: ₹${disc.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('NET PAYABLE AMOUNT', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          Text(
                            '₹${netAmt.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons: Save / Submit Bill | Save & Print
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _triggerCheckout(posProvider, dashProvider, shouldPrint: false),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Save / Submit Bill (F9)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _triggerCheckout(posProvider, dashProvider, shouldPrint: true),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Save & Print (F12 / Enter)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

              // Customer Search Autocomplete Floating Overlay
              if (_showCustomerSuggestions && _filteredCustomers.isNotEmpty)
                Positioned(
                  top: 135,
                  left: 0,
                  right: 0,
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surface,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '🔍 Matching Customers Found (${_filteredCustomers.length})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                const Text('Click to select customer details', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _filteredCustomers.length,
                              separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                              itemBuilder: (context, index) {
                                final cust = _filteredCustomers[index];
                                return ListTile(
                                  dense: true,
                                  hoverColor: AppColors.primary.withValues(alpha: 0.08),
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
                                    cust.phone.isNotEmpty ? '📱 ${cust.phone}' : 'No phone number',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  trailing: cust.pendingBalance > 0
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Udhar: ₹${cust.pendingBalance.toStringAsFixed(0)}',
                                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        )
                                      : const Icon(Icons.north_west, size: 14, color: AppColors.textMuted),
                                  onTap: () {
                                    _selectCustomer(cust);
                                    _custPhoneFocusNode.requestFocus();
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutTag extends StatelessWidget {
  final String keyLabel;
  final String actionLabel;

  const _ShortcutTag({required this.keyLabel, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              keyLabel,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            actionLabel,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

