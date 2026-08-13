import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/bill_model.dart';

class ReceiptPreview extends StatelessWidget {
  final BillModel bill;

  const ReceiptPreview({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
            // Pharmacy Header
            Text(
              dashProvider.pharmacyName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dashProvider.storeAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (dashProvider.gstin.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'GSTIN: ${dashProvider.gstin}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildDivider(),
            const SizedBox(height: 8),

            // Bill metadata
            _buildRow('Bill No:', bill.billNumber),
            _buildRow('Date:', dateFormat.format(bill.createdAt)),
            _buildRow('Cust Name:', bill.customerName),
            if (bill.customerPhone.isNotEmpty)
              _buildRow('Cust Phone:', bill.customerPhone),
            _buildRow('Pay Mode:', bill.paymentMode == 'Credit' ? 'UDHAR' : bill.paymentMode.toUpperCase()),

            const SizedBox(height: 8),
            _buildDivider(),
            const SizedBox(height: 8),

            // Table Headers
            Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Item Description',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Batch/Exp',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildDivider(),
            const SizedBox(height: 8),

            // List of items
            ...bill.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.medicineName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'MRP: ₹${item.mrp.toStringAsFixed(2)}  Rate: ₹${item.salePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Text(
                              item.batchNumber,
                              style: const TextStyle(color: Colors.black, fontSize: 11),
                            ),
                            Text(
                              item.expiryDate,
                              style: const TextStyle(color: Colors.black54, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          item.quantity.toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.black, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${item.totalPrice.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),

            _buildDivider(),
            const SizedBox(height: 8),

            // Financial Summary
            _buildSummaryRow('Gross Total:', '₹${bill.totalAmount.toStringAsFixed(2)}'),
            if (bill.discount > 0)
              _buildSummaryRow('Discount:', '-₹${bill.discount.toStringAsFixed(2)}', isDiscount: true),
            if (bill.gstAmount > 0) ...[
              _buildSummaryRow('Taxable Amt:', '₹${(bill.totalAmount - bill.discount).toStringAsFixed(2)}'),
              _buildSummaryRow('GST (${bill.gstPercentage.toStringAsFixed(1)}%):', '+₹${bill.gstAmount.toStringAsFixed(2)}'),
            ],
            const SizedBox(height: 4),
            _buildSummaryRow(
              'NET AMOUNT:',
              '₹${bill.netAmount.toStringAsFixed(2)}',
              isBold: true,
              fontSize: 15,
            ),

            const SizedBox(height: 12),
            _buildDivider(),
            const SizedBox(height: 12),

            // Thank You Message
            const Text(
              'Thank You! Visit Again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Medicines once sold cannot be returned.\nTax Invoice - Retail Sale',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black26),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 12, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDiscount ? Colors.red.shade700 : Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 90,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isDiscount ? Colors.red.shade700 : Colors.black,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

