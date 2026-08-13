import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/medicine_master_model.dart';
import '../../core/utils/platform_utils.dart';

class SqliteService {
  static final SqliteService instance = SqliteService._init();
  static Database? _database;
  String? _cachedTableName;

  SqliteService._init();

  Future<Database?> get database async {
    if (!PlatformUtils.isDesktop) {
      return null; // SQLite medicine master is Desktop-only
    }
    if (_database != null) return _database;
    _database = await _initDB();
    return _database;
  }

  Future<Database> _initDB() async {
    // Initialize FFI for Desktop
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbDirectory = await getApplicationDocumentsDirectory();
    final path = join(dbDirectory.path, 'medicines_master.db');

    // Check if database already exists in documents directory
    final exists = await databaseExists(path);

    if (!exists) {
      // Create path directory if it doesn't exist
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Try copying from assets
      try {
        ByteData data = await rootBundle.load('assets/database/medicines_master.db');
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        debugPrint('Medicines master DB copied from assets successfully.');
      } catch (e) {
        // If assets copy fails (e.g. file not yet placed in assets),
        // we initialize an empty database and seed it with sample Indian medicines.
        debugPrint('Medicines master DB not found in assets or copy failed ($e). Creating a seed database at: $path');
        final db = await openDatabase(path, version: 1, onCreate: _createDb);
        await _seedInitialData(db);
        return db;
      }
    }

    return await openDatabase(path);
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicine_master (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_name TEXT NOT NULL,
        composition TEXT,
        manufacturer TEXT,
        mrp REAL NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_medicine_name ON medicine_master (medicine_name)');
  }

  Future<void> _seedInitialData(Database db) async {
    final batch = db.batch();
    final sampleMedicines = [
      {'medicine_name': 'Paracetamol 650mg (Dolo)', 'composition': 'Paracetamol 650mg', 'manufacturer': 'Micro Labs Ltd', 'mrp': 30.0},
      {'medicine_name': 'Amoxicillin 500mg (Amoxil)', 'composition': 'Amoxicillin 500mg', 'manufacturer': 'GlaxoSmithKline', 'mrp': 85.5},
      {'medicine_name': 'Metformin 500mg (Glycomet)', 'composition': 'Metformin 500mg', 'manufacturer': 'USV Pvt Ltd', 'mrp': 22.0},
      {'medicine_name': 'Atorvastatin 10mg (Lipvas)', 'composition': 'Atorvastatin 10mg', 'manufacturer': 'Cipla Ltd', 'mrp': 70.0},
      {'medicine_name': 'Pantoprazole 40mg (Pan-40)', 'composition': 'Pantoprazole 40mg', 'manufacturer': 'Alkem Laboratories', 'mrp': 140.0},
      {'medicine_name': 'Cetirizine 10mg (Alerid)', 'composition': 'Cetirizine 10mg', 'manufacturer': 'Cipla Ltd', 'mrp': 18.0},
      {'medicine_name': 'Azithromycin 500mg (Azee)', 'composition': 'Azithromycin 500mg', 'manufacturer': 'Cian Healthcare', 'mrp': 119.0},
      {'medicine_name': 'Ibuprofen 400mg (Brufen)', 'composition': 'Ibuprofen 400mg', 'manufacturer': 'Abbott India', 'mrp': 15.0},
      {'medicine_name': 'Telmisartan 40mg (Telma)', 'composition': 'Telmisartan 40mg', 'manufacturer': 'Glenmark Pharmaceuticals', 'mrp': 92.0},
      {'medicine_name': 'Omeprazole 20mg (Omez)', 'composition': 'Omeprazole 20mg', 'manufacturer': 'Dr Reddy\'s Laboratories', 'mrp': 55.0},
      {'medicine_name': 'Amlodipine 5mg (Amlong)', 'composition': 'Amlodipine 5mg', 'manufacturer': 'Micro Labs Ltd', 'mrp': 24.0},
      {'medicine_name': 'Limcee Vitamin C 500mg', 'composition': 'Vitamin C 500mg', 'manufacturer': 'Abbott India', 'mrp': 25.0},
      {'medicine_name': 'Montelukast + Levocetirizine (Montair LC)', 'composition': 'Montelukast 10mg + Levocetirizine 5mg', 'manufacturer': 'Cipla Ltd', 'mrp': 190.0},
      {'medicine_name': 'Clopidogrel 75mg (Clopilet)', 'composition': 'Clopidogrel 75mg', 'manufacturer': 'Sun Pharmaceutical', 'mrp': 88.0},
      {'medicine_name': 'Losartan 50mg (Covance)', 'composition': 'Losartan 50mg', 'manufacturer': 'Sun Pharmaceutical', 'mrp': 65.0},
      {'medicine_name': 'Pantocid DSR Capsule', 'composition': 'Pantoprazole 40mg + Domperidone 30mg', 'manufacturer': 'Sun Pharmaceutical', 'mrp': 210.0},
      {'medicine_name': 'Becosules Capsules (Vitamin B-Complex)', 'composition': 'Vitamin B-Complex + Vitamin C', 'manufacturer': 'Pfizer Ltd', 'mrp': 48.0},
      {'medicine_name': 'Ranitidine 150mg (Rantac)', 'composition': 'Ranitidine 150mg', 'manufacturer': 'J.B. Chemicals', 'mrp': 28.0},
      {'medicine_name': 'Voglibose 0.2mg (Voglimac)', 'composition': 'Voglibose 0.2mg', 'manufacturer': 'Macleods Pharmaceuticals', 'mrp': 75.0},
      {'medicine_name': 'Rosuvastatin 10mg (Rosuvas)', 'composition': 'Rosuvastatin 10mg', 'manufacturer': 'Sun Pharmaceutical', 'mrp': 135.0},
      {'medicine_name': 'Diclofenac Gel (Volini)', 'composition': 'Diclofenac Diethylamine', 'manufacturer': 'Sun Pharmaceutical', 'mrp': 95.0},
      {'medicine_name': 'Ofloxacin + Ornidazole (O2 Tablet)', 'composition': 'Ofloxacin 200mg + Ornidazole 500mg', 'manufacturer': 'Medley Pharmaceuticals', 'mrp': 130.0},
      {'medicine_name': 'Rabeprazole 20mg (Rabeloc)', 'composition': 'Rabeprazole 20mg', 'manufacturer': 'Cadila Pharmaceuticals', 'mrp': 90.0},
      {'medicine_name': 'Glimepiride 2mg (Amaryl)', 'composition': 'Glimepiride 2mg', 'manufacturer': 'Sanofi India', 'mrp': 110.0},
      {'medicine_name': 'Domperidone 10mg (Domstal)', 'composition': 'Domperidone 10mg', 'manufacturer': 'Torrent Pharmaceuticals', 'mrp': 29.0},
      {'medicine_name': 'Calcium + Vitamin D3 (Shelcal 500)', 'composition': 'Calcium 500mg + Vitamin D3 250 IU', 'manufacturer': 'Torrent Pharmaceuticals', 'mrp': 112.0},
      {'medicine_name': 'Levothyroxine 50mcg (Thyronorm)', 'composition': 'Thyroxine Sodium 50mcg', 'manufacturer': 'Abbott India', 'mrp': 120.0},
      {'medicine_name': 'Spironolactone 25mg (Aldactone)', 'composition': 'Spironolactone 25mg', 'manufacturer': 'RPG Life Sciences', 'mrp': 36.0},
      {'medicine_name': 'Ciprofloxacin 500mg (Cifran)', 'composition': 'Ciprofloxacin 500mg', 'manufacturer': 'Sun Pharmaceutical', 'mrp': 42.0},
      {'medicine_name': 'Gabapentin 300mg (Gabapin)', 'composition': 'Gabapentin 300mg', 'manufacturer': 'Intas Pharmaceuticals', 'mrp': 125.0},
    ];

    for (var medicine in sampleMedicines) {
      batch.insert('medicine_master', medicine);
    }
    await batch.commit(noResult: true);
  }

  Future<String> _getTableName(Database db) async {
    if (_cachedTableName != null) return _cachedTableName!;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('medicine_master', 'medicines')");
    if (tables.isNotEmpty) {
      _cachedTableName = tables.first['name'] as String;
    } else {
      _cachedTableName = 'medicine_master';
    }
    return _cachedTableName!;
  }

  // Auto-complete search (limits results to 15 for top speed)
  Future<List<MedicineMasterModel>> searchMedicines(String query) async {
    if (!PlatformUtils.isDesktop) return [];
    if (query.trim().isEmpty) return [];

    final db = await database;
    if (db == null) return [];

    final tableName = await _getTableName(db);

    // Discover column names dynamically to avoid crash
    final columnsInfo = await db.rawQuery('PRAGMA table_info($tableName)');
    final columns = columnsInfo.map((c) => c['name'] as String).toList();

    final nameCol = columns.firstWhere((c) => ['medicine_name', 'name', 'medicine'].contains(c.toLowerCase()), orElse: () => 'medicine_name');
    final compCol = columns.firstWhere((c) => ['composition', 'substitutes', 'salt'].contains(c.toLowerCase()), orElse: () => 'composition');
    final manCol = columns.firstWhere((c) => ['manufacturer', 'category'].contains(c.toLowerCase()), orElse: () => 'manufacturer');
    final mrpCol = columns.firstWhere((c) => ['mrp', 'price'].contains(c.toLowerCase()), orElse: () => 'mrp');

    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: '$nameCol LIKE ? OR $compCol LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 15,
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return MedicineMasterModel(
        id: map['id'] ?? 0,
        medicineName: map[nameCol]?.toString() ?? '',
        composition: map[compCol]?.toString(),
        manufacturer: map[manCol]?.toString(),
        mrp: (map[mrpCol] as num?)?.toDouble() ?? 0.0,
      );
    });
  }

  // Insert a custom medicine into the master
  Future<int> insertMedicine(MedicineMasterModel medicine) async {
    final db = await database;
    if (db == null) return 0;

    final tableName = await _getTableName(db);
    return await db.insert(
      tableName,
      {
        'medicine_name': medicine.medicineName,
        'composition': medicine.composition,
        'manufacturer': medicine.manufacturer,
        'mrp': medicine.mrp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
