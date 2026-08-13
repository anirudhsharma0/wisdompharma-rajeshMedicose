import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/medicine_master_model.dart';
import '../../../data/services/sqlite_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty || rawValue == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = rawValue;
    });

    // Parse GS1 2D Data Matrix or standard barcode
    final parsedData = _parseMedicalBarcode(rawValue);

    // Search in SQLite & Active Inventory
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);
    InventoryModel? matchedInventory;

    // Check existing stock by batch or name
    for (var item in dashProvider.inventory) {
      if (item.batchNumber.toLowerCase() == parsedData['batch']?.toLowerCase() ||
          (parsedData['name'] != null &&
              !RegExp(r'^\d+$').hasMatch(parsedData['name']!) &&
              item.medicineName.toLowerCase().contains(parsedData['name']!.toLowerCase()))) {
        matchedInventory = item;
        break;
      }
    }

    // 1. Check Smart Barcode Memory (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('barcode_name_$rawValue');
    final savedMrp = prefs.getDouble('barcode_mrp_$rawValue');
    final savedSale = prefs.getDouble('barcode_sale_$rawValue');
    final savedCost = prefs.getDouble('barcode_cost_$rawValue');

    String detectedBrandName = savedName ?? parsedData['name'] ?? '';

    // 2. If not saved in Memory & name is numeric, search in 2.5 Lakh Medicine DB
    if (savedName == null && (detectedBrandName.isEmpty || RegExp(r'^\d+$').hasMatch(detectedBrandName))) {
      try {
        final masterResults = await SqliteService.instance.searchMedicines(rawValue);
        if (masterResults.isNotEmpty) {
          detectedBrandName = masterResults.first.medicineName;
        } else {
          detectedBrandName = ''; // Leave blank so user types real name
        }
      } catch (_) {
        detectedBrandName = '';
      }
    }

    if (!mounted) return;
    parsedData['name'] = detectedBrandName;
    if (savedMrp != null) parsedData['mrp'] = savedMrp.toString();
    if (savedSale != null) parsedData['sale'] = savedSale.toString();
    if (savedCost != null) parsedData['cost'] = savedCost.toString();

    // Show Scanned Result Dialog
    if (mounted) {
      await _showScannedResultSheet(context, parsedData, matchedInventory, dashProvider);
    }

    setState(() {
      _isProcessing = false;
    });
  }

  Map<String, String> _parseMedicalBarcode(String code) {
    String name = code;
    String batch = 'BATCH-${DateTime.now().year % 100}${DateTime.now().month}';
    String expiry = '${DateTime.now().year + 2}-${DateTime.now().month.toString().padLeft(2, '0')}';
    String gtin = '';

    // Handle GS1 2D Data Matrix format (01)GTIN(17)YYMMDD(10)BATCH
    if (code.contains('(01)') || code.startsWith('01')) {
      try {
        final gtinMatch = RegExp(r'\(01\)(\d{14})').firstMatch(code);
        if (gtinMatch != null) gtin = gtinMatch.group(1) ?? '';

        final expMatch = RegExp(r'\(17\)(\d{6})').firstMatch(code);
        if (expMatch != null) {
          final expStr = expMatch.group(1)!;
          expiry = '20${expStr.substring(0, 2)}-${expStr.substring(2, 4)}';
        }

        final batchMatch = RegExp(r'\(10\)([A-Za-z0-9]+)').firstMatch(code);
        if (batchMatch != null) {
          batch = batchMatch.group(1)!;
        }
      } catch (_) {}
    } else {
      // Standard 1D barcode or plain text
      name = code;
    }

    return {
      'raw': code,
      'name': name,
      'batch': batch,
      'expiry': expiry,
      'gtin': gtin,
    };
  }

  Future<void> _showScannedResultSheet(
    BuildContext context,
    Map<String, String> data,
    InventoryModel? existingStock,
    DashboardProvider provider,
  ) async {
    final qtyController = TextEditingController(text: '10');
    final mrpController = TextEditingController(text: existingStock != null ? existingStock.mrp.toString() : '100.0');
    final salePriceController = TextEditingController(text: existingStock != null ? existingStock.salePrice.toString() : '90.0');
    final purchasePriceController = TextEditingController(text: existingStock != null ? existingStock.purchasePrice.toString() : '75.0');
    final nameController = TextEditingController(text: data['name']);
    final batchController = TextEditingController(text: data['batch']);
    final expiryController = TextEditingController(text: data['expiry']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('QR Code Scanned Successfully', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                          Text('Code: ${data['raw']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (existingStock != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Matched existing stock: ${existingStock.medicineName} (Qty: ${existingStock.quantity} packs available)',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                const Text('Medicine Brand Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Autocomplete<MedicineMasterModel>(
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.length < 2) {
                      return const Iterable<MedicineMasterModel>.empty();
                    }
                    return await SqliteService.instance.searchMedicines(textEditingValue.text);
                  },
                  displayStringForOption: (MedicineMasterModel option) => option.medicineName,
                  onSelected: (MedicineMasterModel selection) {
                    nameController.text = selection.medicineName;
                    mrpController.text = selection.mrp.toStringAsFixed(2);
                    salePriceController.text = (selection.mrp * 0.9).toStringAsFixed(2);
                    purchasePriceController.text = (selection.mrp * 0.75).toStringAsFixed(2);
                  },
                  fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
                    if (textCtrl.text.isEmpty && nameController.text.isNotEmpty) {
                      textCtrl.text = nameController.text;
                    }
                    textCtrl.addListener(() {
                      nameController.text = textCtrl.text;
                    });
                    return TextField(
                      controller: textCtrl,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Type brand name (e.g. Crocin, Liv52)...',
                        prefixIcon: const Icon(Icons.medication, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Batch No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: batchController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expiry (YYYY-MM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: expiryController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Add Stock Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cost Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: purchasePriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Selling Price (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: salePriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max MRP (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: mrpController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_task),
                  label: const Text('Add Scanned Stock to Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final batch = batchController.text.trim();
                    final exp = expiryController.text.trim();
                    final qty = int.tryParse(qtyController.text.trim()) ?? 10;
                    final mrp = double.tryParse(mrpController.text.trim()) ?? 100.0;
                    final sale = double.tryParse(salePriceController.text.trim()) ?? 90.0;
                    final cost = double.tryParse(purchasePriceController.text.trim()) ?? 75.0;

                    if (name.isEmpty || batch.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter Medicine Name & Batch Number')),
                      );
                      return;
                    }

                    // Save Barcode Memory Mapping for future 1-click scans
                    final rawCode = data['raw'];
                    if (rawCode != null && rawCode.isNotEmpty) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('barcode_name_$rawCode', name);
                      await prefs.setDouble('barcode_mrp_$rawCode', mrp);
                      await prefs.setDouble('barcode_sale_$rawCode', sale);
                      await prefs.setDouble('barcode_cost_$rawCode', cost);
                    }

                    await provider.addInventory(InventoryModel(
                      medicineName: name,
                      batchNumber: batch,
                      expiryDate: exp,
                      quantity: qty,
                      mrp: mrp,
                      salePrice: sale,
                      purchasePrice: cost,
                    ));

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('✅ Added $qty packs of $name (Batch $batch) to stock!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR / Barcode Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            tooltip: 'Toggle Flashlight',
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            tooltip: 'Switch Camera',
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          // Target Scanner Overlay Box
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(20),
                color: Colors.transparent,
              ),
              child: Stack(
                children: const [
                  Align(
                    alignment: Alignment.center,
                    child: Divider(color: Colors.redAccent, thickness: 2),
                  ),
                ],
              ),
            ),
          ),
          // Top Helper Text
          Positioned(
            top: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Point camera at Medicine Barcode or GS1 QR Code',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
