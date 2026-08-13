import 'dart:async';
import 'package:flutter/material.dart';
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
    if (index == 99) {
      showDialog(
        context: context,
        builder: (ctx) => WipeDataSecurityDialog(
          provider: Provider.of<DashboardProvider>(context, listen: false),
        ),
      );
      return;
    }
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

    return Scaffold(
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
                            onTap: () {},
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
                            tooltip: 'Search (Ctrl+F)',
                            onPressed: () {},
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
                                title: 'Customers (Khata)',
                                icon: Icons.people_alt_outlined,
                                groupKey: 'Parties',
                                children: [
                                  _buildSubTile('Customer Directory', 4),
                                  _buildSubTile('Khata Statements', 4),
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
                                  _buildSubTile('Suppliers Directory', 5),
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

                              // 10. Clean Data Reset
                              _buildSingleSidebarTile(
                                icon: Icons.cleaning_services_outlined,
                                title: 'Clean / Reset Data',
                                screenIndex: 99,
                                accentColor: Colors.red.shade400,
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
                          child: _screens[_selectedIdx],
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
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : (accentColor ?? Colors.white70),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlobalSearchResult {
  final String title;
  final String subtitle;
  final IconData icon;
  final int targetScreenIndex;

  _GlobalSearchResult({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.targetScreenIndex,
  });
}
