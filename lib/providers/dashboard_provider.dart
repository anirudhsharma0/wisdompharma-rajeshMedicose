import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/bill_model.dart';
import '../data/models/inventory_model.dart';
import '../data/models/customer_model.dart';
import '../data/models/supplier_model.dart';
import '../data/models/voucher_model.dart';
import '../data/services/firebase_service.dart';

final List<CustomerModel> _initialUserCustomers = [];

class DashboardProvider extends ChangeNotifier {
  // Streams data
  List<BillModel> _bills = [];
  List<InventoryModel> _inventory = [];
  List<CustomerModel> _customers = [];
  List<CustomerPaymentModel> _customerPayments = [];
  List<VoucherModel> _vouchers = [];
  List<SupplierModel> _suppliers = [];

  // Settings State
  String _pharmacyName = 'Rajesh Medicose';
  String _storeAddress = 'VPO Chaharwala (Sirsa) 125110';
  String _gstin = '23AAAAA1111A1Z1';

  // Stream Subscriptions
  StreamSubscription? _billsSubscription;
  StreamSubscription? _inventorySubscription;
  StreamSubscription? _customersSubscription;
  StreamSubscription? _suppliersSubscription;
  StreamSubscription? _paymentsSubscription;
  StreamSubscription? _vouchersSubscription;

  bool _isLoading = true;
  bool _firebaseActive = false;

  // Getters
  List<BillModel> get bills => _bills;
  List<InventoryModel> get inventory => _inventory;
  List<CustomerModel> get customers => _customers;
  List<CustomerPaymentModel> get customerPayments => _customerPayments;
  List<VoucherModel> get vouchers => _vouchers;
  List<SupplierModel> get suppliers => _suppliers;
  bool get isLoading => _isLoading;
  bool get firebaseActive => _firebaseActive;

  String get pharmacyName => _pharmacyName;
  String get storeAddress => _storeAddress;
  String get gstin => _gstin;

  DashboardProvider() {
    _init();
  }

