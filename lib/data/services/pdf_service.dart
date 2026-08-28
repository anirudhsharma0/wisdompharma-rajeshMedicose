import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/voucher_model.dart';
import '../models/customer_model.dart';

class PdfService {
  /// Helper to convert numbers to Indian Rupee Words
  static String _numberToWords(double amount) {
    int total = amount.round();
    if (total <= 0) return 'Zero Rupees Only';

    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convertLessThanThousand(int n) {
      if (n == 0) return '';
      if (n < 20) return units[n];
      if (n < 100) return '${tens[n ~/ 10]} ${units[n % 10]}'.trim();
      return '${units[n ~/ 100]} Hundred ${convertLessThanThousand(n % 100)}'.trim();
    }

    if (total < 1000) return 'Rs. ${convertLessThanThousand(total)} Only';
    if (total < 100000) {
      return 'Rs. ${convertLessThanThousand(total ~/ 1000)} Thousand ${convertLessThanThousand(total % 1000)} Only'.trim();
    }
    if (total < 10000000) {
      return 'Rs. ${convertLessThanThousand(total ~/ 100000)} Lakh ${convertLessThanThousand(total % 100000)} Only'.trim();
    }
    return 'Rs. ${total.toStringAsFixed(0)} Only';
  }

  /// Build full A4 / A5 14-column GST Invoice document layout matching sample printed bill
  static pw.Document _buildInvoicePdfDocument(
    BillModel bill, {
    String? pharmacyName,
    String? storeAddress,
    String? gstin,
  }) {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');
    final pName = (pharmacyName != null && pharmacyName.trim().isNotEmpty)
        ? pharmacyName
        : 'Rajesh Medicose';
    final pAddress = (storeAddress != null && storeAddress.trim().isNotEmpty)
        ? storeAddress
        : 'VPO Chaharwala (Sirsa) 125110';
    final pGstin = (gstin != null && gstin.trim().isNotEmpty) ? gstin.trim() : '23AAAAA1111A1Z1';

    // Group GST Slabs (5%, 12%, 18%, Exempt)
    double gst5Taxable = 0.0, gst5Tax = 0.0;
    double gst12Taxable = 0.0, gst12Tax = 0.0;
    double gst18Taxable = 0.0, gst18Tax = 0.0;
    double exemptTaxable = 0.0;

    for (var item in bill.items) {
      double lineTaxable = item.lineTaxableAmount;
      if (item.gstPercent == 5.0) {
        gst5Taxable += lineTaxable;
        gst5Tax += item.lineGstAmount;
      } else if (item.gstPercent == 12.0) {
        gst12Taxable += lineTaxable;
        gst12Tax += item.lineGstAmount;
      } else if (item.gstPercent == 18.0) {
        gst18Taxable += lineTaxable;
        gst18Tax += item.lineGstAmount;
      } else if (item.gstPercent == 0.0) {
        exemptTaxable += lineTaxable;
      }
    }

    if (bill.items.isEmpty && bill.gstAmount > 0) {
      if (bill.gstPercentage == 5.0) {
        gst5Taxable = bill.taxableAmount;
        gst5Tax = bill.gstAmount;
      } else if (bill.gstPercentage == 12.0) {
        gst12Taxable = bill.taxableAmount;
        gst12Tax = bill.gstAmount;
      } else if (bill.gstPercentage == 18.0) {
        gst18Taxable = bill.taxableAmount;
        gst18Tax = bill.gstAmount;
      }
    }

    double totalTaxable = gst5Taxable + gst12Taxable + gst18Taxable + exemptTaxable;
    double totalTax = gst5Tax + gst12Tax + gst18Tax;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Section
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 1)),
                ),
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'M/s ${pName.toUpperCase()}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(pAddress, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(
                            'D.L. No: 7970/7970-OBR   GST: $pGstin',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                          if (bill.customerName.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Customer: ${bill.customerName.toUpperCase()} ${bill.customerPhone.isNotEmpty ? "(${bill.customerPhone})" : ""}',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 180,
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Center(
                            child: pw.Text(
                              'GST INVOICE - ${bill.paymentMode == "Credit" ? "CREDIT" : "CASH"}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                            ),
                          ),
                          pw.Divider(thickness: 0.5),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Invoice No.:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                              pw.Text(bill.billNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                              pw.Text(dateFormat.format(bill.createdAt), style: const pw.TextStyle(fontSize: 8)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Due Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                              pw.Text(dateFormat.format(bill.createdAt), style: const pw.TextStyle(fontSize: 8)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),

              // 14 Column Table Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 0.8),
                    bottom: pw.BorderSide(width: 0.8),
                  ),
                ),
                child: pw.Row(
                  children: [
                    _pdfCell('Sn.', width: 20, align: pw.TextAlign.center, isHeader: true),
                    _pdfCell('Qty.', width: 25, align: pw.TextAlign.right, isHeader: true),
                    _pdfCell('Free', width: 25, align: pw.TextAlign.right, isHeader: true),
                    _pdfCell('Pack', width: 45, align: pw.TextAlign.left, isHeader: true),
                    _pdfCell('Product', width: 120, align: pw.TextAlign.left, isHeader: true),
                    _pdfCell('Batch', width: 60, align: pw.TextAlign.center, isHeader: true),
                    _pdfCell('Exp.', width: 35, align: pw.TextAlign.center, isHeader: true),
                    _pdfCell('HSN', width: 45, align: pw.TextAlign.center, isHeader: true),
                    _pdfCell('Mrp', width: 40, align: pw.TextAlign.right, isHeader: true),
                    _pdfCell('Rate', width: 40, align: pw.TextAlign.right, isHeader: true),
                    _pdfCell('Sch.%', width: 35, align: pw.TextAlign.right, isHeader: true),
                    _pdfCell('Dis.%', width: 35, align: pw.TextAlign.right, isHeader: true),
                    _pdfCell('GST%', width: 35, align: pw.TextAlign.right, isHeader: true),
                    _pdfCell('Amount', width: 55, align: pw.TextAlign.right, isHeader: true),
                  ],
                ),
              ),

              // Table Item Rows
              ...bill.items.asMap().entries.map((entry) {
                int idx = entry.key + 1;
                BillItem item = entry.value;
                double gross = item.grossAmount; // Line Amount = Rate * Qty

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.3, color: PdfColors.grey400)),
                  ),
                  child: pw.Row(
                    children: [
                      _pdfCell('$idx.', width: 20, align: pw.TextAlign.center),
                      _pdfCell('${item.quantity}', width: 25, align: pw.TextAlign.right, isBold: true),
                      _pdfCell('${item.freeQty}', width: 25, align: pw.TextAlign.right),
                      _pdfCell(item.pack.isNotEmpty ? item.pack : '1s', width: 45, align: pw.TextAlign.left),
                      _pdfCell(item.medicineName, width: 120, align: pw.TextAlign.left, isBold: true),
                      _pdfCell(item.batchNumber, width: 60, align: pw.TextAlign.center),
                      _pdfCell(item.expiryDate, width: 35, align: pw.TextAlign.center),
                      _pdfCell(item.hsn.isNotEmpty ? item.hsn : '3004', width: 45, align: pw.TextAlign.center),
                      _pdfCell(item.mrp.toStringAsFixed(2), width: 40, align: pw.TextAlign.right),
                      _pdfCell(item.salePrice.toStringAsFixed(2), width: 40, align: pw.TextAlign.right, isBold: true),
                      _pdfCell('${item.schemeDiscPercent.toStringAsFixed(1)}%', width: 35, align: pw.TextAlign.right),
                      _pdfCell('${item.tradeDiscPercent.toStringAsFixed(1)}%', width: 35, align: pw.TextAlign.right),
                      _pdfCell('${item.gstPercent.toStringAsFixed(1)}%', width: 35, align: pw.TextAlign.right),
                      _pdfCell(gross.toStringAsFixed(2), width: 55, align: pw.TextAlign.right, isBold: true),
                    ],
                  ),
                );
              }),

              pw.Spacer(),

              // Khata Account Balance Bar
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CASH RECEIVED: 0.00', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text('PREV. BAL.: ${bill.customerPrevBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text('CURR. BILL: ${bill.netAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text('TOTAL O/S: ${bill.totalOutstanding.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),

              // Bottom Summary Panels
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // GST Tax Table Box
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                      child: pw.Column(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                            color: PdfColors.grey300,
                            child: pw.Row(
                              children: [
                                pw.Expanded(flex: 3, child: pw.Text('GST%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7))),
                                pw.Expanded(flex: 4, child: pw.Text('TAXABLE AMT.', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7))),
                                pw.Expanded(flex: 4, child: pw.Text('TAX AMT.', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7))),
                              ],
                            ),
                          ),
                          _pdfGstRow('GST 5.00', gst5Taxable, gst5Tax),
                          _pdfGstRow('GST 12.00', gst12Taxable, gst12Tax),
                          _pdfGstRow('GST 18.00', gst18Taxable, gst18Tax),
                          _pdfGstRow('EXEMPT', exemptTaxable, 0.0),
                          _pdfGstRow('TOTAL', totalTaxable, totalTax, isBold: true),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 6),

                  // Total Items & Qty Box
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Total Items :-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                              pw.Text('${bill.totalItemsCount}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Total Qty :-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                              pw.Text('${bill.totalQtyCount}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 6),

                  // Financial Totals Box
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                      child: pw.Column(
                        children: [
                          _pdfFinRow('SUB TOTAL', bill.subTotal.toStringAsFixed(2)),
                          if (bill.totalSchemeDiscount > 0)
                            _pdfFinRow('SCHEME AMT', '-${bill.totalSchemeDiscount.toStringAsFixed(2)}'),
                          _pdfFinRow('DISCOUNT', '-${(bill.totalSchemeDiscount > 0 ? bill.totalTradeDiscount : bill.totalDiscount).toStringAsFixed(2)}'),
                          _pdfFinRow('CGST PAYABLE', bill.cgstAmount.toStringAsFixed(2)),
                          _pdfFinRow('SGST PAYABLE', bill.sgstAmount.toStringAsFixed(2)),
                          _pdfFinRow('ROUND OFF', bill.roundOff >= 0 ? '+${bill.roundOff.toStringAsFixed(2)}' : bill.roundOff.toStringAsFixed(2)),
                          pw.Divider(thickness: 0.5),
                          _pdfFinRow('GRAND TOTAL', 'Rs.${bill.netAmount.toStringAsFixed(2)}', isBold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // Footer Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(_numberToWords(bill.netAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Terms & Conditions:\nGoods once sold will not be taken back or exchanged. All disputes subject to Jurisdiction only.',
                          style: const pw.TextStyle(fontSize: 6.5),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Center(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                        child: pw.Text('Our Bank Detail', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('For ${pName.toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                        pw.SizedBox(height: 14),
                        pw.Text('Auth. Sign.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  static pw.Widget _pdfCell(String text, {required double width, required pw.TextAlign align, bool isHeader = false, bool isBold = false}) {
    return pw.SizedBox(
      width: width,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : 7,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _pdfGstRow(String label, double taxable, double tax, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 3, child: pw.Text(label, style: pw.TextStyle(fontSize: 6.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Expanded(flex: 4, child: pw.Text(taxable.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Expanded(flex: 4, child: pw.Text(tax.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        ],
      ),
    );
  }

  static pw.Widget _pdfFinRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: isBold ? 8 : 7, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: isBold ? 8.5 : 7, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  /// Share receipt PDF via native share sheet (WhatsApp, Email, etc.)
  static Future<void> shareReceipt(
    BillModel bill, {
    String? pharmacyName,
    String? storeAddress,
    String? gstin,
  }) async {
    final doc = _buildInvoicePdfDocument(bill, pharmacyName: pharmacyName, storeAddress: storeAddress, gstin: gstin);
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

  /// Generate and open OS print preview dialog for GST Invoice printing
  static Future<void> printReceipt(
    BillModel bill, {
    String? pharmacyName,
    String? storeAddress,
    String? gstin,
  }) async {
    final doc = _buildInvoicePdfDocument(bill, pharmacyName: pharmacyName, storeAddress: storeAddress, gstin: gstin);
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

    final amountInWords = _numberToWords(amountPaid.toDouble());

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

  /// Generate A4 Wholesale GST Credit Invoice PDF (Matching RAM MEDICAL AGENCY Bill Format)
  static Future<Uint8List> generateWholesaleInvoicePdf({
    required String invoiceNumber,
    required DateTime date,
    required String partyName,
    required String partyAddress,
    required List<Map<String, dynamic>> items,
    required double cashReceived,
    required double prevBalance,
    required double currBill,
    required double totalOutstanding,
    required double subTotal,
    required double discount,
    required double gst5Taxable,
    required double gst5Tax,
    required double gst12Taxable,
    required double gst12Tax,
    required double gst18Taxable,
    required double gst18Tax,
    required double exemptTaxable,
    required double totalTaxable,
    required double totalTax,
    required double cgst,
    required double sgst,
    required double roundOff,
    required double grandTotal,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopGstin,
    String? shopDlNo,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');

    final sName = (shopName != null && shopName.trim().isNotEmpty) ? shopName.trim() : 'M/s RAJESH MEDICOSE';
    final sAddress = (shopAddress != null && shopAddress.trim().isNotEmpty) ? shopAddress.trim() : 'CHARWALA, CHARWALA';
    final sPhone = (shopPhone != null && shopPhone.trim().isNotEmpty) ? shopPhone.trim() : 'Ph.No.: 9050524678';
    final sDlGst = 'D.L.No. : ${shopDlNo ?? "7970/7970-OBR"}  |  GST : ${shopGstin ?? "06AAAAA0000A1Z5"}';

    int totalQty = 0;
    for (var it in items) {
      totalQty += ((it['qty'] as num?)?.toInt() ?? 1);
    }
    final totalItems = items.length;
    final amountInWords = _numberToWords(grandTotal.toDouble());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            sName,
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(sAddress, style: const pw.TextStyle(fontSize: 9)),
                          pw.Text(sPhone, style: const pw.TextStyle(fontSize: 9)),
                          pw.Text(sDlGst, style: const pw.TextStyle(fontSize: 8.5)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Agency / Supplier: $partyName',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                          if (partyAddress.isNotEmpty)
                            pw.Text(partyAddress, style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'GST INVOICE - CREDIT',
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Invoice No.:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.Text(invoiceNumber, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Date:', style: const pw.TextStyle(fontSize: 9)),
                                pw.Text(dateFormat.format(date), style: const pw.TextStyle(fontSize: 9)),
                              ],
                            ),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Due Date:', style: const pw.TextStyle(fontSize: 9)),
                                pw.Text(dateFormat.format(date), style: const pw.TextStyle(fontSize: 9)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                // Items Table Header
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(24),  // Sn
                    1: const pw.FixedColumnWidth(30),  // Qty
                    2: const pw.FixedColumnWidth(26),  // Free
                    3: const pw.FixedColumnWidth(48),  // Pack
                    4: const pw.FlexColumnWidth(4),   // Product
                    5: const pw.FlexColumnWidth(2),   // Batch
                    6: const pw.FixedColumnWidth(38),  // Exp
                    7: const pw.FixedColumnWidth(48),  // HSN
                    8: const pw.FixedColumnWidth(45),  // MRP
                    9: const pw.FixedColumnWidth(45),  // Rate
                    10: const pw.FixedColumnWidth(30), // Sch.
                    11: const pw.FixedColumnWidth(34), // Dis%
                    12: const pw.FixedColumnWidth(34), // GST%
                    13: const pw.FixedColumnWidth(55), // Amount
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Sn.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Qty.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Free', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Pack', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Product', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Batch', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Exp.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('HSN', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('MRP', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Rate', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Sch.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Dis.%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('GST%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final it = entry.value;
                      final q = (it['qty'] as num?)?.toInt() ?? 1;
                      final f = (it['free'] as num?)?.toInt() ?? 0;
                      final p = (it['pack'] ?? '1S').toString();
                      final name = (it['name'] ?? 'Item').toString();
                      final b = (it['batch'] ?? '-').toString();
                      final exp = (it['exp'] ?? '-').toString();
                      final hsn = (it['hsn'] ?? '3004').toString();
                      final mrp = (it['mrp'] as num?)?.toDouble() ?? 0.0;
                      final rate = (it['rate'] as num?)?.toDouble() ?? 0.0;
                      final sch = (it['sch'] as num?)?.toDouble() ?? 0.0;
                      final dis = (it['dis'] as num?)?.toDouble() ?? 0.0;
                      final gst = (it['gst'] as num?)?.toDouble() ?? 5.0;
                      final amt = (it['amount'] as num?)?.toDouble() ?? (q * rate);

                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text('$q', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text('$f', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(p, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(b, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(exp, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(hsn, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(mrp.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(rate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(sch.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(dis.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(gst.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(amt.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        ],
                      );
                    }),
                  ],
                ),

                pw.Spacer(),

                // Status Bar Row (CASH RECEIVED | PREV. BAL. | CURR. BILL | TOTAL O/S)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.8),
                    color: PdfColors.grey200,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CASH RECEIVED: ${cashReceived.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('PREV. BAL.: ${prevBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('CURR. BILL: ${currBill.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('TOTAL O/S: ${totalOutstanding.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ),

                // Bottom Grid Section (GST Matrix + Items/Qty + Totals Box)
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left: GST Breakdown Matrix
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Table(
                            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                            children: [
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                                children: [
                                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('GST%', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('TAXABLE AMT.', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('TAX AMT.', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                                ],
                              ),
                              pw.TableRow(children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('GST 5.00', style: const pw.TextStyle(fontSize: 7.5))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(gst5Taxable.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7.5))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(gst5Tax.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7.5))),
                              ]),
                              pw.TableRow(children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('GST 12.00', style: const pw.TextStyle(fontSize: 7.5))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(gst12Taxable.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7.5))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(gst12Tax.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7.5))),
                              ]),
                              pw.TableRow(children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('GST 18.00', style: const pw.TextStyle(fontSize: 7.5))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(gst18Taxable.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7.5))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(gst18Tax.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7.5))),
                              ]),
                              pw.TableRow(children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('EXEMPT', style: const pw.TextStyle(fontSize: 7.5))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(exemptTaxable.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 7.5))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('0.00', style: const pw.TextStyle(fontSize: 7.5))),
                              ]),
                              pw.TableRow(children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(totalTaxable.toStringAsFixed(2), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                                pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(totalTax.toStringAsFixed(2), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                              ]),
                            ],
                          ),
                        ),
                      ),

                      // Middle: Items Count & Qty Count
                      pw.Expanded(
                        flex: 3,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Total Items :-', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                  pw.Text('$totalItems', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Total Qty :-', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                  pw.Text('$totalQty', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right: Financial Summary Totals
                      pw.Expanded(
                        flex: 4,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('SUB TOTAL', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                  pw.Text(subTotal.toStringAsFixed(2), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('DISCOUNT', style: const pw.TextStyle(fontSize: 8.5)),
                                  pw.Text(discount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8.5)),
                                ],
                              ),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('CGST PAYABLE', style: const pw.TextStyle(fontSize: 8.5)),
                                  pw.Text(cgst.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8.5)),
                                ],
                              ),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('SGST PAYABLE', style: const pw.TextStyle(fontSize: 8.5)),
                                  pw.Text(sgst.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8.5)),
                                ],
                              ),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('ROUND OFF', style: const pw.TextStyle(fontSize: 8.5)),
                                  pw.Text(roundOff.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8.5)),
                                ],
                              ),
                              pw.Divider(thickness: 0.5),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  pw.Text(grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer Box: Words, Terms & Conditions, Auth Signature
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Rs. ${amountInWords.isNotEmpty ? amountInWords : "Zero Rupees Only"}',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Goods once sold will not be taken back or exchanged.', style: const pw.TextStyle(fontSize: 7.5)),
                              pw.Text('All disputes subject to Jurisdiction only.', style: const pw.TextStyle(fontSize: 7.5)),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('For $partyName', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 12),
                              pw.Text('Auth. Sign.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}


