import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_model.dart';
import '../models/supplier_model.dart';
import '../../providers/dashboard_provider.dart';
import 'firebase_service.dart';

class ScannedBillItem {
  int srNo;
  String productName;
  String pack;
  int quantity;
  int freeQty;
  String batchNumber;
  String expiryDate;
  String hsn;
  double mrp;
  double purchaseRate;
  double schemeDiscount;
  double discountPercent;
  double gstPercent;
  double netAmount;

  ScannedBillItem({
    this.srNo = 1,
    required this.productName,
    this.pack = '',
    required this.quantity,
    this.freeQty = 0,
    required this.batchNumber,
    required this.expiryDate,
    this.hsn = '',
    required this.mrp,
    required this.purchaseRate,
    this.schemeDiscount = 0.0,
    this.discountPercent = 0.0,
    this.gstPercent = 0.0,
    required this.netAmount,
  });

  double get grossAmount => quantity * purchaseRate;

  double get schemeDiscountAmount {
    if (schemeDiscount <= 0) return 0.0;
    if (schemeDiscount <= 100) {
      return grossAmount * (schemeDiscount / 100);
    }
    return schemeDiscount;
  }

  double get tradeDiscountAmount {
    final afterScheme = grossAmount - schemeDiscountAmount;
    if (discountPercent <= 0) return 0.0;
    return afterScheme * (discountPercent / 100);
  }

  double get taxableAmount {
    final tax = grossAmount - schemeDiscountAmount - tradeDiscountAmount;
    return tax > 0 ? tax : 0.0;
  }

  double get gstAmount {
    if (gstPercent <= 0) return 0.0;
    return taxableAmount * (gstPercent / 100);
  }

  double get calculatedNet {
    return taxableAmount + gstAmount;
  }

  factory ScannedBillItem.fromJson(Map<String, dynamic> json, int index) {
    final qty = (json['quantity'] ?? json['qty'] ?? 1) is num
        ? (json['quantity'] ?? json['qty'] ?? 1).toInt()
        : int.tryParse((json['quantity'] ?? json['qty'] ?? 1).toString()) ?? 1;
    final rate = (json['purchaseRate'] ?? json['rate'] as num?)?.toDouble() ??
        double.tryParse((json['purchaseRate'] ?? json['rate'] ?? '0').toString()) ??
        0.0;
    final sch = (json['schemeDiscount'] ?? json['scheme'] ?? json['sch'] as num?)?.toDouble() ??
        double.tryParse((json['schemeDiscount'] ?? json['scheme'] ?? json['sch'] ?? '0').toString()) ??
        0.0;
    final dis = (json['discountPercent'] ?? json['dis'] as num?)?.toDouble() ??
        double.tryParse((json['discountPercent'] ?? json['dis'] ?? '0').toString()) ??
        0.0;
    final gst = (json['gstPercent'] ?? json['gst'] as num?)?.toDouble() ??
        double.tryParse((json['gstPercent'] ?? json['gst'] ?? '0').toString()) ??
        0.0;

    double net = (json['netAmount'] ?? json['amount'] as num?)?.toDouble() ??
        double.tryParse((json['netAmount'] ?? json['amount'] ?? '0').toString()) ??
        0.0;

    final item = ScannedBillItem(
      srNo: (json['srNo'] as num?)?.toInt() ?? (index + 1),
      productName: (json['productName'] ?? json['product'] ?? json['name'] ?? 'Unknown Item').toString(),
      pack: (json['pack'] ?? '').toString(),
      quantity: qty > 0 ? qty : 1,
      freeQty: (json['freeQty'] ?? json['free'] ?? 0) is num
          ? (json['freeQty'] ?? json['free'] ?? 0).toInt()
          : int.tryParse((json['freeQty'] ?? json['free'] ?? '0').toString()) ?? 0,
      batchNumber: (json['batchNumber'] ?? json['batch'] ?? 'N/A').toString(),
      expiryDate: (json['expiryDate'] ?? json['expiry'] ?? json['exp'] ?? 'N/A').toString(),
      hsn: (json['hsn'] ?? '').toString(),
      mrp: (json['mrp'] as num?)?.toDouble() ?? double.tryParse((json['mrp'] ?? '0').toString()) ?? 0.0,
      purchaseRate: rate,
      schemeDiscount: sch,
      discountPercent: dis,
      gstPercent: gst,
      netAmount: net,
    );

    // If printed net amount is missing or zero, compute using GST formula
    if (item.netAmount <= 0) {
      item.netAmount = item.calculatedNet;
    }

    return item;
  }

