import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  final String medicineName;
  final String batchNumber;
  final String expiryDate;
  final int quantity;
  final int freeQty;
  final String pack;
  final String hsn;
  final double mrp;
  final double salePrice; // Rate per unit
  final double schemeDiscPercent;
  final double tradeDiscPercent;
  final double gstPercent;
  final double totalPrice; // Gross line amount: quantity * salePrice
  final String? substitutes;
  final String? category;

  BillItem({
    required this.medicineName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    this.freeQty = 0,
    this.pack = '',
    this.hsn = '',
    required this.mrp,
    required this.salePrice,
    this.schemeDiscPercent = 0.0,
    this.tradeDiscPercent = 0.0,
    this.gstPercent = 0.0,
    required this.totalPrice,
    this.substitutes,
    this.category,
  });

  // Calculate gross line amount (Rate * Qty)
  double get grossAmount => quantity * salePrice;

  // Scheme discount amount for line item
  double get schemeDiscAmount => grossAmount * (schemeDiscPercent / 100.0);

  // Amount after scheme discount
  double get afterSchemeAmount => grossAmount - schemeDiscAmount;

  // Trade discount amount for line item
  double get tradeDiscAmount => afterSchemeAmount * (tradeDiscPercent / 100.0);

  // Total discount amount for line item
  double get lineDiscountAmount => schemeDiscAmount + tradeDiscAmount;

  // Taxable amount for line item
  double get lineTaxableAmount => grossAmount - lineDiscountAmount;

  // GST amount for line item
  double get lineGstAmount => lineTaxableAmount * (gstPercent / 100.0);

  factory BillItem.fromMap(Map<String, dynamic> map) {
    int qty = (map['quantity'] as num?)?.toInt() ?? 0;
    double rate = (map['salePrice'] as num?)?.toDouble() ?? 0.0;
    double computedGross = qty * rate;
    double rawTotal = (map['totalPrice'] as num?)?.toDouble() ?? computedGross;

    return BillItem(
      medicineName: map['medicineName'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      expiryDate: map['expiryDate'] ?? '',
      quantity: qty,
      freeQty: (map['freeQty'] as num?)?.toInt() ?? 0,
      pack: map['pack'] ?? '',
      hsn: map['hsn'] ?? '',
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      salePrice: rate,
      schemeDiscPercent: (map['schemeDiscPercent'] as num?)?.toDouble() ?? 0.0,
      tradeDiscPercent: (map['tradeDiscPercent'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (map['gstPercent'] as num?)?.toDouble() ?? 0.0,
      totalPrice: rawTotal > 0 ? rawTotal : computedGross,
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
      'freeQty': freeQty,
      'pack': pack,
      'hsn': hsn,
      'mrp': mrp,
      'salePrice': salePrice,
      'schemeDiscPercent': schemeDiscPercent,
      'tradeDiscPercent': tradeDiscPercent,
      'gstPercent': gstPercent,
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
  final double customerPrevBalance;
  final List<BillItem> items;
  final double totalAmount; // Subtotal (gross line amounts)
  final double discount; // Total scheme + trade discounts
  final double gstPercentage;
  final double gstAmount;
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
    this.customerPrevBalance = 0.0,
    required this.items,
    required this.totalAmount,
    required this.discount,
    this.gstPercentage = 0.0,
    this.gstAmount = 0.0,
    required this.netAmount,
    required this.createdAt,
    required this.paymentMode,
    this.status = 'COMPLETED',
    this.localImagePath,
  });

  // Gross Sub Total (Sum of Rate * Qty for all items)
  double get subTotal {
    if (items.isNotEmpty) {
      return items.fold(0.0, (acc, item) => acc + item.grossAmount);
    }
    return totalAmount;
  }

  // Total scheme discount
  double get totalSchemeDiscount {
    return items.fold(0.0, (acc, item) => acc + item.schemeDiscAmount);
  }

  // Total trade discount
  double get totalTradeDiscount {
    return items.fold(0.0, (acc, item) => acc + item.tradeDiscAmount);
  }

  // Total discount (Scheme + Trade)
  double get totalDiscount {
    if (discount > 0) return discount;
    return totalSchemeDiscount + totalTradeDiscount;
  }

  // Taxable Amount (Subtotal - Discount)
  double get taxableAmount {
    return (subTotal - totalDiscount).clamp(0.0, 9999999.0);
  }

  // CGST Amount (Half of total GST)
  double get cgstAmount => (gstAmount / 2.0);

  // SGST Amount (Half of total GST)
  double get sgstAmount => (gstAmount / 2.0);

  // Calculated Round Off
  double get roundOff {
    double rawTotal = taxableAmount + gstAmount;
    return (netAmount - rawTotal);
  }

  // Total Outstanding Balance (Previous Balance + Net Amount)
  double get totalOutstanding => customerPrevBalance + netAmount;

  // Total Items Count
  int get totalItemsCount => items.length;

  // Total Qty Count (including free qty)
  int get totalQtyCount =>
      items.fold(0, (acc, item) => acc + item.quantity + item.freeQty);

  factory BillModel.fromMap(Map<String, dynamic> map, String id) {
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
      customerPrevBalance:
          (map['customerPrevBalance'] as num?)?.toDouble() ?? 0.0,
      items: parsedItems,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      gstPercentage: (map['gstPercentage'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (map['gstAmount'] as num?)?.toDouble() ?? 0.0,
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
      'customerPrevBalance': customerPrevBalance,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'discount': discount,
      'gstPercentage': gstPercentage,
      'gstAmount': gstAmount,
      'netAmount': netAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'paymentMode': paymentMode,
      'status': status,
      if (localImagePath != null) 'localImagePath': localImagePath,
    };
  }

  BillModel copyWith({
    String? id,
    String? billNumber,
    String? customerName,
    String? customerPhone,
    double? customerPrevBalance,
    List<BillItem>? items,
    double? totalAmount,
    double? discount,
    double? gstPercentage,
    double? gstAmount,
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
      customerPrevBalance: customerPrevBalance ?? this.customerPrevBalance,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      gstAmount: gstAmount ?? this.gstAmount,
      netAmount: netAmount ?? this.netAmount,
      createdAt: createdAt ?? this.createdAt,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}
