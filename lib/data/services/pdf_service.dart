import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/voucher_model.dart';
import '../models/customer_model.dart';

class PdfService {
  /// Share receipt PDF via native share sheet (WhatsApp, Email, etc.)
  static Future<void> shareReceipt(
    BillModel bill, {
    String? pharmacyName,
    String? storeAddress,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final pName = (pharmacyName != null && pharmacyName.trim().isNotEmpty)
        ? pharmacyName
        : 'Rajesh Medicose';
    final pAddress = (storeAddress != null && storeAddress.trim().isNotEmpty)
        ? storeAddress
        : 'VPO Chaharwala (Sirsa) 125110';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                pName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                pAddress,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Bill No:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    bill.billNumber,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    dateFormat.format(bill.createdAt),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Customer:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    bill.customerName,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (bill.customerPhone.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Phone:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      bill.customerPhone,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Pay Mode:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    bill.paymentMode == 'Credit'
                        ? 'UDHAR'
                        : bill.paymentMode.toUpperCase(),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Item Description',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Batch/Exp',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              ...bill.items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.medicineName,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'MRP: Rs.${item.mrp.toStringAsFixed(2)} Rate: Rs.${item.salePrice.toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 6),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          children: [
                            pw.Text(
                              item.batchNumber,
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                            pw.Text(
                              item.expiryDate,
                              style: const pw.TextStyle(fontSize: 6),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          item.quantity.toString(),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Rs.${item.totalPrice.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Gross Total:',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Rs.${bill.totalAmount.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (bill.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Discount:',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      '-Rs.${bill.discount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NET AMOUNT:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Rs.${bill.netAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),

              pw.Text(
                'Thank You! Visit Again.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Powered by WisdomPharma\nWisdom Core Solutions | Ph: 9050524678',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 6.5,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final cleanBillNo = bill.billNumber.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    try {
      await Printing.sharePdf(bytes: bytes, filename: 'Bill_$cleanBillNo.pdf');
    } catch (e) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Bill_$cleanBillNo',
      );
    }
  }

  /// Generate and open OS print preview dialog for thermal receipt printing
  static Future<void> printReceipt(
    BillModel bill, {
    String? pharmacyName,
    String? storeAddress,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final pName = (pharmacyName != null && pharmacyName.trim().isNotEmpty)
        ? pharmacyName
        : 'Rajesh Medicose';
    final pAddress = (storeAddress != null && storeAddress.trim().isNotEmpty)
        ? storeAddress
        : 'VPO Chaharwala (Sirsa) 125110';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Pharmacy Header
              pw.Text(
                pName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                pAddress,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Bill No:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    bill.billNumber,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    dateFormat.format(bill.createdAt),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Customer:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    bill.customerName,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (bill.customerPhone.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Phone:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      bill.customerPhone,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Pay Mode:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    bill.paymentMode == 'Credit'
                        ? 'UDHAR'
                        : bill.paymentMode.toUpperCase(),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Item Description',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Batch/Exp',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Items list
              ...bill.items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.medicineName,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'MRP: Rs.${item.mrp.toStringAsFixed(2)} Rate: Rs.${item.salePrice.toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 6),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          children: [
                            pw.Text(
                              item.batchNumber,
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                            pw.Text(
                              item.expiryDate,
                              style: const pw.TextStyle(fontSize: 6),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          item.quantity.toString(),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Rs.${item.totalPrice.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Gross Total:',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Rs.${bill.totalAmount.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (bill.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Discount:',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      '-Rs.${bill.discount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NET AMOUNT:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Rs.${bill.netAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),

              pw.Text(
                'Thank You! Visit Again.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Medicines once sold cannot be returned.\nTax Invoice - Retail Sale',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 6),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${bill.billNumber}',
    );
  }

  /// Print Receipt / Payment Voucher
  static Future<void> printVoucher(
    VoucherModel voucher, {
    String? pharmacyName,
    String? storeAddress,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final isReceipt = voucher.type == 'RECEIPT';
    final pName = (pharmacyName != null && pharmacyName.trim().isNotEmpty)
        ? pharmacyName
        : 'Rajesh Medicose';
    final pAddress = (storeAddress != null && storeAddress.trim().isNotEmpty)
        ? storeAddress
        : 'VPO Chaharwala (Sirsa) 125110';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                pName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                pAddress,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                isReceipt ? 'OFFICIAL RECEIPT VOUCHER' : 'PAYMENT VOUCHER',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Voucher No:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    voucher.voucherNumber,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    dateFormat.format(voucher.createdAt),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isReceipt ? 'Received From:' : 'Paid To:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    voucher.partyName,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (voucher.partyPhone.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Phone:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      voucher.partyPhone,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Payment Mode:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    voucher.paymentMode,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (voucher.referenceNumber.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Ref / Txn No:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      voucher.referenceNumber,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'AMOUNT PAID:',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Rs.${voucher.amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              if (voucher.remarks.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  'Remarks: ${voucher.remarks}',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ],

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              pw.Text(
                'Authorized Signature & Stamp',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Voucher_${voucher.voucherNumber}',
    );
  }

  /// Generate and share A4 Customer Ledger Statement PDF
  static Future<void> generateAndShareCustomerStatement(
    CustomerModel customer,
    List<Map<String, dynamic>> txs, {
    String? pharmacyName,
    String? storeAddress,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final pName = (pharmacyName != null && pharmacyName.trim().isNotEmpty)
        ? pharmacyName
        : 'Rajesh Medicose';
    final pAddress = (storeAddress != null && storeAddress.trim().isNotEmpty)
        ? storeAddress
        : 'VPO Chaharwala (Sirsa) 125110';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Pharmacy Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        pName,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        pAddress,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'KHATA STATEMENT',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),

              // Customer Summary Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Customer Name: ${customer.name}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Phone Number: ${customer.phone}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'OUTSTANDING BALANCE',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          'Rs. ${customer.pendingBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: customer.pendingBalance > 0
                                ? PdfColors.red700
                                : PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Statement Timeline (Bills & Payments)',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),

              // Transactions Table
              pw.TableHelper.fromTextArray(
                headers: [
                  'Date & Time',
                  'Type',
                  'Ref No.',
                  'Items / Details',
                  'Amount (Rs.)',
                ],
                data: txs.map((tx) {
                  final isBill = tx['type'] == 'BILL';
                  return [
                    dateFormat.format(tx['date'] as DateTime),
                    isBill ? 'BILL (+)' : 'PAYMENT (-)',
                    tx['ref'] ?? '',
                    tx['details'] ?? '',
                    '${isBill ? "+" : "-"} Rs.${(tx['amount'] as double).toStringAsFixed(2)}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'WisdomPharma',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Powered by WisdomPharma | Developed by Wisdom Core Solutions (Ph: 9050524678 | wisdomcoresolution.store)',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final cleanName = customer.name
        .replaceAll(RegExp(r'[^\w\s\-]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    try {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Statement_$cleanName.pdf',
      );
    } catch (e) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Statement_$cleanName',
      );
    }
  }

  /// Generate Supplier/Customer Payment Receipt Voucher PDF (Matching Wholesale Pink Slip Format)
  static Future<Uint8List> generatePaymentReceiptPdf({
    required String voucherNumber,
    required String partyName,
    required String partyPhone,
    required double amountPaid,
    required String paymentMode,
    required String referenceNumber,
    required String remarks,
    required DateTime createdAt,
    required double remainingBalance,
    String? agencyName,
    String? agencyAddress,
    String? agencyPhone,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');

    final title = (agencyName != null && agencyName.trim().isNotEmpty)
        ? agencyName.trim()
        : 'WisdomPharma / Agency Payment Slip';
    final address = (agencyAddress != null && agencyAddress.trim().isNotEmpty)
        ? agencyAddress.trim()
        : 'Medical Wholesale & Retail Distributor';
    final phone = (agencyPhone != null && agencyPhone.trim().isNotEmpty)
        ? agencyPhone.trim()
        : 'Mob: 9050524678';

    final amountInWords = _numberToWords(amountPaid.toInt());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Top Agency Header
                pw.Center(
                  child: pw.Text(
                    title.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.pink900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    address,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    phone,
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),

                // Receipt No & Date Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Receipt No: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(voucherNumber.isNotEmpty ? voucherNumber : 'N/A', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Text('Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(dateFormat.format(createdAt), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),

                // Received From / Paid To Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Party / Customer Name: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(partyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900)),
                          if (partyPhone.isNotEmpty) ...[
                            pw.Text('  (Ph: $partyPhone)', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('Sum of Rupees: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Expanded(
                            child: pw.Text(
                              amountInWords,
                              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Amount & Details Grid
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Amount Box
                    pw.Container(
                      width: 140,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1),
                        color: PdfColors.grey200,
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('AMOUNT PAID', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Rs. ${amountPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    // Details Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text('Payment Mode: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                              pw.Text(paymentMode.toUpperCase(), style: const pw.TextStyle(fontSize: 9.5)),
                            ],
                          ),
                          if (referenceNumber.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Row(
                              children: [
                                pw.Text('Bill / Ref No: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                                pw.Text(referenceNumber, style: const pw.TextStyle(fontSize: 9.5)),
                              ],
                            ),
                          ],
                          if (remarks.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Row(
                              children: [
                                pw.Text('Remarks: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                                pw.Expanded(child: pw.Text(remarks, style: const pw.TextStyle(fontSize: 9.5))),
                              ],
                            ),
                          ],
                          pw.SizedBox(height: 4),
                          pw.Divider(thickness: 0.5),
                          pw.Row(
                            children: [
                              pw.Text('Remaining Due Balance: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red900)),
                              pw.Text('Rs. ${remainingBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red900)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Bottom Signature Section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Received with thanks by Cash/UPI/Cheque', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        pw.Text('Computer Generated Payment Slip', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static String _numberToWords(int number) {
    if (number <= 0) return 'Zero Rupees Only';
    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convert(int n) {
      if (n < 20) return units[n];
      if (n < 100) return '${tens[n ~/ 10]} ${units[n % 10]}'.trim();
      if (n < 1000) return '${units[n ~/ 100]} Hundred ${convert(n % 100)}'.trim();
      if (n < 100000) return '${convert(n ~/ 1000)} Thousand ${convert(n % 1000)}'.trim();
      if (n < 10000000) return '${convert(n ~/ 100000)} Lakh ${convert(n % 100000)}'.trim();
      return '${convert(n ~/ 10000000)} Crore ${convert(n % 10000000)}'.trim();
    }

    return '${convert(number)} Rupees Only';
  }
}
