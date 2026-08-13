import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bill_model.dart';
import '../models/inventory_model.dart';
import '../models/customer_model.dart';
import '../models/supplier_model.dart';
import '../models/voucher_model.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Static store ID for demo purposes. Can be dynamically updated upon login.
  String storeId = 'health_plus_pharmacy_demo';

  FirebaseService._init() {
    // Enable offline persistence for Firestore if available on platform
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore persistence settings error: $e');
    }
  }

  /// Ensures user is signed in to Firebase Auth before reading/writing Firestore
  Future<User?> ensureAuthenticated() async {
    try {
      if (_auth.currentUser == null) {
        final credential = await _auth.signInAnonymously();
        debugPrint('Firebase Auth: Authenticated anonymously as ${credential.user?.uid}');
        return credential.user;
      }
      return _auth.currentUser;
    } catch (e) {
      debugPrint('Firebase Auth error during anonymous sign in: $e');
      return null;
    }
  }

  // Helper collection references
  CollectionReference get _storeRef => _firestore.collection('stores');
  CollectionReference get _billsRef => _storeRef.doc(storeId).collection('bills');
  CollectionReference get _inventoryRef => _storeRef.doc(storeId).collection('inventory');
  CollectionReference get _customersRef => _storeRef.doc(storeId).collection('customers');
  CollectionReference get _suppliersRef => _storeRef.doc(storeId).collection('suppliers');

  // ================= BILLS API =================

  // Stream bills in real-time ordered by creation date descending
  Stream<List<BillModel>> streamBills() {
    return _billsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BillModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Create a new bill and push it to Firestore
  Future<Map<String, dynamic>> createBill(BillModel bill) async {
    final docRef = _billsRef.doc();
    final newBill = bill.copyWith(id: docRef.id);
    await docRef.set(newBill.toMap());

    List<String> warnings = [];

    // Update customer credit balance & create customer record if name is provided
    if (bill.customerName.isNotEmpty && bill.customerName.trim().toLowerCase() != 'walk-in customer') {
      final custSuccess = await _updateCustomerCreditBalance(bill.customerName, bill.customerPhone, bill.netAmount, bill.paymentMode);
      if (!custSuccess) {
        warnings.add('Customer balance update could not be processed.');
      }
    }

    // Deduct stock for items in the bill using batch matching & transactions
    for (var item in bill.items) {
      final stockSuccess = await _deductInventoryStock(item.medicineName, item.batchNumber, item.quantity);
      if (!stockSuccess) {
        warnings.add('Stock deduction for "${item.medicineName}" (Batch: ${item.batchNumber}) could not be completed.');
      }
    }

    return {
      'id': docRef.id,
      'warnings': warnings,
    };
  }

  // Internal helper to deduct stock from inventory with batch matching & atomic transactions
  Future<bool> _deductInventoryStock(String name, String batchNumber, int qtyToDeduct) async {
    try {
      final cleanName = name.trim();
      final cleanBatch = batchNumber.trim();

      Query query = _inventoryRef.where('medicineName', isEqualTo: cleanName);
      if (cleanBatch.isNotEmpty) {
        query = query.where('batchNumber', isEqualTo: cleanBatch);
      }

      final snap = await query.limit(1).get();
      if (snap.docs.isEmpty) {
        // Fallback to name-only match if exact batch doc is missing
        final fallbackSnap = await _inventoryRef.where('medicineName', isEqualTo: cleanName).limit(1).get();
        if (fallbackSnap.docs.isEmpty) return false;
        final docRef = fallbackSnap.docs.first.reference;
        return await _runDeductTransaction(docRef, qtyToDeduct);
      } else {
        final docRef = snap.docs.first.reference;
        return await _runDeductTransaction(docRef, qtyToDeduct);
      }
    } catch (e) {
      debugPrint('Error updating inventory stock for $name (Batch: $batchNumber): $e');
      return false;
    }
  }

  Future<bool> _runDeductTransaction(DocumentReference docRef, int qtyToDeduct) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        final data = snapshot.data() as Map<String, dynamic>;
        final currentQty = (data['quantity'] as num?)?.toInt() ?? 0;
        final newQty = (currentQty - qtyToDeduct).clamp(0, 9999999);
        transaction.update(docRef, {'quantity': newQty});
      });
      return true;
    } catch (e) {
      debugPrint('Transaction deduct stock failed: $e');
      return false;
    }
  }

  // Internal helper to update customer credit balance & auto-register customer with normalized name matching & transactions
  Future<bool> _updateCustomerCreditBalance(String name, String phone, double amount, String paymentMode) async {
    try {
      final cleanName = name.trim();
      final cleanPhone = phone.trim();
      final normalizedName = cleanName.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      final isCredit = paymentMode == 'Credit';

      QuerySnapshot query;
      if (cleanPhone.isNotEmpty) {
        query = await _customersRef.where('phone', isEqualTo: cleanPhone).limit(1).get();
      } else {
        query = await _customersRef.where('searchName', isEqualTo: normalizedName).limit(1).get();
      }

      if (query.docs.isEmpty && cleanPhone.isNotEmpty) {
        query = await _customersRef.where('searchName', isEqualTo: normalizedName).limit(1).get();
      }

      if (query.docs.isEmpty) {
        // Legacy fallback query by raw name
        query = await _customersRef.where('name', isEqualTo: cleanName).limit(1).get();
      }

      if (query.docs.isNotEmpty) {
        final docRef = query.docs.first.reference;
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) return;
          final data = snapshot.data() as Map<String, dynamic>;
          final currentBalance = (data['pendingBalance'] as num?)?.toDouble() ?? 0.0;
          final updateData = <String, dynamic>{
            'searchName': normalizedName,
            if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
          };
          if (isCredit) {
            updateData['pendingBalance'] = (currentBalance + amount).toDouble();
          }
          transaction.update(docRef, updateData);
        });
        return true;
      } else {
        // Customer doesn't exist yet, automatically create customer with searchName
        final docRef = _customersRef.doc();
        final newCust = CustomerModel(
          id: docRef.id,
          name: cleanName,
          phone: cleanPhone,
          pendingBalance: isCredit ? amount : 0.0,
        );
        final mapData = newCust.toMap();
        mapData['searchName'] = normalizedName;
        await docRef.set(mapData);
        return true;
      }
    } catch (e) {
      debugPrint('Error updating customer credit balance: $e');
      return false;
    }
  }

  // ================= INVENTORY API =================

  // Stream entire inventory list
  Stream<List<InventoryModel>> streamInventory() {
    return _inventoryRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return InventoryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Add a new inventory item or update if it exists
  Future<String> addInventoryItem(InventoryModel item) async {
    // Check if item with same medicineName and batchNumber exists
    final query = await _inventoryRef
        .where('medicineName', isEqualTo: item.medicineName)
        .where('batchNumber', isEqualTo: item.batchNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final existingQty = (doc.data() as Map<String, dynamic>)['quantity'] ?? 0;
      final updatedItem = item.copyWith(
        id: doc.id,
        quantity: existingQty + item.quantity,
      );
      await doc.reference.update(updatedItem.toMap());
      return doc.id;
    } else {
      final docRef = _inventoryRef.doc();
      final newItem = item.copyWith(id: docRef.id);
      await docRef.set(newItem.toMap());
      return docRef.id;
    }
  }

  // Update quantity of an inventory item directly
  Future<void> updateInventoryQuantity(String docId, int newQuantity) async {
    await _inventoryRef.doc(docId).update({'quantity': newQuantity});
  }

  // Delete inventory item
  Future<void> deleteInventoryItem(String docId) async {
    await _inventoryRef.doc(docId).delete();
  }

  // ================= CUSTOMERS API =================

  // Stream customer database
  Stream<List<CustomerModel>> streamCustomers() {
    return _customersRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return CustomerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Create a new customer
  Future<String> createCustomer(CustomerModel customer) async {
    final docRef = _customersRef.doc();
    final newCustomer = customer.copyWith(id: docRef.id);
    await docRef.set(newCustomer.toMap());
    return docRef.id;
  }

  // Batch insert multiple customers to Firestore safely
  Future<void> batchCreateCustomers(List<CustomerModel> customers) async {
    final chunks = <List<CustomerModel>>[];
    for (var i = 0; i < customers.length; i += 400) {
      chunks.add(customers.sublist(i, i + 400 > customers.length ? customers.length : i + 400));
    }

    for (var chunk in chunks) {
      final batch = _firestore.batch();
      for (var c in chunk) {
        final docRef = _customersRef.doc();
        batch.set(docRef, c.copyWith(id: docRef.id).toMap());
      }
      await batch.commit();
    }
  }

  // Delete a customer profile
  Future<void> deleteCustomer(String customerId) async {
    await _customersRef.doc(customerId).delete();
  }

  // ================= SUPPLIERS API =================

  Stream<List<SupplierModel>> streamSuppliers() {
    return _suppliersRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return SupplierModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<String> createSupplier(SupplierModel supplier) async {
    final docRef = _suppliersRef.doc();
    final newSupplier = supplier.copyWith(id: docRef.id);
    await docRef.set(newSupplier.toMap());
    return docRef.id;
  }

  Future<void> batchCreateSuppliers(List<SupplierModel> suppliers) async {
    final chunks = <List<SupplierModel>>[];
    for (var i = 0; i < suppliers.length; i += 400) {
      chunks.add(suppliers.sublist(i, i + 400 > suppliers.length ? suppliers.length : i + 400));
    }

    for (var chunk in chunks) {
      final batch = _firestore.batch();
      for (var s in chunk) {
        final docRef = _suppliersRef.doc();
        batch.set(docRef, s.copyWith(id: docRef.id).toMap());
      }
      await batch.commit();
    }
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _suppliersRef.doc(supplierId).delete();
  }

  CollectionReference get _paymentsRef => _storeRef.doc(storeId).collection('customer_payments');

  // Clear customer balance (payment received) using atomic transaction
  Future<bool> clearCustomerBalance(String customerId, double paymentAmount) async {
    try {
      final docRef = _customersRef.doc(customerId);
      String custName = '';
      String custPhone = '';

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Customer not found');
        final data = snapshot.data() as Map<String, dynamic>;
        custName = data['name'] ?? '';
        custPhone = data['phone'] ?? '';
        final currentBalance = (data['pendingBalance'] as num?)?.toDouble() ?? 0.0;
        final newBalance = (currentBalance - paymentAmount).clamp(0.0, 9999999.0);
        transaction.update(docRef, {'pendingBalance': newBalance});
      });

      // Record this payment in the history!
      await recordCustomerPayment(CustomerPaymentModel(
        customerId: customerId,
        customerName: custName,
        customerPhone: custPhone,
        amountPaid: paymentAmount,
        createdAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      debugPrint('Error clearing customer balance transaction: $e');
      return false;
    }
  }

  // Add customer credit (manual Udhar added) using atomic transaction
  Future<bool> addCustomerCredit(String customerId, double creditAmount) async {
    try {
      final docRef = _customersRef.doc(customerId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Customer not found');
        final data = snapshot.data() as Map<String, dynamic>;
        final currentBalance = (data['pendingBalance'] as num?)?.toDouble() ?? 0.0;
        transaction.update(docRef, {'pendingBalance': currentBalance + creditAmount});
      });
      return true;
    } catch (e) {
      debugPrint('Error adding customer credit transaction: $e');
      return false;
    }
  }

  // Record a payment transaction
  Future<String> recordCustomerPayment(CustomerPaymentModel payment) async {
    final docRef = _paymentsRef.doc();
    final newPayment = payment.copyWith(id: docRef.id);
    await docRef.set(newPayment.toMap());
    return docRef.id;
  }

  // Stream payments
  Stream<List<CustomerPaymentModel>> streamCustomerPayments() {
    return _paymentsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CustomerPaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // ================= VOUCHERS API =================

  CollectionReference get _vouchersRef => _storeRef.doc(storeId).collection('vouchers');

  Stream<List<VoucherModel>> streamVouchers() {
    return _vouchersRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VoucherModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<String> createVoucher(VoucherModel voucher) async {
    final docRef = _vouchersRef.doc();
    final newVoucher = voucher.copyWith(id: docRef.id);
    await docRef.set(newVoucher.toMap());

    // If it's a RECEIPT voucher for a customer, update customer balance with transaction
    if (voucher.type == 'RECEIPT' && voucher.partyName.isNotEmpty) {
      try {
        final normalized = voucher.partyName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        final query = await _customersRef.where('searchName', isEqualTo: normalized).limit(1).get();
        final docs = query.docs.isNotEmpty ? query.docs : (await _customersRef.where('name', isEqualTo: voucher.partyName.trim()).limit(1).get()).docs;

        if (docs.isNotEmpty) {
          final custDocRef = docs.first.reference;
          await _firestore.runTransaction((transaction) async {
            final snap = await transaction.get(custDocRef);
            if (!snap.exists) return;
            final data = snap.data() as Map<String, dynamic>;
            final currentBal = (data['pendingBalance'] as num?)?.toDouble() ?? 0.0;
            final newBal = (currentBal - voucher.amount).clamp(0.0, 9999999.0);
            transaction.update(custDocRef, {'pendingBalance': newBal});
          });

          await recordCustomerPayment(CustomerPaymentModel(
            customerId: custDocRef.id,
            customerName: voucher.partyName,
            customerPhone: voucher.partyPhone,
            amountPaid: voucher.amount,
            createdAt: voucher.createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Error auto updating customer balance from voucher: $e');
      }
    }
    return docRef.id;
  }

  Future<void> deleteVoucher(String voucherId) async {
    await _vouchersRef.doc(voucherId).delete();
  }

  // ================= BILL CANCEL / MODIFY API =================

  Future<bool> cancelBill(BillModel bill) async {
    try {
      if (bill.id != null && bill.id!.isNotEmpty) {
        await _billsRef.doc(bill.id).update({'status': 'CANCELLED'});

        // Restock items using batch matching & atomic transactions
        for (var item in bill.items) {
          await _restockInventory(item.medicineName, item.batchNumber, item.quantity);
        }

        // Revert customer pending credit if bill was on Credit
        if (bill.paymentMode == 'Credit' && bill.customerName.isNotEmpty && bill.customerName.trim().toLowerCase() != 'walk-in customer') {
          try {
            final normalized = bill.customerName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
            final query = await _customersRef.where('searchName', isEqualTo: normalized).limit(1).get();
            final docs = query.docs.isNotEmpty ? query.docs : (await _customersRef.where('name', isEqualTo: bill.customerName.trim()).limit(1).get()).docs;
            if (docs.isNotEmpty) {
              final docRef = docs.first.reference;
              await _firestore.runTransaction((transaction) async {
                final snap = await transaction.get(docRef);
                if (!snap.exists) return;
                final data = snap.data() as Map<String, dynamic>;
                final currentBal = (data['pendingBalance'] as num?)?.toDouble() ?? 0.0;
                transaction.update(docRef, {'pendingBalance': (currentBal - bill.netAmount).clamp(0.0, 9999999.0)});
              });
            }
          } catch (e) {
            debugPrint('Error reverting customer balance for bill cancellation: $e');
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error cancelling bill: $e');
      return false;
    }
  }

  Future<bool> _restockInventory(String name, String batchNumber, int qtyToRestock) async {
    try {
      final cleanName = name.trim();
      final cleanBatch = batchNumber.trim();

      Query query = _inventoryRef.where('medicineName', isEqualTo: cleanName);
      if (cleanBatch.isNotEmpty) {
        query = query.where('batchNumber', isEqualTo: cleanBatch);
      }

      final snap = await query.limit(1).get();
      if (snap.docs.isEmpty) {
        final fallbackSnap = await _inventoryRef.where('medicineName', isEqualTo: cleanName).limit(1).get();
        if (fallbackSnap.docs.isEmpty) return false;
        final docRef = fallbackSnap.docs.first.reference;
        return await _runRestockTransaction(docRef, qtyToRestock);
      } else {
        final docRef = snap.docs.first.reference;
        return await _runRestockTransaction(docRef, qtyToRestock);
      }
    } catch (e) {
      debugPrint('Error restocking inventory for $name (Batch: $batchNumber): $e');
      return false;
    }
  }

  Future<bool> _runRestockTransaction(DocumentReference docRef, int qtyToRestock) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        final data = snapshot.data() as Map<String, dynamic>;
        final currentQty = (data['quantity'] as num?)?.toInt() ?? 0;
        transaction.update(docRef, {'quantity': currentQty + qtyToRestock});
      });
      return true;
    } catch (e) {
      debugPrint('Transaction restock failed: $e');
      return false;
    }
  }

  // ================= DATA RESET / WIPE ALL DATA API =================

  Future<void> clearAllData() async {
    try {
      final collections = [_billsRef, _inventoryRef, _customersRef, _suppliersRef, _paymentsRef, _vouchersRef];
      for (var col in collections) {
        final snapshot = await col.get();
        if (snapshot.docs.isNotEmpty) {
          for (var i = 0; i < snapshot.docs.length; i += 400) {
            final chunk = snapshot.docs.sublist(i, i + 400 > snapshot.docs.length ? snapshot.docs.length : i + 400);
            final batch = _firestore.batch();
            for (var doc in chunk) {
              batch.delete(doc.reference);
            }
            await batch.commit();
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing Firestore store data: $e');
    }
  }
}
