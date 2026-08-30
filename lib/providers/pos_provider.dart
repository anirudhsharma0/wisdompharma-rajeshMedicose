import 'package:flutter/material.dart';
import '../data/models/bill_model.dart';
import '../data/models/medicine_master_model.dart';
import '../data/services/sqlite_service.dart';
import '../data/services/firebase_service.dart';

class PosProvider extends ChangeNotifier {
  // POS Billing Cart State
  List<BillItem> _cartItems = [];
  String _customerName = '';
  String _customerPhone = '';
  double _discount = 0.0;
  double _gstPercentage = 0.0; // GST % (e.g., 0, 5, 12, 18)
  String _paymentMode = 'Credit';

  // Search autocomplete state
  List<MedicineMasterModel> _searchResults = [];
  bool _isSearching = false;

  // Local storage fallback if Firebase is not initialized
  final List<BillModel> _localFallbackBills = [];

  DateTime? _billDate;

  // Getters
  List<BillItem> get cartItems => _cartItems;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  double get discount => _discount;
  double get gstPercentage => _gstPercentage;
  String get paymentMode => _paymentMode;
  DateTime get billDate => _billDate ?? DateTime.now();

  bool get isCustomBillDate {
    if (_billDate == null) return false;
    final now = DateTime.now();
    return !(_billDate!.year == now.year && _billDate!.month == now.month && _billDate!.day == now.day);
  }
  List<MedicineMasterModel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  double get totalAmount {
    return _cartItems.fold(0.0, (sum, item) => sum + item.grossAmount);
  }


  double get taxableAmount {
    return (totalAmount - _discount).clamp(0.0, 9999999.0);
  }

  double get gstAmount {
    return (taxableAmount * _gstPercentage / 100.0);
  }

  double get netAmount {
    return (taxableAmount + gstAmount).clamp(0.0, 9999999.0);
  }

  // Setters & Cart Actions
  void setCustomerName(String name) {
    _customerName = name;
    notifyListeners();
  }

  void setCustomerPhone(String phone) {
    _customerPhone = phone;
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discount = amount;
    notifyListeners();
  }

  void setGstPercentage(double rate) {
    _gstPercentage = rate;
    notifyListeners();
  }

  void setPaymentMode(String mode) {
    _paymentMode = mode;
    notifyListeners();
  }

  void setBillDate(DateTime? date) {
    _billDate = date;
    notifyListeners();
  }

  // Clear POS billing sheet
  void resetCart({bool preserveBillDate = true}) {
    _cartItems = [];
    _customerName = '';
    _customerPhone = '';
    _discount = 0.0;
    _gstPercentage = 0.0;
    _paymentMode = 'Credit';
    if (!preserveBillDate) {
      _billDate = null;
    }
    _searchResults = [];
    notifyListeners();
  }

  // Auto-complete medicine search from SQLite (Desktop-only)
  Future<void> searchMedicines(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      if (_searchResults.isNotEmpty || _isSearching) {
        _searchResults = [];
        _isSearching = false;
        notifyListeners();
      }
      return;
    }

    try {
      _searchResults = await SqliteService.instance.searchMedicines(clean);
    } catch (e) {
      debugPrint('SQLite Search Error: $e');
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  // Add item to active cart with stock limit validation
  Map<String, dynamic> addItemToCart({
    required String name,
    required String batch,
    required String expiry,
    required int quantity,
    required double mrp,
    required double salePrice,
    int? availableStock,
    String? substitutes,
    String? category,
  }) {
    if (quantity <= 0) {
      return {'success': false, 'message': 'Quantity must be greater than 0.'};
    }

    // Check if item already exists in cart, if so update quantity
    final existingIndex = _cartItems.indexWhere(
        (item) => item.medicineName.toLowerCase() == name.toLowerCase() && item.batchNumber == batch);

    final currentInCart = existingIndex != -1 ? _cartItems[existingIndex].quantity : 0;
    final totalRequestedQty = currentInCart + quantity;

    if (availableStock != null && totalRequestedQty > availableStock) {
      return {
        'success': false,
        'message': 'Cannot add quantity ($totalRequestedQty). Only $availableStock units available in batch "$batch".',
      };
    }

    if (existingIndex != -1) {
      final existingItem = _cartItems[existingIndex];
      _cartItems[existingIndex] = BillItem(
        medicineName: existingItem.medicineName,
        batchNumber: existingItem.batchNumber,
        expiryDate: existingItem.expiryDate,
        quantity: totalRequestedQty,
        mrp: existingItem.mrp,
        salePrice: existingItem.salePrice,
        totalPrice: totalRequestedQty * existingItem.salePrice,
        substitutes: existingItem.substitutes ?? substitutes,
        category: existingItem.category ?? category,
      );
    } else {
      _cartItems.add(BillItem(
        medicineName: name,
        batchNumber: batch,
        expiryDate: expiry,
        quantity: quantity,
        mrp: mrp,
        salePrice: salePrice,
        totalPrice: quantity * salePrice,
        substitutes: substitutes,
        category: category,
      ));
    }
    notifyListeners();
    return {'success': true};
  }

  void updateItemQuantity(int index, int newQty) {
    if (index >= 0 && index < _cartItems.length && newQty > 0) {
      final item = _cartItems[index];
      _cartItems[index] = BillItem(
        medicineName: item.medicineName,
        batchNumber: item.batchNumber,
        expiryDate: item.expiryDate,
        quantity: newQty,
        mrp: item.mrp,
        salePrice: item.salePrice,
        totalPrice: newQty * item.salePrice,
        substitutes: item.substitutes,
        category: item.category,
      );
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  // Complete billing & push to Firestore
  Future<Map<String, dynamic>> checkout({List<dynamic>? currentInventory}) async {
    if (_cartItems.isEmpty) {
      return {'success': false, 'message': 'Cart is empty'};
    }

    final billNumber = 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final bill = BillModel(
      billNumber: billNumber,
      customerName: _customerName.isEmpty ? 'Walk-in Customer' : _customerName,
      customerPhone: _customerPhone,
      items: List.from(_cartItems),
      totalAmount: totalAmount,
      discount: _discount,
      gstPercentage: _gstPercentage,
      gstAmount: gstAmount,
      netAmount: netAmount,
      createdAt: _billDate ?? DateTime.now(),
      paymentMode: _paymentMode,
    );

    try {
      final res = await FirebaseService.instance.createBill(bill);
      final billId = res['id'] as String;
      final warnings = res['warnings'] as List<String>? ?? [];

      resetCart();
      String msg = 'Bill #$billNumber generated successfully.';
      if (warnings.isNotEmpty) {
        msg += '\nNote: ${warnings.join(" ")}';
      }

      return {
        'success': true,
        'message': msg,
        'billId': billId,
        'bill': bill,
        'warnings': warnings,
      };
    } catch (e) {
      debugPrint('Firebase checkout failed, saving locally: $e');
      final offlineBill = bill.copyWith(id: 'local_${DateTime.now().millisecondsSinceEpoch}');
      _localFallbackBills.add(offlineBill);
      resetCart();
      return {
        'success': true,
        'message': 'Bill #$billNumber generated offline (Saved to local memory).',
        'billId': offlineBill.id,
        'bill': offlineBill,
        'isOffline': true,
      };
    }
  }

  // Get local fallback bills
  List<BillModel> get localFallbackBills => _localFallbackBills;
}
