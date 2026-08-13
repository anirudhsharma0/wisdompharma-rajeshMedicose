import 'package:cloud_firestore/cloud_firestore.dart';

class VoucherModel {
  final String? id;
  final String voucherNumber;
  final String type; // 'RECEIPT' or 'PAYMENT'
  final String partyName;
  final String partyPhone;
  final double amount;
  final String paymentMode; // 'Cash', 'UPI', 'Cheque', 'Bank Transfer'
  final String referenceNumber; // Cheque No / UPI UTR / Bank Ref
  final String category; // 'Customer Khata', 'Supplier Payment', 'Rent', 'Salary', 'Misc'
  final String remarks;
  final DateTime createdAt;

  VoucherModel({
    this.id,
    required this.voucherNumber,
    required this.type,
    required this.partyName,
    this.partyPhone = '',
    required this.amount,
    required this.paymentMode,
    this.referenceNumber = '',
    this.category = 'General',
    this.remarks = '',
    required this.createdAt,
  });

  factory VoucherModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime createdDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        createdDate = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        createdDate = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
      }
    }

    return VoucherModel(
      id: id,
      voucherNumber: map['voucherNumber'] ?? '',
      type: map['type'] ?? 'RECEIPT',
      partyName: map['partyName'] ?? '',
      partyPhone: map['partyPhone'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['paymentMode'] ?? 'Cash',
      referenceNumber: map['referenceNumber'] ?? '',
      category: map['category'] ?? 'General',
      remarks: map['remarks'] ?? '',
      createdAt: createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'voucherNumber': voucherNumber,
      'type': type,
      'partyName': partyName,
      'partyPhone': partyPhone,
      'amount': amount,
      'paymentMode': paymentMode,
      'referenceNumber': referenceNumber,
      'category': category,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  VoucherModel copyWith({
    String? id,
    String? voucherNumber,
    String? type,
    String? partyName,
    String? partyPhone,
    double? amount,
    String? paymentMode,
    String? referenceNumber,
    String? category,
    String? remarks,
    DateTime? createdAt,
  }) {
    return VoucherModel(
      id: id ?? this.id,
      voucherNumber: voucherNumber ?? this.voucherNumber,
      type: type ?? this.type,
      partyName: partyName ?? this.partyName,
      partyPhone: partyPhone ?? this.partyPhone,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      category: category ?? this.category,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
