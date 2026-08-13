import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/platform_utils.dart';
import 'data/services/sqlite_service.dart';
import 'providers/pos_provider.dart';
import 'providers/dashboard_provider.dart';
import 'ui/desktop/layout/desktop_layout.dart';
import 'ui/mobile/layout/mobile_layout.dart';

import 'data/services/firebase_service.dart';
import 'data/services/license_service.dart';
import 'ui/common/screens/license_blocked_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Initialize FFI for Desktop
  if (PlatformUtils.isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 1. Setup Firebase with generated configuration options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase Core initialized successfully with options.');
    await FirebaseService.instance.ensureAuthenticated();
  } catch (e) {
    debugPrint('Firebase initialization bypassed or failed (offline simulation mode activated): $e');
  }

  // 2. Setup SQLite medicine database seeding for Desktop ONLY
  if (PlatformUtils.isDesktop) {
    try {
      debugPrint('Initialising SQLite Medicines Master Database for Desktop...');
      // Accessing the database getter triggers initialization & seeding if file is missing
      await SqliteService.instance.database;
      debugPrint('SQLite Medicines Master Database ready.');
    } catch (e) {
      debugPrint('SQLite initialization failed: $e');
    }
  } else {
    debugPrint('SQLite Database initialization skipped (running on Mobile platform: ${PlatformUtils.platformName})');
  }

  // 3. Initialize License & Remote Kill-Switch Verification
  try {
    await LicenseService.instance.initializeAndVerify();
  } catch (e) {
    debugPrint('LicenseService init error: $e');
  }

  runApp(const MedicalStoreApp());
}

class MedicalStoreApp extends StatelessWidget {
  const MedicalStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
      ],
      child: MaterialApp(
        title: 'WisdomPharma - Pharmacy Management System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LicenseGuardWrapper(),
      ),
    );
  }
}

class LicenseGuardWrapper extends StatefulWidget {
  const LicenseGuardWrapper({super.key});

  @override
  State<LicenseGuardWrapper> createState() => _LicenseGuardWrapperState();
}

class _LicenseGuardWrapperState extends State<LicenseGuardWrapper> {
  @override
  Widget build(BuildContext context) {
    if (LicenseService.instance.isBlocked) {
      return LicenseBlockedScreen(
        onUnlocked: () {
          setState(() {});
        },
      );
    }

    return PlatformUtils.isDesktop ? const DesktopLayout() : const MobileLayout();
  }
}
