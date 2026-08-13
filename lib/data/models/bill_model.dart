import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  final String medicineName;
  final String batchNumber;
  final String expiryDate;
  final int quantity;
  final double mrp;
  final double salePrice;
  final double totalPrice;
  final String? substitutes;
  final String? category;

  BillItem({
    required this.medicineName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.mrp,
    required this.salePrice,
    required this.totalPrice,
    this.substitutes,
    this.category,
  });

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      medicineName: map['medicineName'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      expiryDate: map['expiryDate'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      substitutes: map['substitutes'],
      category: map['category'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'batchNumber': batchNumber,
      'expiryDate': expiryDate,
      'quantity': quantity,
      'mrp': mrp,
      'salePrice': salePrice,
      'totalPrice': totalPrice,
      'substitutes': substitutes,
      'category': category,
    };
  }
}

class BillModel {
  final String? id;
  final String billNumber;
  final String customerName;
  final String customerPhone;
  final List<BillItem> items;
  final double totalAmount;
  final double discount;
  final double netAmount;
  final DateTime createdAt;
  final String paymentMode; // 'Cash', 'UPI', 'Card', 'Credit'
  final String status; // 'COMPLETED', 'CANCELLED', 'RETURNED'
  final String? localImagePath; // Local photo path stored on device

  BillModel({
    this.id,
    required this.billNumber,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totalAmount,
    required this.discount,
    required this.netAmount,
    required this.createdAt,
    required this.paymentMode,
    this.status = 'COMPLETED',
    this.localImagePath,
  });

  factory BillModel.fromMap(Map<String, dynamic> map, String id) {
    // Handle Timestamp or String parsing for createdAt
    DateTime createdDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        createdDate = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        createdDate = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
      }
    }

    var itemsList = map['items'] as List? ?? [];
    List<BillItem> parsedItems = itemsList
        .map((item) => BillItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    return BillModel(
      id: id,
      billNumber: map['billNumber'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      items: parsedItems,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdDate,
      paymentMode: map['paymentMode'] ?? 'Cash',
      status: map['status'] ?? 'COMPLETED',
      localImagePath: map['localImagePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billNumber': billNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'discount': discount,
      'netAmount': netAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'paymentMode': paymentMode,
      'status': status,
      if (localImagePath != null) 'localImagePath': localImagePath,
    };
  }

  // Helper to generate a new copy with modified parameters
  BillModel copyWith({
    String? id,
    String? billNumber,
    String? customerName,
    String? customerPhone,
    List<BillItem>? items,
    double? totalAmount,
    double? discount,
    double? netAmount,
    DateTime? createdAt,
    String? paymentMode,
    String? status,
    String? localImagePath,
  }) {
    return BillModel(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      netAmount: netAmount ?? this.netAmount,
      createdAt: createdAt ?? this.createdAt,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}
