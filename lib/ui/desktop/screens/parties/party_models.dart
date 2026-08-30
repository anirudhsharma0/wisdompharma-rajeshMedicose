class PartyItem {
  final String id;
  final String name;
  final String phone;
  final double amount; // Positive = Due to pay (Supplier) or Pending to collect (Customer)
  final String partyType; // 'Supplier' or 'Customer'
  final String? gstin;
  final String? address;

  PartyItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.amount,
    required this.partyType,
    this.gstin,
    this.address,
  });
}

class PartyTransaction {
  final String id;
  final String type; // 'Purchase', 'Payment-Out', 'Sale', 'Payment-In', 'Opening Balance'
  final String refNumber;
  final DateTime date;
  final double totalAmount;
  final double balance;
  final String status;
  final String? remarks;
  final dynamic rawObject;

  PartyTransaction({
    required this.id,
    required this.type,
    required this.refNumber,
    required this.date,
    required this.totalAmount,
    required this.balance,
    required this.status,
    this.remarks,
    this.rawObject,
  });
}
