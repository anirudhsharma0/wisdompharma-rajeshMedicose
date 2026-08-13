import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';

class LicenseService {
  static final LicenseService instance = LicenseService._internal();
  LicenseService._internal();

  // Keys for SharedPreferences
  static const String _keySheetUrl = 'license_google_sheet_url';
  static const String _keyClientId = 'license_client_id';
  static const String _keyLastVerified = 'license_last_online_verified';
  static const String _keyIsBlocked = 'license_cached_is_blocked';
  static const String _keyBlockReason = 'license_cached_block_reason';

  // Fallback defaults
  String defaultClientId = 'RajeshMedicose001';
  // Published Google Sheet CSV URL (User can change via settings or code)
  String defaultSheetUrl = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vR6cfryonGFEsn_3aeS1atXJknefIVb5A7eQ2SdY8lh_GrQV7zYDlOe0YEcyKYdwaPkkhhOgnXbM4J9/pub?output=csv';

  bool isBlocked = false;
  String blockReason = '';
  String clientId = 'RajeshMedicose001';
  String sheetUrl = '';
  DateTime? lastOnlineVerified;
  int maxOfflineDays = 7;

  /// Initialize and perform immediate license check
  Future<bool> initializeAndVerify() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ensure any legacy bypass keys are removed
    await prefs.remove('license_offline_bypass_expiry');

    clientId = prefs.getString(_keyClientId) ?? defaultClientId;
    sheetUrl = prefs.getString(_keySheetUrl) ?? defaultSheetUrl;

    final lastMs = prefs.getInt(_keyLastVerified);
    if (lastMs != null) {
      lastOnlineVerified = DateTime.fromMillisecondsSinceEpoch(lastMs);
    }

    // Load cached state first as fallback
    isBlocked = prefs.getBool(_keyIsBlocked) ?? false;
    blockReason = prefs.getString(_keyBlockReason) ?? 'Software license suspended. Please contact Wisdom Core Solutions (9050524678).';

    // Attempt Online Verification
    try {
      await verifyOnline(sheetUrl, clientId);
    } catch (e) {
      debugPrint('LicenseService: Online check failed (device might be offline): $e');
      await _applyOfflinePolicy();
    }

    return !isBlocked;
  }

  /// Perform online HTTP fetch and parse Google Sheet CSV
  Future<bool> verifyOnline(String targetSheetUrl, String targetClientId) async {
    if (targetSheetUrl.trim().isEmpty || targetSheetUrl.contains('SampleSheetPlaceholder')) {
      debugPrint('LicenseService: No valid Google Sheet CSV URL set. Skipping online fetch.');
      await _applyOfflinePolicy();
      return !isBlocked;
    }

    final prefs = await SharedPreferences.getInstance();
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final request = await client.getUrl(Uri.parse(targetSheetUrl.trim()));
      final response = await request.close();

      if (response.statusCode == 200) {
        final csvString = await response.transform(utf8.decoder).join();
        final List<List<dynamic>> rows = const CsvToListConverter(shouldParseNumbers: false).convert(csvString);

        bool foundMatchingClient = false;
        bool statusActive = false;
        String customMsg = '';

        for (var row in rows) {
          if (row.isEmpty) continue;
          final rowClientId = row[0].toString().trim();
          
          if (rowClientId.toLowerCase() == targetClientId.toLowerCase()) {
            foundMatchingClient = true;
            final statusStr = row.length > 1 ? row[1].toString().trim().toUpperCase() : 'FALSE';
            statusActive = (statusStr == 'TRUE' || statusStr == '1' || statusStr == 'ACTIVE' || statusStr == 'YES');
            
            if (row.length > 2) {
              customMsg = row[2].toString().trim();
            }
            break;
          }
        }

        if (foundMatchingClient) {
          if (statusActive) {
            isBlocked = false;
            blockReason = '';
            lastOnlineVerified = DateTime.now();

            await prefs.setInt(_keyLastVerified, lastOnlineVerified!.millisecondsSinceEpoch);
            await prefs.setBool(_keyIsBlocked, false);
            await prefs.setString(_keyBlockReason, '');
            debugPrint('LicenseService: Online verification SUCCESS for Client ID [$targetClientId]. App Unlocked.');
          } else {
            isBlocked = true;
            blockReason = customMsg.isNotEmpty
                ? customMsg
                : 'Software License Suspended for Client ID [$targetClientId]. Please contact Wisdom Core Solutions @ 9050524678.';
            
            await prefs.setBool(_keyIsBlocked, true);
            await prefs.setString(_keyBlockReason, blockReason);
            debugPrint('LicenseService: Online verification BLOCKED for Client ID [$targetClientId].');
          }
        } else {
          // Client ID not found in sheet
          debugPrint('LicenseService: Client ID [$targetClientId] not listed in Google Sheet.');
          await _applyOfflinePolicy();
        }
      } else {
        debugPrint('LicenseService: HTTP Response status code ${response.statusCode}');
        await _applyOfflinePolicy();
      }
    } finally {
      client.close();
    }

    return !isBlocked;
  }

  /// Offline policy verification (Grace Period)
  Future<void> _applyOfflinePolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedBlocked = prefs.getBool(_keyIsBlocked) ?? false;

    if (cachedBlocked) {
      isBlocked = true;
      blockReason = prefs.getString(_keyBlockReason) ?? 'Software license suspended. Please contact administrator (9050524678).';
      return;
    }

    if (lastOnlineVerified == null) {
      // First run without online verification: set baseline timestamp
      lastOnlineVerified = DateTime.now();
      await prefs.setInt(_keyLastVerified, lastOnlineVerified!.millisecondsSinceEpoch);
      isBlocked = false;
      return;
    }

    final daysOffline = DateTime.now().difference(lastOnlineVerified!).inDays;
    if (daysOffline > maxOfflineDays) {
      isBlocked = true;
      blockReason = 'Offline Grace Period Expired ($daysOffline days offline, max limit $maxOfflineDays days).\n'
          'Please connect your PC/Device to internet to re-verify software license.';
    } else {
      isBlocked = false;
      blockReason = '';
      debugPrint('LicenseService: Offline mode valid ($daysOffline/$maxOfflineDays days elapsed).');
    }
  }

  /// Update Google Sheet published CSV URL
  Future<void> setSheetUrl(String url) async {
    sheetUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySheetUrl, sheetUrl);
  }

  /// Update Client ID
  Future<void> setClientId(String newId) async {
    clientId = newId.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClientId, clientId);
  }
}
