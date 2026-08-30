import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/bill_model.dart';
import '../data/models/inventory_model.dart';
import '../data/models/customer_model.dart';
import '../data/models/supplier_model.dart';
import '../data/models/voucher_model.dart';
import '../data/models/purchase_bill_model.dart';
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
  List<PurchaseBillModel> _purchaseBills = [];

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
  StreamSubscription? _purchaseBillsSubscription;

  bool _isLoading = true;
  bool _firebaseActive = false;

  // Getters
  List<BillModel> get bills => _bills;
  List<InventoryModel> get inventory => _inventory;
  List<CustomerModel> get customers => _customers;
  List<CustomerPaymentModel> get customerPayments => _customerPayments;
  List<VoucherModel> get vouchers => _vouchers;
  List<SupplierModel> get suppliers => _suppliers;
  List<PurchaseBillModel> get purchaseBills => _purchaseBills;
  bool get isLoading => _isLoading;
  bool get firebaseActive => _firebaseActive;

  String get pharmacyName => _pharmacyName;
  String get storeAddress => _storeAddress;
  String get gstin => _gstin;

  DashboardProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadOfflineCustomers();
    try {
      await FirebaseService.instance.ensureAuthenticated();
    } catch (e) {
      debugPrint('Pre-sync auth check error: $e');
    }
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
          _isLoading = false;
          notifyListeners();
        },
      );

      // 2. Inventory Sync
      _inventorySubscription = FirebaseService.instance.streamInventory().listen(
        (data) {
          _inventory = data;
          _firebaseActive = true;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Inventory Stream Error: $e');
          _isLoading = false;
          notifyListeners();
        },
      );

      // 3. Customers Sync
      _customersSubscription = FirebaseService.instance.streamCustomers().listen(
        (data) {
          _firebaseActive = true;
          _customers = data;
          _isLoading = false;
          _saveOfflineCustomers();
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Customers Stream Error: $e');
          _isLoading = false;
          _loadOfflineCustomers();
        },
      );

      // 4. Payments Sync
      _paymentsSubscription = FirebaseService.instance.streamCustomerPayments().listen(
        (data) {
          _customerPayments = data;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Payments Stream Error: $e');
          _isLoading = false;
        },
      );

      // 5. Vouchers Sync
      _vouchersSubscription = FirebaseService.instance.streamVouchers().listen(
        (data) {
          _vouchers = data;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Vouchers Stream Error: $e');
          _isLoading = false;
        },
      );

      // 6. Suppliers Sync
      _suppliersSubscription = FirebaseService.instance.streamSuppliers().listen(
        (data) {
          _suppliers = data;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Suppliers Stream Error: $e');
          _isLoading = false;
        },
      );

      // 7. Purchase Bills Sync
      _purchaseBillsSubscription = FirebaseService.instance.streamPurchaseBills().listen(
        (data) {
          _purchaseBills = data;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firebase Purchase Bills Stream Error: $e');
          _isLoading = false;
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
    _loadOfflineCustomers();
  }

  Future<void> _loadOfflineCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customersJson = prefs.getString('offline_customers_json');
      if (customersJson != null && customersJson.isNotEmpty) {
        final List dynamicList = jsonDecode(customersJson);
        if (dynamicList.isNotEmpty) {
          _customers = dynamicList.map((item) => CustomerModel.fromMap(Map<String, dynamic>.from(item), item['id'] ?? '')).toList();
        } else if (_initialUserCustomers.isNotEmpty) {
          _customers = List.from(_initialUserCustomers);
          _saveOfflineCustomers();
        }
      } else if (_initialUserCustomers.isNotEmpty) {
        _customers = List.from(_initialUserCustomers);
        _saveOfflineCustomers();
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

  Future<void> addPurchaseBill(PurchaseBillModel bill) async {
    if (_firebaseActive) {
      await FirebaseService.instance.createPurchaseBill(bill);
    } else {
      _purchaseBills.insert(0, bill);
      notifyListeners();
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
          final updatedDue = sup.due + voucher.amount;
          _suppliers[idx] = sup.copyWith(due: updatedDue);
          if (_firebaseActive) {
            FirebaseService.instance.updateSupplierDue(sup.id ?? sup.name, updatedDue);
          }
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
          if (_firebaseActive) {
            FirebaseService.instance.updateSupplierDue(sup.id ?? sup.name, newDue);
          }
        }
      } else if (voucher.type == 'RECEIPT') {
        final idx = _customers.indexWhere((c) =>
          c.name.trim().toLowerCase() == cleanPartyName ||
          (cleanPhone.isNotEmpty && c.phone.trim() == cleanPhone)
        );
        if (idx != -1) {
          final cust = _customers[idx];
          final updatedBal = cust.pendingBalance + voucher.amount;
          _customers[idx] = cust.copyWith(pendingBalance: updatedBal);
          if (_firebaseActive) {
            FirebaseService.instance.updateCustomerBalance(cust.id ?? cust.name, updatedBal);
          }
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
    _purchaseBillsSubscription?.cancel();
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

  double getCustomerPendingBalance(CustomerModel cust) {
    final cName = cust.name.trim().toLowerCase();
    final cPhone = cust.phone.trim();

    final cBills = _bills.where((b) {
      if (b.paymentMode != 'Credit') return false;
      final bName = b.customerName.trim().toLowerCase();
      final bPhone = b.customerPhone.trim();
      return (cPhone.isNotEmpty && bPhone == cPhone) ||
             (bName.isNotEmpty && bName == cName);
    }).toList();

    final cPays = _customerPayments.where((p) {
      final pName = p.customerName.trim().toLowerCase();
      final pPhone = p.customerPhone.trim();
      return (cust.id != null && p.customerId == cust.id) ||
             (cPhone.isNotEmpty && pPhone == cPhone) ||
             (pName.isNotEmpty && pName == cName);
    }).toList();

    if (cBills.isEmpty && cPays.isEmpty) {
      return cust.pendingBalance;
    }

    final creditBillsTotal = cBills.fold(0.0, (sum, b) => sum + b.netAmount);
    final paymentsTotal = cPays.fold(0.0, (sum, p) => sum + p.amountPaid);

    final calculated = creditBillsTotal - paymentsTotal;
    return calculated > 0 ? calculated : 0.0;
  }

  double getSupplierPendingDue(SupplierModel sup) {
    final sName = sup.name.trim().toLowerCase();
    final sPhone = sup.contact.trim();

    final sVouchers = _vouchers.where((v) {
      final vName = v.partyName.trim().toLowerCase();
      final vPhone = v.partyPhone.trim();
      return (sPhone.isNotEmpty && vPhone == sPhone) ||
             (sName.isNotEmpty && vName == sName);
    }).toList();

    if (sVouchers.isEmpty) {
      return sup.due;
    }

    final purchasesTotal = sVouchers.where((v) => v.type == 'PURCHASE').fold(0.0, (sum, v) => sum + v.amount);
    final paymentsTotal = sVouchers.where((v) => v.type == 'PAYMENT').fold(0.0, (sum, v) => sum + v.amount);

    final calculated = purchasesTotal - paymentsTotal;
    return calculated > 0 ? calculated : 0.0;
  }

  double get totalOutstandingBalance {
    return _customers.fold(0.0, (sum, cust) => sum + getCustomerPendingBalance(cust));
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

    final localId = customer.id ?? 'cust_${DateTime.now().millisecondsSinceEpoch}';
    final newCust = customer.copyWith(id: localId);
    _customers.add(newCust);
    _saveOfflineCustomers();
    notifyListeners();

    if (_firebaseActive) {
      FirebaseService.instance.createCustomer(customer).then((docId) {
        final idx = _customers.indexWhere((c) => c.id == localId);
        if (idx != -1) {
          _customers[idx] = _customers[idx].copyWith(id: docId);
          _saveOfflineCustomers();
          notifyListeners();
        }
      }).catchError((e) {
        debugPrint('Firebase createCustomer error: $e');
      });
    }

    return true; // Added successfully
  }

  Future<void> batchAddCustomers(List<CustomerModel> customerList) async {
    _customers.addAll(customerList);
    await _saveOfflineCustomers();
    notifyListeners();

    if (_firebaseActive) {
      FirebaseService.instance.batchCreateCustomers(customerList).catchError((e) {
        debugPrint('Error batch creating customers in Firebase: $e');
      });
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    final custIdx = _customers.indexWhere((c) => c.id == customerId);
    if (custIdx != -1) {
      final custName = _customers[custIdx].name.trim().toLowerCase();
      final custPhone = _customers[custIdx].phone.trim();

      _customers.removeAt(custIdx);

      // Clean up linked payments & vouchers for this customer
      _customerPayments.removeWhere((p) =>
        p.customerId == customerId ||
        (custName.isNotEmpty && p.customerName.trim().toLowerCase() == custName) ||
        (custPhone.isNotEmpty && p.customerPhone.trim() == custPhone)
      );
      _vouchers.removeWhere((v) =>
        (custName.isNotEmpty && v.partyName.trim().toLowerCase() == custName) ||
        (custPhone.isNotEmpty && v.partyPhone.trim() == custPhone)
      );
    } else {
      _customers.removeWhere((c) => c.id == customerId);
    }

    await _saveOfflineCustomers();
    notifyListeners();

    if (_firebaseActive) {
      FirebaseService.instance.deleteCustomer(customerId).catchError((e) {
        debugPrint('Error deleting customer from Firebase: $e');
      });
    }
  }

  Future<void> collectCustomerPayment(
    String customerId,
    double amount, {
    String paymentMode = 'Cash',
    String referenceNumber = '',
    String remarks = '',
  }) async {
    final cleanId = customerId.trim().toLowerCase();
    final idx = _customers.indexWhere((cust) =>
        (cust.id != null && cust.id!.toLowerCase() == cleanId) ||
        cust.name.trim().toLowerCase() == cleanId);

    if (idx != -1) {
      final cust = _customers[idx];
      final currentBal = cust.pendingBalance;
      final newBal = (currentBal - amount).clamp(0.0, 9999999.0);
      _customers[idx] = cust.copyWith(pendingBalance: newBal);
      _saveOfflineCustomers();
      notifyListeners();
    }

    if (_firebaseActive) {
      FirebaseService.instance.clearCustomerBalance(
        customerId,
        amount,
        paymentMode: paymentMode,
        referenceNumber: referenceNumber,
        remarks: remarks,
      ).catchError((e) {
        debugPrint('Error syncing customer payment to Firebase: $e');
        return false;
      });
    } else {
      // Offline-only: add to local payments list
      final cust = idx != -1 ? _customers[idx] : null;
      if (cust != null) {
        final now = DateTime.now();
        _customerPayments.insert(
          0,
          CustomerPaymentModel(
            id: 'local_pay_${now.millisecondsSinceEpoch}',
            customerId: cust.id ?? customerId,
            customerName: cust.name,
            customerPhone: cust.phone,
            amountPaid: amount,
            createdAt: now,
          ),
        );
        notifyListeners();
      }
    }
  }

  Future<void> addCustomerSale(
    String customerId,
    double totalAmount, {
    double amountPaidNow = 0.0,
    String referenceNumber = '',
    String remarks = '',
  }) async {
    final cleanId = customerId.trim().toLowerCase();
    final idx = _customers.indexWhere((cust) =>
        (cust.id != null && cust.id!.toLowerCase() == cleanId) ||
        cust.name.trim().toLowerCase() == cleanId);

    if (idx != -1) {
      final cust = _customers[idx];
      final currentBal = cust.pendingBalance;
      final netDue = (totalAmount - amountPaidNow).clamp(0.0, 9999999.0);
      final newBal = currentBal + netDue;
      _customers[idx] = cust.copyWith(pendingBalance: newBal);

      final now = DateTime.now();
      final refNo = referenceNumber.trim().isNotEmpty
          ? referenceNumber.trim()
          : 'SAL-${now.millisecondsSinceEpoch.toString().substring(7)}';

      final bill = BillModel(
        billNumber: refNo,
        customerName: cust.name,
        customerPhone: cust.phone,
        items: [
          BillItem(
            medicineName: remarks.isNotEmpty ? remarks : 'Manual Sale / Udhar Entry',
            batchNumber: 'N/A',
            expiryDate: 'N/A',
            quantity: 1,
            mrp: totalAmount,
            salePrice: totalAmount,
            totalPrice: totalAmount,
          ),
        ],
        totalAmount: totalAmount,
        discount: 0.0,
        gstAmount: 0.0,
        netAmount: totalAmount,
        paymentMode: 'Credit',
        createdAt: now,
      );

      if (_firebaseActive) {
        // Online: let Firebase stream handle the bill insert. Locally only update customer balance.
        _customers[idx] = cust.copyWith(pendingBalance: newBal);
        _saveOfflineCustomers();
        notifyListeners();
        FirebaseService.instance.createBill(bill).catchError((e) {
          debugPrint('Error syncing customer sale to Firebase: $e');
          return <String, dynamic>{};
        });
      } else {
        // Offline: insert locally
        addLocalBill(bill);
      }

      if (amountPaidNow > 0) {
        await collectCustomerPayment(
          cust.id ?? customerId,
          amountPaidNow,
          paymentMode: 'Cash',
          referenceNumber: refNo,
          remarks: 'Paid against Sale #$refNo',
        );
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
      // When online: update customer balance locally, let Firebase stream handle bill entry
      final idx = _customers.indexWhere((c) =>
          (customer.id != null && c.id == customer.id) ||
          (customer.phone.trim().isNotEmpty && c.phone.trim() == customer.phone.trim()) ||
          c.name.trim().toLowerCase() == customer.name.trim().toLowerCase());
      if (idx != -1) {
        _customers[idx] = _customers[idx].copyWith(
          pendingBalance: _customers[idx].pendingBalance + amount,
        );
        _saveOfflineCustomers();
        notifyListeners();
      }
      FirebaseService.instance.createBill(bill).catchError((e) {
        debugPrint('Error syncing credit bill to Firebase: $e');
        return <String, dynamic>{};
      });
    } else {
      // Offline-only: insert locally
      addLocalBill(bill);
    }
  }

  Future<bool> addSupplier(SupplierModel supplier) async {
    final cleanName = supplier.name.trim().toLowerCase();
    final cleanContact = supplier.contact.trim();

    final exists = _suppliers.any((s) =>
        s.name.trim().toLowerCase() == cleanName && (cleanContact.isEmpty || s.contact.trim() == cleanContact));

    if (exists) {
      return false;
    }

    final localId = supplier.id ?? 'sup_${DateTime.now().millisecondsSinceEpoch}';
    final newSup = supplier.copyWith(id: localId);
    _suppliers.add(newSup);
    notifyListeners();

    if (_firebaseActive) {
      FirebaseService.instance.createSupplier(supplier).then((docId) {
        final idx = _suppliers.indexWhere((s) => s.id == localId);
        if (idx != -1) {
          _suppliers[idx] = _suppliers[idx].copyWith(id: docId);
          notifyListeners();
        }
      }).catchError((e) {
        debugPrint('Firebase createSupplier error: $e');
      });
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
    if (_firebaseActive) {
      FirebaseService.instance.batchCreateSuppliers(newSuppliers).catchError((e) {
        debugPrint('Error batch creating suppliers in Firestore: $e');
      });
    }
  }

  Future<void> deleteSupplier(String supplierId) async {
    final supIdx = _suppliers.indexWhere((s) => s.id == supplierId);
    if (supIdx != -1) {
      final supName = _suppliers[supIdx].name.trim().toLowerCase();
      final supPhone = _suppliers[supIdx].contact.trim();

      _suppliers.removeAt(supIdx);

      // Clean up linked vouchers for this supplier
      _vouchers.removeWhere((v) =>
        (supName.isNotEmpty && v.partyName.trim().toLowerCase() == supName) ||
        (supPhone.isNotEmpty && v.partyPhone.trim() == supPhone)
      );
    } else {
      _suppliers.removeWhere((s) => s.id == supplierId);
    }

    notifyListeners();

    if (_firebaseActive) {
      FirebaseService.instance.deleteSupplier(supplierId).catchError((e) {
        debugPrint('Error deleting supplier from Firebase: $e');
      });
    }
  }

  Future<VoucherModel?> paySupplier(
    String supplierId,
    double amount, {
    String paymentMode = 'Cash',
    String referenceNumber = '',
    String remarks = '',
  }) async {
    final cleanId = supplierId.trim().toLowerCase();
    final idx = _suppliers.indexWhere((sup) =>
        (sup.id != null && sup.id!.toLowerCase() == cleanId) ||
        sup.name.trim().toLowerCase() == cleanId);
    if (idx != -1) {
      final sup = _suppliers[idx];
      final vNumber = referenceNumber.trim().isNotEmpty
          ? referenceNumber.trim()
          : 'VCH-PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Deduplication Guard: prevent double save within 15 seconds
      final isDuplicate = _vouchers.any((v) =>
        v.type == 'PAYMENT' &&
        v.voucherNumber.trim() == vNumber.trim() &&
        v.partyName.trim().toLowerCase() == sup.name.trim().toLowerCase() &&
        DateTime.now().difference(v.createdAt).inSeconds < 15
      );
      if (isDuplicate) {
        debugPrint('Duplicate supplier payment blocked for $vNumber');
        return _vouchers.firstWhere((v) => v.voucherNumber.trim() == vNumber.trim());
      }

      final newDue = (sup.due - amount).clamp(0.0, 9999999.0);
      _suppliers[idx] = sup.copyWith(due: newDue);

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
      notifyListeners();

      if (_firebaseActive) {
        FirebaseService.instance.createVoucher(voucher).catchError((e) {
          debugPrint('Error syncing payment voucher to Firebase: $e');
          return '';
        });
      }
      return voucher;
    }
    return null;
  }

  Future<VoucherModel?> addSupplierPurchase(
    String supplierId,
    double amount, {
    String billNumber = '',
    String remarks = '',
    String paymentMode = 'Credit',
    String partyPhone = '',
  }) async {
    final cleanId = supplierId.trim().toLowerCase();
    final idx = _suppliers.indexWhere((sup) =>
        (sup.id != null && sup.id!.toLowerCase() == cleanId) ||
        sup.name.trim().toLowerCase() == cleanId);
    if (idx != -1) {
      final sup = _suppliers[idx];

      final vNumber = billNumber.trim().isNotEmpty
          ? billNumber.trim()
          : 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Deduplication Guard: prevent double purchase bill save within 15 seconds
      final isDuplicate = _vouchers.any((v) =>
        v.type == 'PURCHASE' &&
        v.voucherNumber.trim() == vNumber.trim() &&
        v.partyName.trim().toLowerCase() == sup.name.trim().toLowerCase() &&
        DateTime.now().difference(v.createdAt).inSeconds < 15
      );
      if (isDuplicate) {
        debugPrint('Duplicate purchase bill creation blocked for $vNumber');
        return _vouchers.firstWhere((v) => v.voucherNumber.trim() == vNumber.trim());
      }

      _suppliers[idx] = sup.copyWith(due: sup.due + amount);

      final voucher = VoucherModel(
        voucherNumber: vNumber,
        type: 'PURCHASE',
        partyName: sup.name,
        partyPhone: partyPhone.isNotEmpty ? partyPhone : sup.contact,
        amount: amount,
        paymentMode: paymentMode,
        referenceNumber: billNumber,
        category: 'Stock Purchase',
        remarks: remarks.isNotEmpty ? remarks : 'Stock Bill Added',
        createdAt: DateTime.now(),
      );

      _vouchers.insert(0, voucher);
      notifyListeners();

      if (_firebaseActive) {
        FirebaseService.instance.createVoucher(voucher).catchError((e) {
          debugPrint('Error syncing purchase voucher to Firebase: $e');
          return '';
        });
      }
      return voucher;
    }
    return null;
  }

  Future<void> addSupplierDue(String supplierId, double amount) async {
    await addSupplierPurchase(supplierId, amount);
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
        if (_firebaseActive) {
          FirebaseService.instance.updateCustomerBalance(cust.id ?? cust.name, newBal);
        }
      }
    }

    _bills.removeWhere((b) =>
      b.id == bill.id ||
      (b.billNumber == bill.billNumber && b.createdAt == bill.createdAt)
    );
    if (_firebaseActive && bill.id != null && bill.id!.isNotEmpty) {
      FirebaseService.instance.deleteBill(bill.id!);
    }
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
      final newBal = cust.pendingBalance + payment.amountPaid;
      _customers[idx] = cust.copyWith(pendingBalance: newBal);
      if (_firebaseActive) {
        FirebaseService.instance.updateCustomerBalance(cust.id ?? cust.name, newBal);
      }
    }

    _customerPayments.removeWhere((p) =>
      p.id == payment.id ||
      (p.customerId == payment.customerId && p.createdAt == payment.createdAt)
    );
    if (_firebaseActive && payment.id != null && payment.id!.isNotEmpty) {
      FirebaseService.instance.deleteCustomerPayment(payment.id!);
    }
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
