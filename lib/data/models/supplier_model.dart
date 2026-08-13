class SupplierModel {
  final String? id;
  final String name;
  final String contact;
  final int orders;
  final double due;
  final String? gstin;
  final String? address;

  SupplierModel({
    this.id,
    required this.name,
    required this.contact,
    this.orders = 0,
    this.due = 0.0,
    this.gstin,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'orders': orders,
      'due': due,
      'gstin': gstin,
      'address': address,
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map, String docId) {
    return SupplierModel(
      id: docId,
      name: map['name'] ?? '',
      contact: map['contact'] ?? '',
      orders: (map['orders'] as num?)?.toInt() ?? 0,
      due: (map['due'] as num?)?.toDouble() ?? 0.0,
      gstin: map['gstin'],
      address: map['address'],
    );
  }

  SupplierModel copyWith({
    String? id,
    String? name,
    String? contact,
    int? orders,
    double? due,
    String? gstin,
    String? address,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      orders: orders ?? this.orders,
      due: due ?? this.due,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
    );
  }
}
