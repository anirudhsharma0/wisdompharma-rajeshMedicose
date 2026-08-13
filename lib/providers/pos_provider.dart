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
  String _paymentMode = 'Credit';

  // Search autocomplete state
  List<MedicineMasterModel> _searchResults = [];
  bool _isSearching = false;

  // Local storage fallback if Firebase is not initialized
  final List<BillModel> _localFallbackBills = [];

  // Getters
  List<BillItem> get cartItems => _cartItems;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  double get discount => _discount;
  String get paymentMode => _paymentMode;
  List<MedicineMasterModel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  double get totalAmount {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get netAmount {
    return (totalAmount - _discount).clamp(0.0, 9999999.0);
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

  void setPaymentMode(String mode) {
    _paymentMode = mode;
    notifyListeners();
  }

  // Clear POS billing sheet
  void resetCart() {
    _cartItems = [];
    _customerName = '';
    _customerPhone = '';
    _discount = 0.0;
    _paymentMode = 'Credit';
    _searchResults = [];
    notifyListeners();
  }

  // Auto-complete medicine search from SQLite (Desktop-only)
  Future<void> searchMedicines(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await SqliteService.instance.searchMedicines(query);
    } catch (e) {
      debugPrint('SQLite Search Error: $e');
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  // Add item to active cart
  void addItemToCart({
    required String name,
    required String batch,
    required String expiry,
    required int quantity,
    required double mrp,
    required double salePrice,
    String? substitutes,
    String? category,
  }) {
    // Check if item already exists in cart, if so update quantity
    final existingIndex = _cartItems.indexWhere(
        (item) => item.medicineName.toLowerCase() == name.toLowerCase() && item.batchNumber == batch);

    if (existingIndex != -1) {
      final existingItem = _cartItems[existingIndex];
      final newQty = existingItem.quantity + quantity;
      _cartItems[existingIndex] = BillItem(
        medicineName: existingItem.medicineName,
        batchNumber: existingItem.batchNumber,
        expiryDate: existingItem.expiryDate,
        quantity: newQty,
        mrp: existingItem.mrp,
        salePrice: existingItem.salePrice,
        totalPrice: newQty * existingItem.salePrice,
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

  // Complete billing & push to Firestore (with local in-memory fallback)
  Future<Map<String, dynamic>> checkout() async {
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
      netAmount: netAmount,
      createdAt: DateTime.now(),
      paymentMode: _paymentMode,
    );

    try {
      // Try to save to Firebase
      final billId = await FirebaseService.instance.createBill(bill);
      resetCart();
      return {
        'success': true,
        'message': 'Bill #$billNumber generated successfully & uploaded to Firebase.',
        'billId': billId,
        'bill': bill,
      };
    } catch (e) {
      // Fallback to local simulated storage
      debugPrint('Firebase checkout failed, saving locally: $e');
      final offlineBill = bill.copyWith(id: 'local_${DateTime.now().millisecondsSinceEpoch}');
      _localFallbackBills.add(offlineBill);
      resetCart();
      return {
        'success': true,
        'message': 'Bill #$billNumber generated offline (Firebase not configured).',
        'billId': offlineBill.id,
        'bill': offlineBill,
        'isOffline': true,
      };
    }
  }

  // Get local fallback bills
  List<BillModel> get localFallbackBills => _localFallbackBills;
}