  Future<void> _init() async {
    _loadOfflineCustomers();
    initRealtimeSync();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pharmacyName = prefs.getString('pharmacyName') ?? 'Rajesh Medicose';
      _storeAddress = prefs.getString('storeAddress') ?? 'VPO Chaharwala (Sirsa) 125110';
      _gstin = prefs.getString('gstin') ?? '23AAAAA1111A1Z1';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> updateSettings({
    required String name,
    required String address,
    required String gstin,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pharmacyName', name);
      await prefs.setString('storeAddress', address);
      await prefs.setString('gstin', gstin);
      
      _pharmacyName = name;
      _storeAddress = address;
      _gstin = gstin;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  void initRealtimeSync() {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Bills Sync
      _billsSubscription = FirebaseService.instance.streamBills().listen(
        (data) {
          _bills = data;
          _firebaseActive = true;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Bills Stream Error: $e');
          _setupMockData();
        },
      );

      // 2. Inventory Sync
      _inventorySubscription = FirebaseService.instance.streamInventory().listen(
        (data) {
          _inventory = data;
          _firebaseActive = true;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Inventory Stream Error: $e');
        },
      );

      // 3. Customers Sync
      _customersSubscription = FirebaseService.instance.streamCustomers().listen(
        (data) {
          if (data.isNotEmpty) {
            _customers = data;
            _firebaseActive = true;
          } else {
            if (_initialUserCustomers.isNotEmpty) {
              _customers = List.from(_initialUserCustomers);
              _saveOfflineCustomers();
              FirebaseService.instance.batchCreateCustomers(_customers);
            } else {
              _customers = [];
              _saveOfflineCustomers();
            }
          }
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Customers Stream Error: $e');
          _loadOfflineCustomers();
        },
      );

      // 4. Payments Sync
      _paymentsSubscription = FirebaseService.instance.streamCustomerPayments().listen(
        (data) {
          if (data.isNotEmpty) {
            _customerPayments = data;
          }
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Payments Stream Error: $e');
        },
      );

      // 5. Vouchers Sync
      _vouchersSubscription = FirebaseService.instance.streamVouchers().listen(
        (data) {
          _vouchers = data;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Vouchers Stream Error: $e');
        },
      );

      // 6. Suppliers Sync
      _suppliersSubscription = FirebaseService.instance.streamSuppliers().listen(
        (data) {
          if (data.isNotEmpty) {
            _suppliers = data;
          }
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Suppliers Stream Error: $e');
        },
      );
    } catch (e) {
      debugPrint('Firebase setup exception: $e. Using local simulation.');
      _setupMockData();
    }
  }

  // Fallback to high-quality mockup dataset for local testing
  void _setupMockData() {
    _firebaseActive = false;
    _isLoading = false;
    _bills = [];
    _inventory = [];
    _customers = [];
    _customerPayments = [];
    _vouchers = [];
    _suppliers.clear();
    _loadOfflineCustomers();
  }

  Future<void> _loadOfflineCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customersJson = prefs.getString('offline_customers_json');
      if (_initialUserCustomers.isEmpty) {
        _customers = [];
        await prefs.remove('offline_customers_json');
        await prefs.remove('offline_payments_json');
      } else if (customersJson != null && customersJson.isNotEmpty) {
        final List dynamicList = jsonDecode(customersJson);
        if (dynamicList.isNotEmpty) {
          _customers = dynamicList.map((item) => CustomerModel.fromMap(Map<String, dynamic>.from(item), item['id'] ?? '')).toList();
        } else {
          _customers = List.from(_initialUserCustomers);
          _saveOfflineCustomers();
          if (_firebaseActive) {
            FirebaseService.instance.batchCreateCustomers(_customers);
          }
        }
      } else {
        _customers = List.from(_initialUserCustomers);
        _saveOfflineCustomers();
        if (_firebaseActive) {
          FirebaseService.instance.batchCreateCustomers(_customers);
        }
      }

      final paymentsJson = prefs.getString('offline_payments_json');
      if (paymentsJson != null && paymentsJson.isNotEmpty) {
        final List dynamicList = jsonDecode(paymentsJson);
        _customerPayments = dynamicList.map((item) => CustomerPaymentModel.fromMap(Map<String, dynamic>.from(item), item['id'] ?? '')).toList();
      } else {
        _customerPayments = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading offline customers: $e');
      _customers = [];
      notifyListeners();
    }
  }

  Future<void> _saveOfflineCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customersListMap = _customers.map((c) => {...c.toMap(), 'id': c.id}).toList();
      await prefs.setString('offline_customers_json', jsonEncode(customersListMap));

      final paymentsListMap = _customerPayments.map((p) => {...p.toMap(), 'id': p.id, 'createdAt': p.createdAt.toIso8601String()}).toList();
      await prefs.setString('offline_payments_json', jsonEncode(paymentsListMap));
    } catch (e) {
      debugPrint('Error saving offline customers: $e');
    }
  }

  // ================= METRICS CALCULATIONS =================
  // (existing metrics code continues...)

  // ================= BILL CANCEL & VOUCHERS API =================

  Future<void> cancelBill(BillModel bill) async {
    if (_firebaseActive) {
      await FirebaseService.instance.cancelBill(bill);
    } else {
      final idx = _bills.indexWhere((b) => b.billNumber == bill.billNumber);
      if (idx != -1) {
        _bills[idx] = _bills[idx].copyWith(status: 'CANCELLED');

        for (var item in bill.items) {
          final invIdx = _inventory.indexWhere((i) => i.medicineName == item.medicineName);
          if (invIdx != -1) {
            _inventory[invIdx] = _inventory[invIdx].copyWith(quantity: _inventory[invIdx].quantity + item.quantity);
          }
        }

        if (bill.paymentMode == 'Credit') {
          final custIdx = _customers.indexWhere((c) => c.name.toLowerCase() == bill.customerName.toLowerCase() || (bill.customerPhone.isNotEmpty && c.phone == bill.customerPhone));
          if (custIdx != -1) {
            final currentBal = _customers[custIdx].pendingBalance;
            _customers[custIdx] = _customers[custIdx].copyWith(pendingBalance: (currentBal - bill.netAmount).clamp(0.0, 999999.0));
          }
        }
        notifyListeners();
      }
    }
  }

  Future<void> addVoucher(VoucherModel voucher) async {
    if (_firebaseActive) {
      await FirebaseService.instance.createVoucher(voucher);
    } else {
      final newV = voucher.copyWith(id: 'mock_vouch_${DateTime.now().millisecondsSinceEpoch}');
      _vouchers.insert(0, newV);

      if (voucher.type == 'RECEIPT' && voucher.partyName.isNotEmpty) {
        final custIdx = _customers.indexWhere((c) => c.name.toLowerCase() == voucher.partyName.toLowerCase());
        if (custIdx != -1) {
          final currentBal = _customers[custIdx].pendingBalance;
          _customers[custIdx] = _customers[custIdx].copyWith(pendingBalance: (currentBal - voucher.amount).clamp(0.0, 999999.0));

          _customerPayments.insert(0, CustomerPaymentModel(
            id: 'mock_pay_${DateTime.now().millisecondsSinceEpoch}',
            customerId: _customers[custIdx].id ?? '',
            customerName: voucher.partyName,
            customerPhone: voucher.partyPhone,
            amountPaid: voucher.amount,
            createdAt: voucher.createdAt,
          ));
        }
      }
      notifyListeners();
    }
  }

  Future<void> deleteVoucher(dynamic voucherOrId) async {
    VoucherModel? voucher;
    String id = '';

    if (voucherOrId is VoucherModel) {
      voucher = voucherOrId;
      id = voucher.id ?? voucher.voucherNumber;
    } else if (voucherOrId is String) {
      id = voucherOrId;
      final idx = _vouchers.indexWhere((v) => v.id == id || v.voucherNumber == id);
      if (idx != -1) {
        voucher = _vouchers[idx];
      }
    }

    if (voucher != null) {
      final cleanPartyName = voucher.partyName.trim().toLowerCase();
      final cleanPhone = voucher.partyPhone.trim();

      if (voucher.type == 'PAYMENT') {
        final idx = _suppliers.indexWhere((s) =>
          s.name.trim().toLowerCase() == cleanPartyName ||
          (cleanPhone.isNotEmpty && s.contact.trim() == cleanPhone)
        );
        if (idx != -1) {
          final sup = _suppliers[idx];
          _suppliers[idx] = sup.copyWith(due: sup.due + voucher.amount);
        }
      } else if (voucher.type == 'PURCHASE') {
        final idx = _suppliers.indexWhere((s) =>
          s.name.trim().toLowerCase() == cleanPartyName ||
          (cleanPhone.isNotEmpty && s.contact.trim() == cleanPhone)
        );
        if (idx != -1) {
          final sup = _suppliers[idx];
          final newDue = (sup.due - voucher.amount).clamp(0.0, 9999999.0);
          _suppliers[idx] = sup.copyWith(due: newDue);
        }
      } else if (voucher.type == 'RECEIPT') {
        final idx = _customers.indexWhere((c) =>
          c.name.trim().toLowerCase() == cleanPartyName ||
          (cleanPhone.isNotEmpty && c.phone.trim() == cleanPhone)
        );
        if (idx != -1) {
          final cust = _customers[idx];
          _customers[idx] = cust.copyWith(pendingBalance: cust.pendingBalance + voucher.amount);
        }
      }

      _vouchers.removeWhere((v) =>
        (v.id != null && v.id == voucher!.id) ||
        (v.voucherNumber == voucher!.voucherNumber && v.createdAt == voucher.createdAt)
      );
    } else if (id.isNotEmpty) {
      _vouchers.removeWhere((v) => v.id == id || v.voucherNumber == id);
    }

    if (_firebaseActive && id.isNotEmpty) {
      await FirebaseService.instance.deleteVoucher(id);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _billsSubscription?.cancel();
    _inventorySubscription?.cancel();
    _customersSubscription?.cancel();
    _suppliersSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _vouchersSubscription?.cancel();
    super.dispose();
  }

  // ================= METRICS CALCULATIONS =================

  double get todaySales {
    final now = DateTime.now();
    return _bills
        .where((bill) => bill.createdAt.year == now.year && bill.createdAt.month == now.month && bill.createdAt.day == now.day)
        .fold(0.0, (sum, bill) => sum + bill.netAmount);
  }

  double get weeklySales {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _bills
        .where((bill) => bill.createdAt.isAfter(sevenDaysAgo))
        .fold(0.0, (sum, bill) => sum + bill.netAmount);
  }

  double get monthlySales {
    final now = DateTime.now();
    return _bills
        .where((bill) => bill.createdAt.year == now.year && bill.createdAt.month == now.month)
        .fold(0.0, (sum, bill) => sum + bill.netAmount);
  }

  List<InventoryModel> get lowStockMedicines {
    // Alert if quantity < 15
    return _inventory.where((item) => item.quantity < 15).toList();
  }

  List<InventoryModel> get nearExpiryMedicines {
    final now = DateTime.now();
    final threeMonthsFromNow = DateTime(now.year, now.month + 3, now.day);
    return _inventory.where((item) {
      try {
        final expParts = item.expiryDate.split('-');
        if (expParts.isEmpty) return false;
        final year = int.parse(expParts[0]);
        final month = expParts.length > 1 ? int.parse(expParts[1]) : 1;
        final expiry = DateTime(year, month);
        return expiry.isBefore(threeMonthsFromNow);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  double get totalOutstandingBalance {
    return _customers.fold(0.0, (sum, cust) => sum + cust.pendingBalance);
  }

  // Top selling products summary
  Map<String, int> get topSellingMedicines {
    Map<String, int> salesCount = {};
    for (var bill in _bills) {
      for (var item in bill.items) {
        salesCount[item.medicineName] = (salesCount[item.medicineName] ?? 0) + item.quantity;
      }
    }
    return salesCount;
  }

  // Add bill locally if Firebase is offline
  void addLocalBill(BillModel bill) {
    _bills.insert(0, bill);
    // Deduct stock locally
    for (var item in bill.items) {
      final index = _inventory.indexWhere((inv) => inv.medicineName == item.medicineName);
      if (index != -1) {
        final currentInv = _inventory[index];
        _inventory[index] = currentInv.copyWith(
          quantity: (currentInv.quantity - item.quantity).clamp(0, 999999),
        );
      }
    }
    // Update Customer Balance
    if (bill.customerName.isNotEmpty && bill.customerName.trim().toLowerCase() != 'walk-in customer') {
      final name = bill.customerName.trim();
      final phone = bill.customerPhone.trim();
      final index = _customers.indexWhere((cust) => 
        (phone.isNotEmpty && cust.phone == phone) ||
        (cust.name.toLowerCase() == name.toLowerCase())
      );

      if (bill.paymentMode == 'Credit') {
        if (index != -1) {
          _customers[index] = _customers[index].copyWith(
            pendingBalance: _customers[index].pendingBalance + bill.netAmount,
            phone: phone.isNotEmpty ? phone : _customers[index].phone,
          );
        } else {
          _customers.add(CustomerModel(
            id: 'mock_cust_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            phone: phone,
            pendingBalance: bill.netAmount,
          ));
        }
      } else {
        if (index == -1) {
          _customers.add(CustomerModel(
            id: 'mock_cust_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            phone: phone,
            pendingBalance: 0.0,
          ));
        } else if (phone.isNotEmpty && _customers[index].phone.isEmpty) {
          _customers[index] = _customers[index].copyWith(phone: phone);
        }
      }
    }
    notifyListeners();
  }

  Future<void> importCustomerList(List<CustomerModel> newCustomers) async {
    _customers.addAll(newCustomers);
    _saveOfflineCustomers();
    if (_firebaseActive) {
      await FirebaseService.instance.batchCreateCustomers(newCustomers);
    }
    notifyListeners();
  }

  // ================= CRUD API =================

  Future<void> addInventory(InventoryModel item) async {
    if (_firebaseActive) {
      await FirebaseService.instance.addInventoryItem(item);
    } else {
      // Mock update
      final idx = _inventory.indexWhere((inv) => inv.medicineName == item.medicineName && inv.batchNumber == item.batchNumber);
      if (idx != -1) {
        _inventory[idx] = _inventory[idx].copyWith(quantity: _inventory[idx].quantity + item.quantity);
      } else {
        _inventory.add(item.copyWith(id: 'mock_inv_${DateTime.now().millisecondsSinceEpoch}'));
      }
      notifyListeners();
    }
  }

  Future<void> updateStock(String id, int qty) async {
    if (_firebaseActive) {
      await FirebaseService.instance.updateInventoryQuantity(id, qty);
    } else {
      final idx = _inventory.indexWhere((inv) => inv.id == id);
      if (idx != -1) {
        _inventory[idx] = _inventory[idx].copyWith(quantity: qty);
        notifyListeners();
      }
    }
  }

  Future<void> deleteStock(String id) async {
    if (_firebaseActive) {
      await FirebaseService.instance.deleteInventoryItem(id);
    } else {
      _inventory.removeWhere((inv) => inv.id == id);
      notifyListeners();
    }
  }

  Future<bool> addCustomer(CustomerModel customer) async {
    final cleanName = customer.name.trim().toLowerCase();
    final cleanPhone = customer.phone.trim();

    // Check if customer with BOTH same name AND same phone number already exists
    final exists = _customers.any((c) {
      final sameName = cleanName.isNotEmpty && c.name.trim().toLowerCase() == cleanName;
      final samePhone = cleanPhone.isNotEmpty && c.phone.trim() == cleanPhone;
      return sameName && samePhone;
    });

    if (exists) {
      return false; // Customer already registered
    }

    if (_firebaseActive) {
      await FirebaseService.instance.createCustomer(customer);
    } else {
      _customers.add(customer.copyWith(id: 'mock_cust_${DateTime.now().millisecondsSinceEpoch}'));
      _saveOfflineCustomers();
      notifyListeners();
    }
    return true; // Added successfully
  }

  Future<void> batchAddCustomers(List<CustomerModel> customerList) async {
    if (_firebaseActive) {
      await FirebaseService.instance.batchCreateCustomers(customerList);
    } else {
      int count = 0;
      for (var c in customerList) {
        count++;
        _customers.add(c.copyWith(id: 'c_$count'));
      }
      await _saveOfflineCustomers();
      notifyListeners();
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    if (_firebaseActive) {
      await FirebaseService.instance.deleteCustomer(customerId);
    } else {
      _customers.removeWhere((c) => c.id == customerId);
      _saveOfflineCustomers();
      notifyListeners();
    }
  }

  Future<void> collectCustomerPayment(String customerId, double amount) async {
    if (_firebaseActive) {
      await FirebaseService.instance.clearCustomerBalance(customerId, amount);
    } else {
      final idx = _customers.indexWhere((cust) => cust.id == customerId);
      if (idx != -1) {
        final cust = _customers[idx];
        final currentBal = cust.pendingBalance;
        _customers[idx] = cust.copyWith(pendingBalance: (currentBal - amount));
        
        // Add offline payment history
        _customerPayments.insert(0, CustomerPaymentModel(
          id: 'mock_pay_${DateTime.now().millisecondsSinceEpoch}',
          customerId: customerId,
          customerName: cust.name,
          customerPhone: cust.phone,
          amountPaid: amount,
          createdAt: DateTime.now(),
        ));
        _saveOfflineCustomers();
      }
    }
  }

  Future<void> addCustomerCredit(CustomerModel customer, double amount, {String? note}) async {
    final billNumber = 'UDHAR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final bill = BillModel(
      billNumber: billNumber,
      customerName: customer.name,
      customerPhone: customer.phone,
      items: [
        BillItem(
          medicineName: note != null && note.trim().isNotEmpty ? note.trim() : 'Manual Udhar / Credit Entry',
          batchNumber: 'N/A',
          expiryDate: 'N/A',
          quantity: 1,
          mrp: amount,
          salePrice: amount,
          totalPrice: amount,
        )
      ],
      totalAmount: amount,
      discount: 0.0,
      netAmount: amount,
      createdAt: DateTime.now(),
      paymentMode: 'Credit',
    );

    if (_firebaseActive) {
      await FirebaseService.instance.createBill(bill);
    } else {
      addLocalBill(bill);
    }
  }

  // ================= SUPPLIER CRUD =================
  Future<bool> addSupplier(SupplierModel supplier) async {
    final cleanName = supplier.name.trim().toLowerCase();
    final cleanContact = supplier.contact.trim();

    final exists = _suppliers.any((s) =>
        s.name.trim().toLowerCase() == cleanName && s.contact.trim() == cleanContact);

    if (exists) {
      return false;
    }

    if (_firebaseActive) {
      await FirebaseService.instance.createSupplier(supplier);
    } else {
      _suppliers.add(supplier.copyWith(id: 'sup_${DateTime.now().millisecondsSinceEpoch}'));
      notifyListeners();
    }
    return true;
  }

  Future<void> importSupplierList(List<SupplierModel> newSuppliers) async {
    for (var sup in newSuppliers) {
      final cleanName = sup.name.trim().toLowerCase();
      final exists = _suppliers.any((s) => s.name.trim().toLowerCase() == cleanName);
      if (!exists) {
        _suppliers.add(sup.copyWith(id: sup.id ?? 'sup_${DateTime.now().millisecondsSinceEpoch}_${_suppliers.length}'));
      }
    }
    notifyListeners();
    try {
      await FirebaseService.instance.batchCreateSuppliers(newSuppliers);
    } catch (e) {
      debugPrint('Error batch creating suppliers in Firestore: $e');
    }
  }

  Future<void> deleteSupplier(String supplierId) async {
    if (_firebaseActive) {
      await FirebaseService.instance.deleteSupplier(supplierId);
    }
    _suppliers.removeWhere((s) => s.id == supplierId);
    notifyListeners();
  }

  Future<VoucherModel?> paySupplier(
    String supplierId,
    double amount, {
    String paymentMode = 'Cash',
    String referenceNumber = '',
    String remarks = '',
  }) async {
    final idx = _suppliers.indexWhere((sup) => sup.id == supplierId || sup.name.toLowerCase() == supplierId.toLowerCase());
    if (idx != -1) {
      final sup = _suppliers[idx];
      final newDue = (sup.due - amount).clamp(0.0, 9999999.0);
      _suppliers[idx] = sup.copyWith(due: newDue);

      final vNumber = referenceNumber.isNotEmpty ? referenceNumber : 'VCH-PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final voucher = VoucherModel(
        voucherNumber: vNumber,
        type: 'PAYMENT',
        partyName: sup.name,
        partyPhone: sup.contact,
        amount: amount,
        paymentMode: paymentMode,
        referenceNumber: referenceNumber,
        category: 'Supplier Payment',
        remarks: remarks,
        createdAt: DateTime.now(),
      );

      _vouchers.insert(0, voucher);
      if (_firebaseActive) {
        await FirebaseService.instance.createVoucher(voucher);
      }
      notifyListeners();
      return voucher;
    }
    return null;
  }

  Future<void> addSupplierDue(String supplierId, double amount) async {
    final idx = _suppliers.indexWhere((sup) => sup.id == supplierId || sup.name.toLowerCase() == supplierId.toLowerCase());
    if (idx != -1) {
      final sup = _suppliers[idx];
      _suppliers[idx] = sup.copyWith(due: sup.due + amount);
      notifyListeners();
    }
  }

  // ================= TRANSACTION DELETION METHODS =================

  Future<void> deleteBill(BillModel bill) async {
    final cleanCustName = bill.customerName.trim().toLowerCase();
    final cleanPhone = bill.customerPhone.trim();

    if (bill.paymentMode == 'Credit' || bill.netAmount > 0) {
      final idx = _customers.indexWhere((c) =>
        c.name.trim().toLowerCase() == cleanCustName ||
        (cleanPhone.isNotEmpty && c.phone.trim() == cleanPhone)
      );
      if (idx != -1) {
        final cust = _customers[idx];
        final newBal = (cust.pendingBalance - bill.netAmount).clamp(0.0, 9999999.0);
        _customers[idx] = cust.copyWith(pendingBalance: newBal);
      }
    }

    _bills.removeWhere((b) =>
      b.id == bill.id ||
      (b.billNumber == bill.billNumber && b.createdAt == bill.createdAt)
    );
    notifyListeners();
  }

  Future<void> deleteCustomerPayment(CustomerPaymentModel payment) async {
    final cleanCustName = payment.customerName.trim().toLowerCase();
    final cleanPhone = payment.customerPhone.trim();

    final idx = _customers.indexWhere((c) =>
      c.id == payment.customerId ||
      c.name.trim().toLowerCase() == cleanCustName ||
      (cleanPhone.isNotEmpty && c.phone.trim() == cleanPhone)
    );
    if (idx != -1) {
      final cust = _customers[idx];
      _customers[idx] = cust.copyWith(pendingBalance: cust.pendingBalance + payment.amountPaid);
    }

    _customerPayments.removeWhere((p) =>
      p.id == payment.id ||
      (p.customerId == payment.customerId && p.createdAt == payment.createdAt)
    );
    _saveOfflineCustomers();
    notifyListeners();
  }

  // ================= DATA RESET / WIPE ALL DATA API =================
  Future<void> clearAllData() async {
    try {
      await FirebaseService.instance.clearAllData();
    } catch (e) {
      debugPrint('Firebase wipe error: $e');
    }
    _bills.clear();
    _inventory.clear();
    _customers.clear();
    _customerPayments.clear();
    _vouchers.clear();
    _suppliers.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_customers_json');
      await prefs.remove('offline_payments_json');
    } catch (_) {}
    notifyListeners();
  }
}
