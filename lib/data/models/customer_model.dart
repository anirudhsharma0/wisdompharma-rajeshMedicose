import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String? id;
  final String name;
  final String phone;
  final double pendingBalance;

  CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    required this.pendingBalance,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      pendingBalance: (map['pendingBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'pendingBalance': pendingBalance,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    double? pendingBalance,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      pendingBalance: pendingBalance ?? this.pendingBalance,
    );
  }
}

class CustomerPaymentModel {
  final String? id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final double amountPaid;
  final DateTime createdAt;

  CustomerPaymentModel({
    this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.amountPaid,
    required this.createdAt,
  });

  factory CustomerPaymentModel.fromMap(Map<String, dynamic> map, String id) {
    // Handle parsing createdAt
    DateTime createdDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        createdDate = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        createdDate = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
      }
    }
    return CustomerPaymentModel(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'amountPaid': amountPaid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  CustomerPaymentModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    double? amountPaid,
    DateTime? createdAt,
  }) {
    return CustomerPaymentModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      amountPaid: amountPaid ?? this.amountPaid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
