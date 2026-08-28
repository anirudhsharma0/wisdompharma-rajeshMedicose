import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/colors.dart';
import '../../../data/services/bill_ocr_service.dart';

import 'pending_bills_screen.dart';

class BillScannerScreen extends StatefulWidget {
  const BillScannerScreen({super.key});

  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen> {
  Uint8List? _selectedImageBytes;
  // ignore: unused_field
  String? _selectedImageName;
  bool _isScanning = false;
  String _statusText = '';
  ScannedBillModel? _scannedBill;

  // Header Controllers
  final _supplierController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _grandTotalController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNoController.dispose();
    _invoiceDateController.dispose();
    _grandTotalController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 90);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
        await _processImageScan(bytes);
      }
    } catch (e) {
      _showSnackBar('Error selecting image: $e', isError: true);
    }
  }

  Future<void> _pickFileFromDisk() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedImageBytes = file.bytes;
            _selectedImageName = file.name;
          });
          await _processImageScan(file.bytes!);
        }
      }
    } catch (e) {
      _showSnackBar('Error selecting file: $e', isError: true);
    }
  }

  Future<void> _processImageScan(Uint8List bytes) async {
    setState(() {
      _isScanning = true;
      _statusText = 'AI Analyzing Purchase Bill (Gemini AI)...';
    });

    try {
      final scannedBill = await BillOcrService.instance.scanBillImage(bytes);
      setState(() {
        _scannedBill = scannedBill;
        _supplierController.text = scannedBill.supplierName;
        _invoiceNoController.text = scannedBill.invoiceNumber;
        _invoiceDateController.text = scannedBill.invoiceDate;
        _grandTotalController.text = scannedBill.grandTotal.toStringAsFixed(2);
        _isScanning = false;
        _statusText = 'Scan Complete! ${scannedBill.items.length} items extracted.';
      });
      _showSnackBar('Successfully scanned ${scannedBill.items.length} items from bill!');
    } catch (e) {
      debugPrint('AI Scan Error: $e');
      final fallbackBill = ScannedBillModel(
        supplierName: 'PURCHASE AGENCY',
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        invoiceDate: '30/07/2026',
        grandTotal: 0.0,
        items: [
          ScannedBillItem(
            srNo: 1,
            productName: 'Sample Item (Edit Name)',
            pack: '10S',
            quantity: 1,
            batchNumber: 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
            expiryDate: '12/28',
            mrp: 100.0,
            purchaseRate: 80.0,
            netAmount: 80.0,
          )
        ],
      );
      final errorStr = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _scannedBill = fallbackBill;
        _supplierController.text = fallbackBill.supplierName;
        _invoiceNoController.text = fallbackBill.invoiceNumber;
        _invoiceDateController.text = fallbackBill.invoiceDate;
        _grandTotalController.text = fallbackBill.grandTotal.toStringAsFixed(2);
        _isScanning = false;
        _statusText = 'Scan Failed: $errorStr';
      });
      _showSnackBar('AI Scan Error: $errorStr', isError: true);
      
      final lowerErr = errorStr.toLowerCase();
      if (lowerErr.contains('key') || lowerErr.contains('400') || lowerErr.contains('403') || lowerErr.contains('unauthorized')) {
        _showApiKeyDialog(autoTriggeredByError: true);
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_scannedBill == null || _scannedBill!.items.isEmpty) {
      _showSnackBar('No scanned data available to export.', isError: true);
      return;
    }

    _syncHeaderData();

    try {
      final file = await BillOcrService.instance.generateExcelSheet(_scannedBill!);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.description, color: AppColors.emerald),
              SizedBox(width: 8),
              Text('Excel File Exported!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your purchase bill has been converted to an Excel sheet:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  file.path,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar('Error generating Excel file: $e', isError: true);
    }
  }

  Future<void> _sendToApprovalQueue() async {
    if (_scannedBill == null || _scannedBill!.items.isEmpty) {
      _showSnackBar('No scanned items to save.', isError: true);
      return;
    }

    _syncHeaderData();

    try {
      await BillOcrService.instance.savePendingBill(_scannedBill!);
      _showSnackBar('📩 Sent to Admin Approval Queue!');

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.mark_email_read, color: AppColors.emerald, size: 48),
          title: const Text('Sent to Desktop Admin Queue!'),
          content: Text(
            'Bill #${_scannedBill!.invoiceNumber.isNotEmpty ? _scannedBill!.invoiceNumber : "Scanned"} synced to Cloud Firestore.\n\n'
            '• Items Parsed: ${_scannedBill!.items.length}\n'
            '• Total Amount: ₹${_scannedBill!.grandTotal.toStringAsFixed(2)}\n\n'
            '💻 This pending bill is now visible on Desktop! The admin can select the supplier agency, manually edit items, and pre-fill into Purchase Bill.',
          ),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Open Admin Approval Queue'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PendingBillsScreen()),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar('Error sending to approval queue: $e', isError: true);
    }
  }

  void _syncHeaderData() {
    if (_scannedBill != null) {
      _scannedBill!.supplierName = _supplierController.text.trim();
      _scannedBill!.invoiceNumber = _invoiceNoController.text.trim();
      _scannedBill!.invoiceDate = _invoiceDateController.text.trim();
      _scannedBill!.grandTotal = double.tryParse(_grandTotalController.text) ?? _scannedBill!.grandTotal;
    }
  }

  void _showApiKeyDialog({bool autoTriggeredByError = false}) async {
    final currentKey = await BillOcrService.instance.getApiKey();
    final keyController = TextEditingController(text: currentKey);
    bool obscure = true;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.security, color: AppColors.teal),
              const SizedBox(width: 8),
              Text(autoTriggeredByError ? 'Set Gemini AI API Key' : 'Configure Gemini API Key'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (autoTriggeredByError)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: const Text(
                    '⚠️ Invalid or missing API Key. Please paste your Google Gemini API Key below to scan bills.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                  ),
                ),
              const Text(
                'Enter your Google Gemini API Key (starts with AIzaSy...):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keyController,
                obscureText: obscure,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Gemini API Key',
                  hintText: 'AIzaSy...',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: () async {
                final newKey = keyController.text.trim();
                await BillOcrService.instance.saveApiKey(newKey);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _showSnackBar('API Key updated successfully! Try scanning your bill now.');
              },
              child: const Text('Save Key', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : AppColors.emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📷 AI Purchase Bill Scanner & Excel Converter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_circle, color: Colors.amberAccent, size: 28),
            tooltip: 'Admin Pending Scanned Bills',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PendingBillsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Selection Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan Physical Purchase Bill / Photo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Click a photo or select an image of your distributor purchase bill. AI will extract all table rows & columns automatically into Excel and Stock!',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickFileFromDisk,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Upload Image / File'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Scanning progress indicator
            if (_isScanning)
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _statusText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_selectedImageBytes != null && !_isScanning)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_selectedImageBytes!, fit: BoxFit.contain),
                  ),
                ),
              ),

            // Extracted Header Information Card
            if (_scannedBill != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extracted Bill Details (Editable)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _supplierController,
                              decoration: const InputDecoration(
                                labelText: 'Supplier / Agency Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _invoiceNoController,
                              decoration: const InputDecoration(
                                labelText: 'Invoice Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _invoiceDateController,
                              decoration: const InputDecoration(
                                labelText: 'Invoice Date',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _grandTotalController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Grand Total (₹)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Calculation Engine Summary & Mode Toggle Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.teal.withAlpha(80)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.calculate, color: AppColors.teal, size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'Smart GST Calculation Breakdown',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.teal),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text('Taxable Table Column', style: TextStyle(fontSize: 12)),
                                    Switch(
                                      value: _scannedBill!.isAmountTaxable,
                                      activeColor: AppColors.teal,
                                      onChanged: (val) {
                                        setState(() {
                                          _scannedBill!.isAmountTaxable = val;
                                          for (var item in _scannedBill!.items) {
                                            item.netAmount = val ? item.taxableAmount : item.calculatedNet;
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryTile('Taxable Subtotal', '₹${_scannedBill!.calculatedTaxableTotal.toStringAsFixed(2)}'),
                                _buildSummaryTile('Total GST (CGST+SGST)', '₹${_scannedBill!.calculatedGstTotal.toStringAsFixed(2)}'),
                                _buildSummaryTile('Calculated Total', '₹${_scannedBill!.calculatedGrandTotal.toStringAsFixed(2)}'),
                                _buildSummaryTile('Round Off', '₹${_scannedBill!.roundOff.toStringAsFixed(2)}', color: Colors.orange.shade800),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Items Table Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Parsed Items (${_scannedBill!.items.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: AppColors.teal),
                            tooltip: 'Add Row',
                            onPressed: () {
                              setState(() {
                                _scannedBill!.items.add(ScannedBillItem(
                                  srNo: _scannedBill!.items.length + 1,
                                  productName: 'New Medicine',
                                  quantity: 1,
                                  batchNumber: 'BATCH-01',
                                  expiryDate: '12/28',
                                  mrp: 100.0,
                                  purchaseRate: 80.0,
                                  netAmount: 80.0,
                                ));
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                          columns: const [
                            DataColumn(label: Text('Sn', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Pack', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Batch', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Exp.', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Free', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('MRP (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Sch', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Dis %', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('GST %', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _scannedBill!.items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(Text('${idx + 1}')),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: TextFormField(
                                      initialValue: item.productName,
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => item.productName = val,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 70,
                                    child: TextFormField(
                                      initialValue: item.pack,
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => item.pack = val,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 90,
                                    child: TextFormField(
                                      initialValue: item.batchNumber,
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => item.batchNumber = val,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 60,
                                    child: TextFormField(
                                      initialValue: item.expiryDate,
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => item.expiryDate = val,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 50,
                                    child: TextFormField(
                                      initialValue: item.quantity.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => setState(() => item.quantity = int.tryParse(val) ?? item.quantity),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 50,
                                    child: TextFormField(
                                      initialValue: item.freeQty.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => setState(() => item.freeQty = int.tryParse(val) ?? item.freeQty),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 65,
                                    child: TextFormField(
                                      initialValue: item.mrp.toStringAsFixed(2),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => setState(() => item.mrp = double.tryParse(val) ?? item.mrp),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 65,
                                    child: TextFormField(
                                      initialValue: item.purchaseRate.toStringAsFixed(2),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => setState(() => item.purchaseRate = double.tryParse(val) ?? item.purchaseRate),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 50,
                                    child: TextFormField(
                                      initialValue: item.schemeDiscount.toStringAsFixed(1),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => setState(() => item.schemeDiscount = double.tryParse(val) ?? item.schemeDiscount),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 50,
                                    child: TextFormField(
                                      initialValue: item.discountPercent.toStringAsFixed(1),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => setState(() => item.discountPercent = double.tryParse(val) ?? item.discountPercent),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 50,
                                    child: TextFormField(
                                      initialValue: item.gstPercent.toStringAsFixed(1),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => setState(() => item.gstPercent = double.tryParse(val) ?? item.gstPercent),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 75,
                                    child: TextFormField(
                                      initialValue: item.netAmount.toStringAsFixed(2),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (val) => setState(() => item.netAmount = double.tryParse(val) ?? item.netAmount),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _scannedBill!.items.removeAt(idx);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons: Excel Export & Add to Stock
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportToExcel,
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Export to Excel (.xlsx)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sendToApprovalQueue,
                      icon: const Icon(Icons.mark_email_read),
                      label: const Text('📩 Send for Admin Approval'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? AppColors.slate800),
        ),
      ],
    );
  }
}
