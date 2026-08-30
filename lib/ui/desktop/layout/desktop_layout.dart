import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/pos_billing_screen.dart';
import '../screens/inventory_management_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/vouchers_screen.dart';
import '../screens/placeholder_screens.dart';
import '../screens/parties_screen.dart';
import '../../common/screens/bill_scanner_screen.dart';
import '../../common/screens/pending_bills_screen.dart';

class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  int _selectedIdx = 0;
  late final List<Widget> _screens;
  late Timer _timer;
  DateTime _now = DateTime.now();

  bool _isSidebarCollapsed = false;

  // Track expanded groups in sidebar
  final Set<String> _expandedGroups = {'Parties', 'Items', 'Purchase'};

  void _showShortcutsHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.keyboard, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⌨️ Desktop Keyboard Shortcuts',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Work super-fast with instant keyboard shortcuts',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildShortcutSection(
                  'Global Navigation Shortcuts',
                  [
                    _ShortcutItem(['F1', 'Ctrl + H'], 'Open Shortcuts Guide'),
                    _ShortcutItem(['F2', 'Ctrl + F'], 'Open Anything (Global Search)'),
                    _ShortcutItem(['F3', 'Ctrl + N'], 'Open POS Sale Billing'),
                    _ShortcutItem(['F4', 'Ctrl + P'], 'Open Wholesale Khata & Purchases'),
                    _ShortcutItem(['F5', 'Ctrl + I'], 'Open Stock Inventory'),
                    _ShortcutItem(['Ctrl + K'], 'Open Customer Khata'),
                    _ShortcutItem(['Ctrl + D'], 'Open Dashboard Overview'),
                    _ShortcutItem(['Ctrl + R'], 'Open Reports & MIS'),
                  ],
                ),
                const SizedBox(height: 16),
                _buildShortcutSection(
                  'POS Billing Shortcuts',
                  [
                    _ShortcutItem(['F9', 'Ctrl + Enter'], 'Save & Print Bill (Fast Checkout)'),
                    _ShortcutItem(['F8'], 'Focus Discount Field'),
                    _ShortcutItem(['Esc'], 'Clear Cart / Close Modal'),
                  ],
                ),
                const SizedBox(height: 16),
                _buildShortcutSection(
                  'Wholesale & Purchase Shortcuts',
                  [
                    _ShortcutItem(['Alt + B'], '+ Add Purchase Bill'),
                    _ShortcutItem(['Alt + P'], '+ Pay Supplier (Payment Out)'),
                    _ShortcutItem(['Alt + N'], '+ Add New Wholesaler'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutSection(String title, List<_ShortcutItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: items.map((item) {
            return Container(
              width: 270,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.description,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                  ),
                  Row(
                    children: item.keys.map((k) => Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        k,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showGlobalSearchDialog(BuildContext context) {
    final TextEditingController searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

          final matchedCustomers = dashProvider.customers.where((c) => c.name.toLowerCase().contains(query) || c.phone.contains(query)).take(4).toList();
          final matchedSuppliers = dashProvider.suppliers.where((s) => s.name.toLowerCase().contains(query) || s.contact.contains(query)).take(4).toList();
          final matchedInventory = dashProvider.inventory.where((i) => i.medicineName.toLowerCase().contains(query) || i.batchNumber.toLowerCase().contains(query)).take(4).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 580,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search medicines, suppliers, customers or jump...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (query.isEmpty) ...[
                    const Text('Quick Navigation Shortcuts:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(avatar: const Icon(Icons.receipt_long, size: 16), label: const Text('Sale Billing (POS) [F3]'), onPressed: () { Navigator.pop(ctx); _navigateToScreen(1); }),
                        ActionChip(avatar: const Icon(Icons.local_shipping, size: 16), label: const Text('Wholesale Khata [F4]'), onPressed: () { Navigator.pop(ctx); _navigateToScreen(5); }),
                        ActionChip(avatar: const Icon(Icons.inventory_2, size: 16), label: const Text('Stock Inventory [F5]'), onPressed: () { Navigator.pop(ctx); _navigateToScreen(3); }),
                        ActionChip(avatar: const Icon(Icons.people, size: 16), label: const Text('Customer Khata [Ctrl+K]'), onPressed: () { Navigator.pop(ctx); _navigateToScreen(4); }),
                        ActionChip(avatar: const Icon(Icons.analytics, size: 16), label: const Text('Reports [Ctrl+R]'), onPressed: () { Navigator.pop(ctx); _navigateToScreen(8); }),
                        ActionChip(avatar: const Icon(Icons.keyboard, size: 16), label: const Text('Shortcuts Guide [F1]'), onPressed: () { Navigator.pop(ctx); _showShortcutsHelpDialog(context); }),
                      ],
                    ),
                  ] else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (matchedInventory.isNotEmpty) ...[
                              const Text('Medicines in Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                              ...matchedInventory.map((i) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.medication, size: 18),
                                title: Text(i.medicineName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Batch: ${i.batchNumber} | Stock: ${i.quantity} | MRP: ₹${i.mrp}'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _navigateToScreen(3);
                                },
                              )),
                              const Divider(),
                            ],
                            if (matchedSuppliers.isNotEmpty) ...[
                              const Text('Wholesale Suppliers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
                              ...matchedSuppliers.map((s) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.local_shipping, size: 18),
                                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Mob: ${s.contact} | Due: ₹${s.due.toStringAsFixed(2)}'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _navigateToScreen(5);
                                },
                              )),
                              const Divider(),
                            ],
                            if (matchedCustomers.isNotEmpty) ...[
                              const Text('Customers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.success)),
                              ...matchedCustomers.map((c) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.person, size: 18),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Mob: ${c.phone} | Balance: ₹${c.pendingBalance.toStringAsFixed(2)}'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _navigateToScreen(4);
                                },
                              )),
                            ],
                            if (matchedInventory.isEmpty && matchedSuppliers.isEmpty && matchedCustomers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(child: Text('No matching records found.')),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onNavigate: (index) {
        setState(() {
          _selectedIdx = index;
        });
      }),
      const PosBillingScreen(),
      const PurchaseScreen(),
      const InventoryManagementScreen(),
      const PartiesScreen(initialFilter: 'CUSTOMERS'),
      const PartiesScreen(initialFilter: 'SUPPLIERS'),
      const MedicineMasterScreen(),
      const ExpiryManagementScreen(),
      const ReportsScreen(),
      const ExpensesScreen(),
      const VouchersScreen(),
      const UsersScreen(),
      const SettingsScreen(),
      const BillScannerScreen(),
      const PendingBillsScreen(),
    ];

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _navigateToScreen(int index) {
    setState(() {
      _selectedIdx = index;
    });
  }

  void _toggleGroup(String groupKey) {
    setState(() {
      if (_expandedGroups.contains(groupKey)) {
        _expandedGroups.remove(groupKey);
      } else {
        _expandedGroups.add(groupKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f1): () => _showShortcutsHelpDialog(context),
        const SingleActivator(LogicalKeyboardKey.f2): () => _showGlobalSearchDialog(context),
        const SingleActivator(LogicalKeyboardKey.f3): () => _navigateToScreen(1),
        const SingleActivator(LogicalKeyboardKey.f4): () => _navigateToScreen(5),
        const SingleActivator(LogicalKeyboardKey.f5): () => _navigateToScreen(3),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () => _showShortcutsHelpDialog(context),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _showGlobalSearchDialog(context),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _navigateToScreen(1),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => _navigateToScreen(5),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () => _navigateToScreen(3),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _navigateToScreen(4),
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () => _navigateToScreen(0),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () => _navigateToScreen(8),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              // ================= 2. MAIN APP ROW (SIDEBAR + CONTENT) =================
              Expanded(
                child: Row(
                  children: [
                    // A. VYAPAR STYLE LEFT SIDEBAR NAVIGATION (COLLAPSIBLE)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isSidebarCollapsed ? 60 : 230,
                      color: const Color(0xFF1E293B), // Dark navy slate background
                      child: Column(
                        children: [
                          // WisdomPharma Sidebar Top Logo Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F172A),
                              border: Border(bottom: BorderSide(color: Colors.white12)),
                            ),
                            child: _isSidebarCollapsed
                                ? Center(
                                    child: IconButton(
                                      icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                                      tooltip: 'Expand Sidebar (Show Navbar)',
                                      onPressed: () => setState(() => _isSidebarCollapsed = false),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.asset(
                                            'assets/icon/app_icon.png',
                                            width: 26,
                                            height: 26,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              'wisdomPharma',
                                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Pharmacy ERP System',
                                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.keyboard, color: Colors.amberAccent, size: 20),
                                        tooltip: 'Shortcuts Guide (F1)',
                                        onPressed: () => _showShortcutsHelpDialog(context),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.menu_open, color: Colors.white70, size: 20),
                                        tooltip: 'Hide / Collapse Navbar',
                                        onPressed: () => setState(() => _isSidebarCollapsed = true),
                                      ),
                                    ],
                                  ),
                          ),
                          // Search Pill Box
                          if (!_isSidebarCollapsed)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                              child: InkWell(
                                onTap: () => _showGlobalSearchDialog(context),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF334155).withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.search, size: 16, color: Colors.white70),
                                      SizedBox(width: 8),
                                      Text(
                                        'Open Anything (Ctrl+F)',
                                        style: TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: IconButton(
                                icon: const Icon(Icons.search, size: 20, color: Colors.white70),
                                tooltip: 'Search (Ctrl+F / F2)',
                                onPressed: () => _showGlobalSearchDialog(context),
                              ),
                            ),

                      const Divider(color: Colors.white12, height: 1),

                      // Navigation Menu List
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Dashboard
                              _buildSingleSidebarTile(
                                icon: Icons.grid_view_rounded,
                                title: 'Dashboard',
                                screenIndex: 0,
                              ),

                              // 2. Customers / Khata Ledger Group
                              _buildExpandableGroup(
                                title: 'Khata Ledger & Parties',
                                icon: Icons.people_alt_outlined,
                                groupKey: 'Parties',
                                children: [
                                  _buildSubTile('Customer Khata', 4),
                                  _buildSubTile('Wholesale Khata', 5),
                                ],
                              ),

                              // 3. Inventory & Medicines Group
                              _buildExpandableGroup(
                                title: 'Inventory & Medicines',
                                icon: Icons.inventory_2_outlined,
                                groupKey: 'Items',
                                children: [
                                  _buildSubTile('Stock Inventory', 3),
                                  _buildSubTile('Medicines Master DB', 6),
                                  _buildSubTile('Expiry Management', 7),
                                ],
                              ),

                              // 4. POS Sale Billing
                              _buildSingleSidebarTile(
                                icon: Icons.receipt_long_outlined,
                                title: 'Sale Billing (POS)',
                                screenIndex: 1,
                              ),

                              // 5. Purchase & Expense Group
                              _buildExpandableGroup(
                                title: 'Purchase & Expense',
                                icon: Icons.shopping_cart_outlined,
                                groupKey: 'Purchase',
                                children: [
                                  _buildSubTile('Purchase Bills', 2),
                                  _buildSubTile('📷 AI Bill Scanner (Excel)', 13),
                                  _buildSubTile('📋 Pending Bills Queue', 14),
                                  _buildSubTile('Daily Expenses', 9),
                                ],
                              ),

                              // 6. Reports & MIS
                              _buildSingleSidebarTile(
                                icon: Icons.analytics_outlined,
                                title: 'Reports & MIS',
                                screenIndex: 8,
                              ),

                              // 7. Payment Vouchers
                              _buildSingleSidebarTile(
                                icon: Icons.payments_outlined,
                                title: 'Payment Vouchers',
                                screenIndex: 10,
                              ),

                              // 8. User Accounts
                              _buildSingleSidebarTile(
                                icon: Icons.manage_accounts_outlined,
                                title: 'User Accounts',
                                screenIndex: 11,
                              ),

                              // 9. System Settings
                              _buildSingleSidebarTile(
                                icon: Icons.settings_outlined,
                                title: 'System Settings',
                                screenIndex: 12,
                              ),


                            ],
                          ),
                        ),
                      ),

                      // Store / User Profile at Bottom Left
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          border: Border(top: BorderSide(color: Colors.white12)),
                        ),
                        child: _isSidebarCollapsed
                            ? Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.asset(
                                    'assets/icon/app_icon.png',
                                    width: 22,
                                    height: 22,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 16),
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: Image.asset(
                                        'assets/icon/app_icon.png',
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          dashProvider.pharmacyName.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Text(
                                          'WisdomPharma POS',
                                          style: TextStyle(color: Colors.white60, fontSize: 9.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 16, color: Colors.white54),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                // B. MAIN CONTENT AREA (TOP HEADER + SCREEN WORKSPACE)
                Expanded(
                  child: Column(
                    children: [
                      // CENTER SCREEN CONTENT
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: _screens[_selectedIdx.clamp(0, _screens.length - 1)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ================= 3. BOTTOM FOOTER STATUS BAR =================
          Container(
            height: 24,
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'WisdomPharma ERP | ${dashProvider.pharmacyName.toUpperCase()} | Powered by Wisdom Core Solutions (Support: 9050524678 | wisdomcoresolution.store)',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Period: 2026-2027 | ${DateFormat('dd-MM-yyyy HH:mm:ss').format(_now)}',
                  style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildSingleSidebarTile({
    required IconData icon,
    required String title,
    required int screenIndex,
    Color? accentColor,
  }) {
    final isSelected = _selectedIdx == screenIndex;
    if (_isSidebarCollapsed) {
      return Tooltip(
        message: title,
        child: InkWell(
          onTap: () => _navigateToScreen(screenIndex),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF334155) : Colors.transparent,
            ),
            child: Icon(icon, size: 20, color: isSelected ? Colors.white : (accentColor ?? Colors.white70)),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => _navigateToScreen(screenIndex),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF334155) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              color: isSelected ? (accentColor ?? const Color(0xFFE11D48)) : Colors.transparent,
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 18, color: isSelected ? Colors.white : (accentColor ?? Colors.white70)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : (accentColor ?? Colors.white70),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableGroup({
    required String title,
    required IconData icon,
    required String groupKey,
    required List<Widget> children,
  }) {
    final isExpanded = _expandedGroups.contains(groupKey);
    if (_isSidebarCollapsed) {
      return Tooltip(
        message: title,
        child: InkWell(
          onTap: () => _toggleGroup(groupKey),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: Colors.white70),
          ),
        ),
      );
    }
    return Column(
      children: [
        InkWell(
          onTap: () => _toggleGroup(groupKey),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) Column(children: children),
      ],
    );
  }

  Widget _buildSubTile(String title, int screenIndex) {
    final isSelected = _selectedIdx == screenIndex;
    if (_isSidebarCollapsed) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _navigateToScreen(screenIndex),
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 46),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF334155) : Colors.transparent,
        ),
        child: Row(
          children: [
            if (isSelected)
              Container(
                width: 4,
                height: 18,
                margin: const EdgeInsets.only(right: 8),
                color: const Color(0xFFE11D48),
              ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutItem {
  final List<String> keys;
  final String description;
  _ShortcutItem(this.keys, this.description);
}
