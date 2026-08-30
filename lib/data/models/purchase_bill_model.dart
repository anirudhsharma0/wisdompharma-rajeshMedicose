import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseBillModel {
  final String? id;
  final String billNumber;
  final String supplierName;
  final String supplierPhone;
  final DateTime billDate;
  final int itemsCount;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final String paymentMode;
  final String receiptNo;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;

  // Exact scanned footer breakdown values (As-Is Paper Data)
  final double itemsSubtotal;
  final double billDiscountAmount;
  final double netTaxableAmount;
  final double totalCGST;
  final double totalSGST;
  final double roundOff;

  PurchaseBillModel({
    this.id,
    required this.billNumber,
    required this.supplierName,
    this.supplierPhone = '',
    required this.billDate,
    required this.itemsCount,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentMode,
    this.receiptNo = '',
    required this.items,
    required this.createdAt,
    this.itemsSubtotal = 0.0,
    this.billDiscountAmount = 0.0,
    this.netTaxableAmount = 0.0,
    this.totalCGST = 0.0,
    this.totalSGST = 0.0,
    this.roundOff = 0.0,
  });

  factory PurchaseBillModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime bDate = DateTime.now();
    if (map['billDate'] != null) {
      if (map['billDate'] is Timestamp) {
        bDate = (map['billDate'] as Timestamp).toDate();
      } else if (map['billDate'] is String) {
        bDate = DateTime.tryParse(map['billDate']) ?? DateTime.now();
      }
    }

    DateTime cDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        cDate = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        cDate = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
      }
    }

    List<Map<String, dynamic>> parsedItems = [];
    if (map['items'] != null && map['items'] is List) {
      parsedItems = List<Map<String, dynamic>>.from(
        (map['items'] as List).map((i) => Map<String, dynamic>.from(i)),
      );
    }

    return PurchaseBillModel(
      id: id,
      billNumber: map['billNumber'] ?? '',
      supplierName: map['supplierName'] ?? '',
      supplierPhone: map['supplierPhone'] ?? '',
      billDate: bDate,
      itemsCount: (map['itemsCount'] as num?)?.toInt() ?? parsedItems.length,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      dueAmount: (map['dueAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['paymentMode'] ?? 'Cash',
      receiptNo: map['receiptNo'] ?? '',
      items: parsedItems,
      createdAt: cDate,
      itemsSubtotal: (map['itemsSubtotal'] as num?)?.toDouble() ?? 0.0,
      billDiscountAmount: (map['billDiscountAmount'] as num?)?.toDouble() ?? 0.0,
      netTaxableAmount: (map['netTaxableAmount'] as num?)?.toDouble() ?? 0.0,
      totalCGST: (map['totalCGST'] as num?)?.toDouble() ?? 0.0,
      totalSGST: (map['totalSGST'] as num?)?.toDouble() ?? 0.0,
      roundOff: (map['roundOff'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billNumber': billNumber,
      'supplierName': supplierName,
      'supplierPhone': supplierPhone,
      'billDate': Timestamp.fromDate(billDate),
      'itemsCount': itemsCount,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'paymentMode': paymentMode,
      'receiptNo': receiptNo,
      'items': items,
      'createdAt': Timestamp.fromDate(createdAt),
      'itemsSubtotal': itemsSubtotal,
      'billDiscountAmount': billDiscountAmount,
      'netTaxableAmount': netTaxableAmount,
      'totalCGST': totalCGST,
      'totalSGST': totalSGST,
      'roundOff': roundOff,
    };
  }
}
