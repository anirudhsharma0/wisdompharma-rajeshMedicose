class MedicineMasterModel {
  final int id;
  final String medicineName;
  final String? composition;
  final String? manufacturer;
  final double mrp;

  MedicineMasterModel({
    required this.id,
    required this.medicineName,
    this.composition,
    this.manufacturer,
    required this.mrp,
  });

  factory MedicineMasterModel.fromMap(Map<String, dynamic> map) {
    return MedicineMasterModel(
      id: map['id'] ?? 0,
      medicineName: map['medicine_name'] ?? map['medicineName'] ?? '',
      composition: map['composition'],
      manufacturer: map['manufacturer'],
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_name': medicineName,
      'composition': composition,
      'manufacturer': manufacturer,
      'mrp': mrp,
    };
  }
}