  Map<String, dynamic> toJson() {
    return {
      'srNo': srNo,
      'productName': productName,
      'pack': pack,
      'quantity': quantity,
      'freeQty': freeQty,
      'batchNumber': batchNumber,
      'expiryDate': expiryDate,
      'hsn': hsn,
      'mrp': mrp,
      'purchaseRate': purchaseRate,
      'schemeDiscount': schemeDiscount,
      'scheme': schemeDiscount,
      'discountPercent': discountPercent,
      'gstPercent': gstPercent,
      'netAmount': netAmount,
    };
  }
}

class ScannedBillModel {
  String id;
  String supplierName;
  String invoiceNumber;
  String invoiceDate;
  double grandTotal;
  double billDiscountPercent; // Overall bill discount (e.g. 4.0 for 4%)
  double billDiscountAmount;  // Overall bill discount in rupees (e.g. 147.73)
  List<ScannedBillItem> items;
  DateTime scannedAt;
  String status; // 'pending', 'approved', 'rejected'
  bool isAmountTaxable; // true if printed table column is taxable amount before GST

  ScannedBillModel({
    String? id,
    required this.supplierName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.grandTotal,
    this.billDiscountPercent = 0.0,
    this.billDiscountAmount = 0.0,
    required this.items,
    DateTime? scannedAt,
    this.status = 'pending',
    this.isAmountTaxable = false,
  })  : id = id ?? 'sb_${DateTime.now().millisecondsSinceEpoch}',
        scannedAt = scannedAt ?? DateTime.now();

  double get itemsSubtotal => items.fold(0.0, (sum, i) => sum + i.taxableAmount);

  double get calculatedBillDiscount {
    if (billDiscountAmount > 0) return billDiscountAmount;
    if (billDiscountPercent > 0) {
      return itemsSubtotal * (billDiscountPercent / 100);
    }
    return 0.0;
  }

  double get calculatedTaxableTotal {
    final sub = itemsSubtotal - calculatedBillDiscount;
    return sub > 0 ? sub : 0.0;
  }

  double get calculatedGstTotal {
    final factor = itemsSubtotal > 0 ? (calculatedTaxableTotal / itemsSubtotal) : 1.0;
    return items.fold(0.0, (sum, i) => sum + (i.gstAmount * factor));
  }

  double get calculatedGrandTotal => calculatedTaxableTotal + calculatedGstTotal;

  double get roundOff {
    if (grandTotal > 0) {
      return grandTotal - calculatedGrandTotal;
    }
    return 0.0;
  }

  factory ScannedBillModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    List<ScannedBillItem> parsedItems = [];
    for (int i = 0; i < rawItems.length; i++) {
      if (rawItems[i] is Map<String, dynamic>) {
        parsedItems.add(ScannedBillItem.fromJson(rawItems[i], i));
      }
    }

    final parsedGrandTotal = (json['grandTotal'] ?? json['totalAmount'] ?? json['grand_total'] as num?)?.toDouble() ?? 0.0;
    final disPct = (json['billDiscountPercent'] ?? json['billDiscount'] ?? json['discPercent'] as num?)?.toDouble() ??
        double.tryParse((json['billDiscountPercent'] ?? json['billDiscount'] ?? json['discPercent'] ?? '0').toString()) ??
        0.0;
    final disAmt = (json['billDiscountAmount'] ?? json['discountAmount'] as num?)?.toDouble() ??
        double.tryParse((json['billDiscountAmount'] ?? json['discountAmount'] ?? '0').toString()) ??
        0.0;

