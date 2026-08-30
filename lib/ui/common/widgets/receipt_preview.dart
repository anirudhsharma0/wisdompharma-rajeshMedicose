import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/bill_model.dart';

class ReceiptPreview extends StatelessWidget {
  final BillModel bill;

  const ReceiptPreview({super.key, required this.bill});

  String _numberToWords(double amount) {
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MM-yyyy');
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 1.2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header Grid
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 1.2)),
              ),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Left Details
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'M/s ${dashProvider.pharmacyName.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          dashProvider.storeAddress,
                          style: const TextStyle(color: Colors.black87, fontSize: 10, height: 1.3),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'D.L. No: 7970/7970-OBR   GST: ${dashProvider.gstin.isNotEmpty ? dashProvider.gstin : "N/A"}',
                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        if (bill.customerName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Customer: ${bill.customerName.toUpperCase()} ${bill.customerPhone.isNotEmpty ? "(${bill.customerPhone})" : ""}',
                            style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Header Right Box
                  Container(
                    width: 220,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1),
                      color: Colors.grey.shade100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'GST INVOICE - ${bill.paymentMode == "Credit" ? "CREDIT" : "CASH"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                          ),
                        ),
                        const Divider(color: Colors.black, height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Invoice No.:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            Text(dateFormat.format(bill.createdAt), style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Due Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            Text(dateFormat.format(bill.createdAt), style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 14 Column Grid Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 780,
                child: Column(
                  children: [
                    // Table Header Row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        border: const Border(
                          top: BorderSide(color: Colors.black, width: 1),
                          bottom: BorderSide(color: Colors.black, width: 1),
                        ),
                      ),
                      child: Row(
                        children: const [
                          _HeaderCell('Sn.', width: 25, align: TextAlign.center),
                          _HeaderCell('Qty.', width: 35, align: TextAlign.right),
                          _HeaderCell('Free', width: 32, align: TextAlign.right),
                          _HeaderCell('Pack', width: 55, align: TextAlign.left),
                          _HeaderCell('Product', width: 140, align: TextAlign.left),
                          _HeaderCell('Batch', width: 75, align: TextAlign.center),
                          _HeaderCell('Exp.', width: 45, align: TextAlign.center),
                          _HeaderCell('HSN', width: 60, align: TextAlign.center),
                          _HeaderCell('Mrp', width: 50, align: TextAlign.right),
                          _HeaderCell('Rate', width: 50, align: TextAlign.right),
                          _HeaderCell('Sch. %', width: 42, align: TextAlign.right),
                          _HeaderCell('Dis. %', width: 42, align: TextAlign.right),
                          _HeaderCell('GST %', width: 42, align: TextAlign.right),
                          _HeaderCell('Amount', width: 65, align: TextAlign.right),
                        ],
                      ),
                    ),

                    // Table Items Rows
                    ...bill.items.asMap().entries.map((entry) {
                      int idx = entry.key + 1;
                      BillItem item = entry.value;
                      // Line Amount = Gross Amount = Rate * Qty
                      double grossAmount = item.grossAmount;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            _DataCell('$idx.', width: 25, align: TextAlign.center),
                            _DataCell('${item.quantity}', width: 35, align: TextAlign.right, isBold: true),
                            _DataCell('${item.freeQty}', width: 32, align: TextAlign.right),
                            _DataCell(item.pack.isNotEmpty ? item.pack : '1s', width: 55, align: TextAlign.left),
                            _DataCell(item.medicineName, width: 140, align: TextAlign.left, isBold: true),
                            _DataCell(item.batchNumber, width: 75, align: TextAlign.center),
                            _DataCell(item.expiryDate, width: 45, align: TextAlign.center),
                            _DataCell(item.hsn.isNotEmpty ? item.hsn : '3004', width: 60, align: TextAlign.center),
                            _DataCell(item.mrp.toStringAsFixed(2), width: 50, align: TextAlign.right),
                            _DataCell(item.salePrice.toStringAsFixed(2), width: 50, align: TextAlign.right, isBold: true),
                            _DataCell('${item.schemeDiscPercent.toStringAsFixed(2)}%', width: 42, align: TextAlign.right),
                            _DataCell('${item.tradeDiscPercent.toStringAsFixed(2)}%', width: 42, align: TextAlign.right),
                            _DataCell('${item.gstPercent.toStringAsFixed(1)}%', width: 42, align: TextAlign.right),
                            _DataCell(grossAmount.toStringAsFixed(2), width: 65, align: TextAlign.right, isBold: true),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Account Balance Bar (Khata Summary Strip)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CASH RECEIVED: 0.00',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black),
                  ),
                  Text(
                    'PREV. BAL.: ${bill.customerPrevBalance.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black),
                  ),
                  Text(
                    'CURR. BILL: ${bill.netAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black),
                  ),
                  Text(
                    'TOTAL O/S: ${bill.totalOutstanding.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Bottom Summary Section Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bottom Left: GST Tax Slabs Grid Table
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.8)),
                    child: Column(
                      children: [
                        Container(
                          color: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                          child: Row(
                            children: const [
                              Expanded(flex: 3, child: Text('GST%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                              Expanded(flex: 4, child: Text('TAXABLE AMT.', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                              Expanded(flex: 4, child: Text('TAX AMT.', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                            ],
                          ),
                        ),
                        _GstGridRow('GST 5.00', gst5Taxable, gst5Tax),
                        _GstGridRow('GST 12.00', gst12Taxable, gst12Tax),
                        _GstGridRow('GST 18.00', gst18Taxable, gst18Tax),
                        _GstGridRow('EXEMPT', exemptTaxable, 0.0),
                        Container(
                          color: Colors.grey.shade200,
                          child: _GstGridRow('TOTAL', totalTaxable, totalTax, isBold: true),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Bottom Middle: Total Items & Total Qty
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Items :-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('${bill.totalItemsCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Qty :-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('${bill.totalQtyCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Bottom Right: Financial Summary Totals
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.8)),
                    child: Column(
                      children: [
                        _FinancialRow('SUB TOTAL', bill.subTotal.toStringAsFixed(2)),
                        _FinancialRow('DISCOUNT', '-${bill.totalDiscount.toStringAsFixed(2)}', isRed: bill.totalDiscount > 0),
                        _FinancialRow('CGST PAYABLE', bill.cgstAmount.toStringAsFixed(2)),
                        _FinancialRow('SGST PAYABLE', bill.sgstAmount.toStringAsFixed(2)),
                        _FinancialRow('ROUND OFF', bill.roundOff >= 0 ? '+${bill.roundOff.toStringAsFixed(2)}' : bill.roundOff.toStringAsFixed(2)),
                        const Divider(color: Colors.black, height: 6),
                        _FinancialRow('GRAND TOTAL', '₹${bill.netAmount.toStringAsFixed(2)}', isGrandTotal: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Container(height: 1, color: Colors.black),
            const SizedBox(height: 6),

            // Footer Section: Amount in Words, Bank Details, Auth Sign
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _numberToWords(bill.netAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Terms & Conditions:\nGoods once sold will not be taken back or exchanged. All disputes subject to Jurisdiction only.',
                        style: TextStyle(fontSize: 8, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: Colors.black45, width: 0.8)),
                      child: const Text('Our Bank Detail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                    ),
                  ),
                ),

                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('For ${dashProvider.pharmacyName.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                      const SizedBox(height: 20),
                      const Text('Auth. Sign.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;

  const _HeaderCell(this.text, {required this.width, required this.align});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;
  final bool isBold;

  const _DataCell(this.text, {required this.width, required this.align, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          color: Colors.black,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _GstGridRow extends StatelessWidget {
  final String label;
  final double taxable;
  final double tax;
  final bool isBold;

  const _GstGridRow(this.label, this.taxable, this.tax, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: TextStyle(fontSize: 8.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Expanded(flex: 4, child: Text(taxable.toStringAsFixed(2), textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Expanded(flex: 4, child: Text(tax.toStringAsFixed(2), textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isRed;
  final bool isGrandTotal;

  const _FinancialRow(this.label, this.value, {this.isRed = false, this.isGrandTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isGrandTotal ? 11 : 9.5,
              color: isGrandTotal ? Colors.black : Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isGrandTotal ? 12 : 9.5,
              color: isRed ? Colors.red.shade700 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}


