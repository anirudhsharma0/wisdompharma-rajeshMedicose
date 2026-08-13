class InventoryModel {
  final String? id;
  final String medicineName;
  final String batchNumber;
  final String expiryDate; // Format: YYYY-MM or YYYY-MM-DD
  final int quantity;
  final double mrp;
  final double salePrice;
  final double purchasePrice;
  final String supplierName;

  InventoryModel({
    this.id,
    required this.medicineName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.mrp,
    required this.salePrice,
    required this.purchasePrice,
    this.supplierName = '',
  });

  // Factory constructor to create an InventoryModel from a Firestore map
  factory InventoryModel.fromMap(Map<String, dynamic> map, String id) {
    return InventoryModel(
      id: id,
      medicineName: map['medicineName'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      expiryDate: map['expiryDate'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      supplierName: map['supplierName'] ?? '',
    );
  }

  // Convert an InventoryModel to a Firestore map
  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'batchNumber': batchNumber,
      'expiryDate': expiryDate,
      'quantity': quantity,
      'mrp': mrp,
      'salePrice': salePrice,
      'purchasePrice': purchasePrice,
      'supplierName': supplierName,
    };
  }

  // Create a copy of the model with updated fields
  InventoryModel copyWith({
    String? id,
    String? medicineName,
    String? batchNumber,
    String? expiryDate,
    int? quantity,
    double? mrp,
    double? salePrice,
    double? purchasePrice,
    String? supplierName,
  }) {
    return InventoryModel(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      mrp: mrp ?? this.mrp,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      supplierName: supplierName ?? this.supplierName,
    );
  }
}