    final bill = ScannedBillModel(
      id: json['id']?.toString(),
      supplierName: (json['supplierName'] ?? json['supplier'] ?? json['vendor'] ?? 'PURCHASE AGENCY').toString(),
      invoiceNumber: (json['invoiceNumber'] ?? json['invoiceNo'] ?? json['billNo'] ?? '').toString(),
      invoiceDate: (json['invoiceDate'] ?? json['date'] ?? '').toString(),
      grandTotal: parsedGrandTotal,
      billDiscountPercent: disPct,
      billDiscountAmount: disAmt,
      items: parsedItems,
      scannedAt: json['scannedAt'] != null ? DateTime.tryParse(json['scannedAt'].toString()) : null,
      status: json['status']?.toString() ?? 'pending',
      isAmountTaxable: json['isAmountTaxable'] == true,
    );

    // Auto-fill grand total if missing
    if (bill.grandTotal <= 0 && bill.items.isNotEmpty) {
      bill.grandTotal = bill.calculatedGrandTotal;
    }

    return bill;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierName': supplierName,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': invoiceDate,
      'grandTotal': grandTotal,
      'billDiscountPercent': billDiscountPercent,
      'billDiscountAmount': billDiscountAmount,
      'items': items.map((i) => i.toJson()).toList(),
      'scannedAt': scannedAt.toIso8601String(),
      'status': status,
      'isAmountTaxable': isAmountTaxable,
    };
  }
}

class BillOcrService {
  static final BillOcrService instance = BillOcrService._internal();
  BillOcrService._internal();

  static const String _defaultApiKey = '';
  static const String _prefApiKey = 'gemini_ocr_api_key';
  static const String _prefPendingBills = 'pending_scanned_bills_queue';

  CollectionReference get _pendingBillsRef => FirebaseFirestore.instance
      .collection('stores')
      .doc(FirebaseService.instance.storeId)
      .collection('pending_bills');

  Stream<List<ScannedBillModel>> streamPendingBills() {
    try {
      return _pendingBillsRef
          .orderBy('scannedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return ScannedBillModel.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
      });
    } catch (e) {
      debugPrint('Firestore pending bills stream error: $e');
      return Stream.value([]);
    }
  }

  Future<List<ScannedBillModel>> getPendingBills() async {
    // 1. Try fetching from Cloud Firestore first for multi-device realtime sync
    try {
      final snapshot = await _pendingBillsRef.get();
      if (snapshot.docs.isNotEmpty) {
        final list = snapshot.docs.map((doc) {
          return ScannedBillModel.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
        list.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
        // Sync to local cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefPendingBills, jsonEncode(list.map((b) => b.toJson()).toList()));
        return list;
      }
    } catch (e) {
      debugPrint('Firestore fetch pending bills error (falling back to local cache): $e');
    }

    // 2. Fallback to local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefPendingBills);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List list = jsonDecode(jsonStr);
      return list.map((e) => ScannedBillModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingBill(ScannedBillModel bill) async {
    // 1. Update local cache
    final bills = await getPendingBills();
    bills.removeWhere((b) => b.id == bill.id);
    bills.insert(0, bill);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPendingBills, jsonEncode(bills.map((b) => b.toJson()).toList()));

    // 2. Sync to Cloud Firestore for Desktop App real-time processing
    try {
      await FirebaseService.instance.ensureAuthenticated();
      await _pendingBillsRef.doc(bill.id).set(bill.toJson());
      debugPrint('Pending bill successfully uploaded to Firestore: ${bill.id}');
    } catch (e) {
      debugPrint('Failed to sync pending bill to Firestore: $e');
    }
  }

  Future<void> removePendingBill(String id) async {
    // 1. Update local cache
    final bills = await getPendingBills();
    bills.removeWhere((b) => b.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPendingBills, jsonEncode(bills.map((b) => b.toJson()).toList()));

    // 2. Delete from Cloud Firestore
    try {
      await _pendingBillsRef.doc(id).delete();
      debugPrint('Pending bill deleted from Firestore: $id');
    } catch (e) {
      debugPrint('Failed to delete pending bill from Firestore: $e');
    }
  }

  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefApiKey);
    // Return saved key if it exists and is non-empty
    if (saved != null && saved.trim().isNotEmpty) {
      debugPrint('Using saved API key from preferences (ends with: ...${saved.trim().length > 6 ? saved.trim().substring(saved.trim().length - 6) : saved.trim()})');
      return saved.trim();
    }
    debugPrint('Using default API key from code.');
    return _defaultApiKey;
  }

  Future<void> saveApiKey(String newKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, newKey.trim());
  }

  String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
        return 'image/webp';
      }
      if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        return 'application/pdf';
      }
    }
    return 'image/jpeg';
  }

  /// Send bill image to Gemini API and parse into ScannedBillModel
  Future<ScannedBillModel> scanBillImage(Uint8List imageBytes, {String? mimeType}) async {
    final apiKey = (await getApiKey()).trim();
    final effectiveMimeType = mimeType ?? _detectMimeType(imageBytes);
    final base64Image = base64Encode(imageBytes);

    debugPrint('Scanning bill: image size=${imageBytes.length} bytes, detected mimeType=$effectiveMimeType');

    final promptText = '''
You are an expert OCR scanner for Indian wholesale medicine purchase invoices (e.g. Marg ERP, Busy, Tally bills from distributors like Madaan Medicose, Manav, Kissan, Ram, Ganpati, Friends Medical Agency).
Analyze the provided bill image with 100% precision.
Extract header details, all line items, free quantities, discounts, tax rates, footer overall bill discounts, and final printed totals.

Required JSON Structure (Return ONLY raw valid JSON text, no markdown backticks, no explanatory text):
{
  "supplierName": "Full Name of Distributor/Agency (e.g. MADAAN MEDICOSE)",
  "invoiceNumber": "Invoice/Bill Number (e.g. 3006 or A000892)",
  "invoiceDate": "Date of invoice (e.g. 28/08/2026)",
  "grandTotal": 3554.00,
  "billDiscountPercent": 4.0,
  "billDiscountAmount": 147.73,
  "isAmountTaxable": false,
  "items": [
    {
      "srNo": 1,
      "productName": "Medicine/Product Name (e.g. CNS LIQ.)",
      "pack": "Pack Size (e.g. 1LTR)",
      "quantity": 1,
      "freeQty": 0,
      "batchNumber": "Batch Number (e.g. F-5558)",
      "expiryDate": "Expiry Date in MM/YY or YYYY-MM (e.g. 02/28)",
      "hsn": "HSN Code (e.g. 23099010)",
      "mrp": 600.00,
      "purchaseRate": 405.56,
      "scheme": 0.0,
      "discountPercent": 0.0,
      "gstPercent": 0.0,
      "netAmount": 405.56
    }
  ]
}

Strict Rules:
1. Extract Qty and Free Qty accurately. If column says "Qty / Free" or "Qty + Free", separate main Qty from Free Qty.
2. Extract Rate (Purchase Rate), Scheme Discount % (Sch %), Trade Discount % (Dis %), and GST % accurately for each line. If item says "GST FREE", set gstPercent to 0.0.
3. VERY IMPORTANT: Check invoice footer / summary table for overall bill discounts (e.g. "DISC. 4.00%", "CASH DISC", "TRADE DISCOUNT"). Store the percentage in "billDiscountPercent" (e.g. 4.0) and total discount amount in "billDiscountAmount" (e.g. 147.73).
4. In "isAmountTaxable", return true if the table column "Amount" represents Taxable Value (before GST), or false if it represents Net Total Value.
5. Return ONLY valid JSON. All numeric values must be numbers.
''';

    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": promptText},
            {
              "inline_data": {
                "mime_type": effectiveMimeType,
                "data": base64Image
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.1,
        "maxOutputTokens": 8192,
        "response_mime_type": "application/json"
      }
    };

    final endpoints = [
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$apiKey',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$apiKey',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$apiKey',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey',
    ];

    http.Response? response;
    String? lastErrorDetails;

    debugPrint('Using Gemini API Key ending in: ...${apiKey.length > 6 ? apiKey.substring(apiKey.length - 6) : apiKey}');

    for (final endpoint in endpoints) {
      final url = Uri.parse(endpoint);
      try {
        final res = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) {
          response = res;
          debugPrint('Successfully scanned using Gemini endpoint: $endpoint');
          break;
        } else {
          lastErrorDetails = '[Code ${res.statusCode}] ${res.body}';
          debugPrint('Endpoint failed (${res.statusCode}): $endpoint \nResponse: ${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
        }
      } catch (e) {
        lastErrorDetails = '[Exception: $e]';
        debugPrint('Exception for endpoint $endpoint: $e');
      }
    }

    if (response == null || response.statusCode != 200) {
      debugPrint('All Gemini OCR endpoints failed: $lastErrorDetails');
      throw Exception('Gemini API Error: $lastErrorDetails');
    }

    final responseJson = jsonDecode(response.body);
    final candidates = responseJson['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response generated by Gemini AI Vision.');
    }

    final parts = candidates[0]['content']['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty content returned by AI.');
    }

    String rawText = parts[0]['text'] ?? '';
    debugPrint('Gemini Raw OCR Output:\n$rawText');

    final parsedMap = _parseOrRepairJson(rawText);
    return ScannedBillModel.fromJson(parsedMap);
  }

  /// Robust JSON Auto-Repair & Fallback Parser to prevent FormatException truncation
  Map<String, dynamic> _parseOrRepairJson(String rawText) {
    String cleaned = rawText.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();

    // 1. Direct parse attempt
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('Standard JSON decode failed. Attempting smart auto-repair...');
    }

    // 2. Smart Repair unclosed brackets/commas
    try {
      String repaired = cleaned;
      // Cut off incomplete key-value pair at the end
      final lastCommaIdx = repaired.lastIndexOf(',');
      if (lastCommaIdx != -1) {
        repaired = repaired.substring(0, lastCommaIdx);
      }

      int openBraces = 0;
      int openBrackets = 0;
      for (int i = 0; i < repaired.length; i++) {
        if (repaired[i] == '{') openBraces++;
        if (repaired[i] == '}') openBraces--;
        if (repaired[i] == '[') openBrackets++;
        if (repaired[i] == ']') openBrackets--;
      }

      while (openBrackets > 0) {
        repaired += ']';
        openBrackets--;
      }
      while (openBraces > 0) {
        repaired += '}';
        openBraces--;
      }

      return jsonDecode(repaired) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Auto-repair failed: $e. Using Regex Fallback.');
    }

    // 3. Ultimate Regex Fallback to extract items safely
    final supplierMatch = RegExp(r'"supplierName"\s*:\s*"([^"]+)"').firstMatch(cleaned);
    final invoiceNoMatch = RegExp(r'"invoiceNumber"\s*:\s*"([^"]+)"').firstMatch(cleaned);
    final invoiceDateMatch = RegExp(r'"invoiceDate"\s*:\s*"([^"]+)"').firstMatch(cleaned);
    final grandTotalMatch = RegExp(r'"grandTotal"\s*:\s*([\d\.]+)').firstMatch(cleaned);

    final itemMatches = RegExp(r'\{[^{}]*"productName"[^{}]*\}').allMatches(cleaned);
    List<Map<String, dynamic>> extractedItems = [];

    for (final m in itemMatches) {
      try {
        extractedItems.add(jsonDecode(m.group(0)!) as Map<String, dynamic>);
      } catch (_) {}
    }

    return {
      "supplierName": supplierMatch?.group(1) ?? "RAM MEDICAL AGENCY",
      "invoiceNumber": invoiceNoMatch?.group(1) ?? "",
      "invoiceDate": invoiceDateMatch?.group(1) ?? "",
      "grandTotal": double.tryParse(grandTotalMatch?.group(1) ?? "0") ?? 0.0,
      "items": extractedItems,
    };
  }

  /// Generate an Excel (.xlsx) file from ScannedBillModel and save to local disk
  Future<File> generateExcelSheet(ScannedBillModel bill) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Purchase Bill'];
    excel.setDefaultSheet('Purchase Bill');

    // Headers
    sheetObject.appendRow([TextCellValue('PURCHASE INVOICE REPORT')]);
    sheetObject.appendRow([TextCellValue('Supplier Name:'), TextCellValue(bill.supplierName)]);
    sheetObject.appendRow([TextCellValue('Invoice Number:'), TextCellValue(bill.invoiceNumber)]);
    sheetObject.appendRow([TextCellValue('Invoice Date:'), TextCellValue(bill.invoiceDate)]);
    sheetObject.appendRow([TextCellValue('Grand Total (₹):'), DoubleCellValue(bill.grandTotal)]);
    sheetObject.appendRow([]); // Blank row

    // Table Column Headers
    sheetObject.appendRow([
      TextCellValue('S.No'),
      TextCellValue('Product Name'),
      TextCellValue('Pack'),
      TextCellValue('Batch No'),
      TextCellValue('Expiry Date'),
      TextCellValue('HSN'),
      TextCellValue('Qty'),
      TextCellValue('Free Qty'),
      TextCellValue('MRP (₹)'),
      TextCellValue('Purchase Rate (₹)'),
      TextCellValue('Sch (%)'),
      TextCellValue('Dis %'),
      TextCellValue('GST %'),
      TextCellValue('Net Amount (₹)'),
    ]);

    // Data Rows
    for (var item in bill.items) {
      sheetObject.appendRow([
        IntCellValue(item.srNo),
        TextCellValue(item.productName),
        TextCellValue(item.pack),
        TextCellValue(item.batchNumber),
        TextCellValue(item.expiryDate),
        TextCellValue(item.hsn),
        IntCellValue(item.quantity),
        IntCellValue(item.freeQty),
        DoubleCellValue(item.mrp),
        DoubleCellValue(item.purchaseRate),
        DoubleCellValue(item.schemeDiscount),
        DoubleCellValue(item.discountPercent),
        DoubleCellValue(item.gstPercent),
        DoubleCellValue(item.netAmount),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel bytes.');
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final fileName = 'PurchaseBill_${bill.invoiceNumber.isNotEmpty ? bill.invoiceNumber : DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    debugPrint('Excel Sheet saved successfully at: ${file.path}');
    return file;
  }

  /// Automatically commit scanned bill items to Stock Inventory and Supplier Due Ledger
  Future<void> commitToStockAndLedger(
    ScannedBillModel bill,
    DashboardProvider provider, {
    String paymentMode = 'Credit',
  }) async {
    // 1. Add each medicine to inventory stock
    for (var item in bill.items) {
      final totalQty = item.quantity + item.freeQty;
      final inventoryItem = InventoryModel(
        medicineName: item.productName.trim(),
        batchNumber: item.batchNumber.trim().isNotEmpty ? item.batchNumber.trim() : 'GENERIC',
        expiryDate: item.expiryDate.trim().isNotEmpty ? item.expiryDate.trim() : 'N/A',
        quantity: totalQty > 0 ? totalQty : 1,
        mrp: item.mrp > 0 ? item.mrp : item.purchaseRate * 1.2,
        salePrice: item.mrp > 0 ? item.mrp : item.purchaseRate * 1.2,
        purchasePrice: item.purchaseRate,
        supplierName: bill.supplierName.trim(),
      );

      await provider.addInventory(inventoryItem);
    }

    // 2. Ensure supplier exists or add supplier
    final supplierName = bill.supplierName.trim().isNotEmpty ? bill.supplierName.trim() : 'RAM MEDICAL AGENCY';
    final existingSupIndex = provider.suppliers.indexWhere(
      (s) => s.name.trim().toLowerCase() == supplierName.toLowerCase(),
    );

    String supplierId = '';
    if (existingSupIndex != -1) {
      supplierId = provider.suppliers[existingSupIndex].id ?? supplierName;
    } else {
      final newSup = SupplierModel(
        name: supplierName,
        contact: 'N/A',
        due: 0.0,
      );
      await provider.addSupplier(newSup);
      final idx = provider.suppliers.indexWhere((s) => s.name.trim().toLowerCase() == supplierName.toLowerCase());
      supplierId = idx != -1 ? (provider.suppliers[idx].id ?? supplierName) : supplierName;
    }

    // 3. Record Supplier Purchase Voucher & update supplier due amount
    final billTotal = bill.grandTotal > 0
        ? bill.grandTotal
        : bill.items.fold(0.0, (subTotal, i) => subTotal + i.netAmount);

    await provider.addSupplierPurchase(
      supplierId,
      billTotal,
      billNumber: bill.invoiceNumber.isNotEmpty ? bill.invoiceNumber : 'BILL-${DateTime.now().millisecondsSinceEpoch}',
      remarks: 'Auto Scanned Purchase Bill via AI OCR',
      paymentMode: paymentMode,
    );
  }
}
