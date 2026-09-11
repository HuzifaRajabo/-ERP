import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/report_controller.dart';
import '../controllers/invoice_controller.dart';
import '../controllers/feature_controller.dart';
import '../core/utils/money_utils.dart';
import '../models/report_model.dart';
import '../models/invoice_model.dart';
import '../models/business_config.dart';

import 'product/product_list_screen.dart';
import 'party/party_list_screen.dart';
import 'invoice/invoice_list_screen.dart';
import 'expense/expense_list_screen.dart';
import 'inventory/inventory_screen.dart';
import 'debts/debts_screen.dart';
import 'report/report_screen.dart';
import 'warehouse/warehouse_list_screen.dart';
import 'packaging/packaging_screens.dart';
import 'notifications/notifications_screen.dart';
import '../controllers/notification_controller.dart';

// ============================================================
// NAV ITEM DEFINITIONS
// ============================================================
// Single source of truth for every section that lives inside the
// scrollable bottom navigation. Order here == order on screen.

class _NavItemData {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

const _NavItemData _homeNav = _NavItemData(
  label: 'الرئيسية',
  icon: Icons.dashboard_outlined,
  selectedIcon: Icons.dashboard_rounded,
);
const _NavItemData _productsNav = _NavItemData(
  label: 'المنتجات',
  icon: Icons.inventory_2_outlined,
  selectedIcon: Icons.inventory_2_rounded,
);
const _NavItemData _partiesNav = _NavItemData(
  label: 'الأطراف',
  icon: Icons.people_outline,
  selectedIcon: Icons.people_rounded,
);
const _NavItemData _invoicesNav = _NavItemData(
  label: 'الفواتير',
  icon: Icons.receipt_long_outlined,
  selectedIcon: Icons.receipt_long_rounded,
);
const _NavItemData _warehousesNav = _NavItemData(
  label: 'المستودعات',
  icon: Icons.warehouse_outlined,
  selectedIcon: Icons.warehouse_rounded,
);
const _NavItemData _expensesNav = _NavItemData(
  label: 'المصاريف',
  icon: Icons.money_off_outlined,
  selectedIcon: Icons.money_off_rounded,
);
const _NavItemData _debtsNav = _NavItemData(
  label: 'الديون',
  icon: Icons.account_balance_wallet_outlined,
  selectedIcon: Icons.account_balance_wallet_rounded,
);
const _NavItemData _inventoryNav = _NavItemData(
  label: 'المخزون العام',
  icon: Icons.inventory_outlined,
  selectedIcon: Icons.inventory_rounded,
);
const _NavItemData _packagingNav = _NavItemData(
  label: 'الفوارغ',
  icon: Icons.liquor_outlined,
  selectedIcon: Icons.liquor_rounded,
);
const _NavItemData _reportsNav = _NavItemData(
  label: 'التقارير',
  icon: Icons.bar_chart_outlined,
  selectedIcon: Icons.bar_chart_rounded,
);

class _NavSpec {
  final _NavItemData item;
  final Widget page;

  const _NavSpec({required this.item, required this.page});
}

List<_NavSpec> _navSpecsFor(BusinessSettings settings) {
  bool on(AppFeature feature) => settings.isEnabled(feature);
  return [
    const _NavSpec(item: _homeNav, page: HomeScreen()),
    const _NavSpec(item: _productsNav, page: ProductListScreen()),
    const _NavSpec(item: _partiesNav, page: PartyListScreen()),
    const _NavSpec(item: _invoicesNav, page: InvoiceListScreen()),
    if (on(AppFeature.warehouses))
      const _NavSpec(item: _warehousesNav, page: WarehouseListScreen()),
    if (on(AppFeature.expenses))
      const _NavSpec(item: _expensesNav, page: ExpenseListScreen()),
    if (on(AppFeature.debts))
      const _NavSpec(item: _debtsNav, page: DebtsScreen()),
    const _NavSpec(item: _inventoryNav, page: InventoryScreen()),
    if (on(AppFeature.returnablePackaging))
      const _NavSpec(item: _packagingNav, page: PackagingHubScreen()),
    const _NavSpec(item: _reportsNav, page: ReportScreen()),
  ];
}

// ============================================================
// MAIN SCREEN
// ============================================================
// Converted to a StatefulWidget only so the GetX RxInt survives
// widget rebuilds the same way it did before (it's created once,
// in initState, exactly like it used to be created once as a
// final field). Everything else (IndexedStack + pages) is
// unchanged in spirit.

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final RxInt currentIndex;
  final Map<String, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    currentIndex = 0.obs;
  }

  List<_NavSpec> _specs() {
    final settings = Get.isRegistered<FeatureController>()
        ? Get.find<FeatureController>().settings.value
        : ActivityProfilesFallback.settings;
    return _navSpecsFor(settings).map((spec) {
      return _NavSpec(
        item: spec.item,
        page: _pageCache.putIfAbsent(spec.item.label, () => spec.page),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final specs = _specs();
        final maxIndex = specs.isEmpty ? 0 : specs.length - 1;
        final index = currentIndex.value.clamp(0, maxIndex);
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          drawer: const _MainDrawer(),
          body: IndexedStack(
            index: index,
            children: specs.map((spec) => spec.page).toList(),
          ),
          bottomNavigationBar: _ScrollableBottomNav(
            currentIndex: index,
            items: specs.map((spec) => spec.item).toList(),
            onItemSelected: (value) => currentIndex.value = value,
          ),
        );
      },
    );
  }
}

class ActivityProfilesFallback {
  static final settings = BusinessSettings(
    activity: BusinessActivity.foodDistributor,
    features: {for (final feature in AppFeature.values) feature: true},
    notifications: const NotificationConfig(),
  );
}

// ============================================================
// SCROLLABLE BOTTOM NAVIGATION
// ============================================================
// Replaces the old 5-item NavigationBar + "المزيد" bottom sheet.
// A single horizontally scrollable row holds every section. The
// active item is kept in view automatically via
// Scrollable.ensureVisible whenever `currentIndex` changes
// (including changes triggered from outside this widget, e.g. a
// drawer link or Get.toNamed navigation that updates the index).
//
// RTL note: this app runs under Directionality.rtl (via the
// Arabic locale). A horizontal ListView automatically resolves its
// scroll/paint direction from the ambient TextDirection, so a drag
// from the right edge naturally reveals the next items in reading
// order — no manual `reverse:` flag is needed or wanted here.

class _ScrollableBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final List<_NavItemData> items;

  const _ScrollableBottomNav({
    required this.currentIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  State<_ScrollableBottomNav> createState() => _ScrollableBottomNavState();
}

class _ScrollableBottomNavState extends State<_ScrollableBottomNav> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(covariant _ScrollableBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
    }
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.items.length != widget.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!mounted || widget.items.isEmpty) return;
    final safeIndex = widget.currentIndex.clamp(0, widget.items.length - 1);
    final key = _itemKeys[safeIndex];
    final itemContext = key.currentContext;
    if (itemContext == null) return;

    Scrollable.ensureVisible(
      itemContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final selected = index == widget.currentIndex;

              return Padding(
                key: _itemKeys[index],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _NavBarItem(
                  label: item.label,
                  icon: item.icon,
                  selectedIcon: item.selectedIcon,
                  selected: selected,
                  onTap: () => widget.onItemSelected(index),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  static const Color _primary = Color(0xFF2563EB);
  static const Color _inactive = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected
                      ? _primary.withOpacity(0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: selected ? _primary : _inactive,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? _primary : _inactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME / DASHBOARD
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ReportController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<ReportController>();
  }

  Future<void> _refresh() async {
    await controller.loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: _buildAppBar(context),
      drawer: const _MainDrawer(),
      body: Obx(() {
        if (Get.isRegistered<FeatureController>()) {
          Get.find<FeatureController>().settings.value;
        }
        final overview = controller.overview.value;

        if (controller.isLoading.value && overview == null) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (overview == null) {
          return _ErrorState(
            message: controller.errorMessage.value ?? 'تعذر تحميل بيانات لوحة التحكم',
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              _buildHeader(),
              const SizedBox(height: 18),

              _buildPeriodSelector(),

              const SizedBox(height: 18),

              _buildPrimaryStats(overview),

              const SizedBox(height: 16),

              _buildFinancialSummary(overview),

              if (featureEnabled(AppFeature.debts)) ...[
                const SizedBox(height: 16),
                _buildDebtSection(overview),
              ],

              const SizedBox(height: 16),

              _buildOperationsSection(overview),

              if (featureEnabled(AppFeature.expiry)) ...[
                const SizedBox(height: 16),
                _buildExpiryAlertsCard(),
              ],

              const SizedBox(height: 16),

              _buildQuickActions(context),

              const SizedBox(height: 16),

              _buildReportButton(context),

              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (context) {
          return IconButton(
            tooltip: 'القائمة',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        },
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لوحة التحكم',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 2),
          Text(
            'نظرة عامة على نشاط النظام',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        const NotificationBellButton(),
        Obx(
          () => IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: controller.isLoading.value ? null : _refresh,
            icon: controller.isLoading.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();

    final greeting = switch (now.hour) {
      >= 5 && < 12 => 'صباح الخير 👋',
      >= 12 && < 17 => 'مساء الخير 👋',
      _ => 'مساء الخير 🌙',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF2563EB),
            Color(0xFF3B82F6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.business_center_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'إليك ملخص أداء نشاطك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            _periodItem(
              label: 'اليوم',
              value: ReportDateRange.today,
            ),
            _periodItem(
              label: 'الأسبوع',
              value: ReportDateRange.thisWeek,
            ),
            _periodItem(
              label: 'الشهر',
              value: ReportDateRange.thisMonth,
            ),
            _periodItem(
              label: 'السنة',
              value: ReportDateRange.thisYear,
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodItem({
    required String label,
    required ReportDateRange value,
  }) {
    final selected = controller.selectedRange.value == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setRange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2563EB)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : const Color(0xFF6B7280),
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryStats(ReportOverview overview) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'صافي المبيعات',
                value: MoneyUtils.formatMoney(
                  overview.saleNetTotal,
                ),
                subtitle:
                    '${overview.saleInvoiceCount} فاتورة',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'صافي المشتريات',
                value: MoneyUtils.formatMoney(
                  overview.purchaseNetTotal,
                ),
                subtitle:
                    '${overview.purchaseInvoiceCount} فاتورة',
                icon: Icons.shopping_cart_checkout_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'صافي الربح',
                value: MoneyUtils.formatMoney(
                  overview.netProfit,
                ),
                subtitle:
                    'مجمل الربح ${MoneyUtils.formatMoney(overview.grossProfit)}',
                icon: overview.netProfit >= 0
                    ? Icons.account_balance_wallet_rounded
                    : Icons.trending_down_rounded,
                color: overview.netProfit >= 0
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'قيمة المخزون',
                value: MoneyUtils.formatMoney(
                  overview.inventoryValue,
                ),
                subtitle: 'بسعر التكلفة الحالي',
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialSummary(ReportOverview overview) {
    return _SectionCard(
      title: 'الملخص المالي',
      icon: Icons.account_balance_rounded,
      child: Column(
        children: [
          _FinancialRow(
            title: 'المبيعات',
            value: overview.saleNetTotal,
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFF16A34A),
          ),
          const Divider(height: 22),
          _FinancialRow(
            title: 'تكلفة البضاعة المباعة',
            value: overview.cogsTotal,
            icon: Icons.inventory_rounded,
            color: const Color(0xFFF59E0B),
          ),
          if (featureEnabled(AppFeature.expenses)) ...[
            const Divider(height: 22),
            _FinancialRow(
              title: 'المصاريف',
              value: overview.expenseTotal,
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFEF4444),
            ),
          ],
          const Divider(height: 22),
          _FinancialRow(
            title: 'صافي الربح',
            value: overview.netProfit,
            icon: overview.netProfit >= 0
                ? Icons.check_circle_rounded
                : Icons.warning_rounded,
            color: overview.netProfit >= 0
                ? const Color(0xFF2563EB)
                : const Color(0xFFDC2626),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDebtSection(ReportOverview overview) {
    return _SectionCard(
      title: 'الذمم والديون',
      icon: Icons.account_balance_wallet_rounded,
      child: Row(
        children: [
          Expanded(
            child: _DebtCard(
              title: 'مستحق لنا',
              subtitle: 'من العملاء',
              value: overview.debtsOwedToUs,
              icon: Icons.south_west_rounded,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DebtCard(
              title: 'مستحق علينا',
              subtitle: 'للموردين',
              value: overview.debtsOwedByUs,
              icon: Icons.north_east_rounded,
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsSection(ReportOverview overview) {
    return _SectionCard(
      title: 'العمليات',
      icon: Icons.swap_horiz_rounded,
      child: Column(
        children: [
          _OperationRow(
            title: 'مرتجعات المبيعات',
            count: overview.saleReturnCount,
            value: overview.saleReturnTotal,
            icon: Icons.undo_rounded,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 10),
          _OperationRow(
            title: 'مرتجعات المشتريات',
            count: overview.purchaseReturnCount,
            value: overview.purchaseReturnTotal,
            icon: Icons.redo_rounded,
            color: const Color(0xFF0891B2),
          ),
          if (featureEnabled(AppFeature.expenses)) ...[
            const SizedBox(height: 10),
            _OperationRow(
              title: 'المصاريف',
              count: overview.expenseCount,
              value: overview.expenseTotal,
              icon: Icons.money_off_rounded,
              color: const Color(0xFFDC2626),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpiryAlertsCard() {
    return Obx(() {
      final count = Get.isRegistered<NotificationController>()
          ? Get.find<NotificationController>().activeExpiryCount
          : 0;
      if (count <= 0) return const SizedBox.shrink();
      return _SectionCard(
        title: 'تنبيهات الصلاحية',
        icon: Icons.event_busy_outlined,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB45309),
          ),
          title: Text('$count تنبيه قرب/انتهاء صلاحية'),
          subtitle: const Text('من الإشعارات النشطة الحالية'),
          onTap: () => Get.toNamed('/notifications'),
        ),
      );
    });
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = <Widget>[
      _QuickAction(
        title: 'فاتورة بيع',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF2563EB),
        onTap: () async {
          await Get.find<InvoiceController>().startNewInvoice();
          Get.toNamed('/invoice-form');
        },
      ),
      _QuickAction(
        title: 'فاتورة شراء',
        icon: Icons.shopping_cart_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () async {
          await Get.find<InvoiceController>().startNewInvoice(
            type: InvoiceType.purchase,
          );
          Get.toNamed('/invoice-form');
        },
      ),
      _QuickAction(
        title: 'إضافة منتج',
        icon: Icons.add_box_rounded,
        color: const Color(0xFF16A34A),
        onTap: () => Get.toNamed('/product-form'),
      ),
      _QuickAction(
        title: 'إضافة طرف',
        icon: Icons.person_add_rounded,
        color: const Color(0xFF7C3AED),
        onTap: () => Get.toNamed('/party-form'),
      ),
      if (featureEnabled(AppFeature.waste))
        _QuickAction(
          title: 'إتلاف بضاعة',
          icon: Icons.delete_forever_outlined,
          color: const Color(0xFFB91C1C),
          onTap: () => Get.toNamed('/waste-form'),
        ),
      if (featureEnabled(AppFeature.expiry))
        _QuickAction(
          title: 'مرتجع منتهي',
          icon: Icons.event_busy_outlined,
          color: const Color(0xFF9A3412),
          onTap: () => Get.toNamed('/expired-return-form'),
        ),
      if (featureEnabled(AppFeature.returnablePackaging))
        _QuickAction(
          title: 'تسوية عبوات',
          icon: Icons.liquor_outlined,
          color: const Color(0xFF0F766E),
          onTap: () => Get.toNamed('/packaging-settle'),
        ),
    ];

    return _SectionCard(
      title: 'إجراءات سريعة',
      icon: Icons.bolt_rounded,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
        children: actions,
      ),
    );
  }

  Widget _buildReportButton(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: () => Get.toNamed('/reports'),
        icon: const Icon(Icons.analytics_rounded),
        label: const Text(
          'عرض التقارير المالية التفصيلية',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAIN DRAWER
// ============================================================
// Kept as-is: it's still a valid secondary way to jump to a
// section, and none of it depended on the old "More" bottom sheet.

class _MainDrawer extends StatelessWidget {
  const _MainDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFF1D4ED8),
                    Color(0xFF2563EB),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.business_center_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'نظام إدارة المؤسسة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ERP Management System',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Obx(() {
                if (Get.isRegistered<FeatureController>()) {
                  Get.find<FeatureController>().settings.value;
                }
                return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                children: [
                  const _DrawerSectionTitle(
                    title: 'الإدارة',
                  ),
                  _DrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'لوحة التحكم',
                    onTap: () => Get.back(),
                  ),
                  Obx(() {
                    final count = Get.isRegistered<NotificationController>()
                        ? Get.find<NotificationController>().unreadCount.value
                        : 0;
                    return _DrawerItem(
                      icon: Icons.notifications_outlined,
                      title: 'الإشعارات',
                      badgeCount: count,
                      onTap: () {
                        Get.back();
                        Get.toNamed('/notifications');
                      },
                    );
                  }),
                  _DrawerItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'المنتجات',
                    onTap: () {
                      Get.back();
                      Get.to(
                        () => const ProductListScreen(),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.people_rounded,
                    title: 'الأطراف',
                    onTap: () {
                      Get.back();
                      Get.to(
                        () => const PartyListScreen(),
                      );
                    },
                  ),

                  const _DrawerSectionTitle(
                    title: 'المبيعات والمشتريات',
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'الفواتير',
                    onTap: () {
                      Get.back();
                      Get.to(
                        () => const InvoiceListScreen(),
                      );
                    },
                  ),
                  if (featureEnabled(AppFeature.debts))
                    _DrawerItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'الديون والمدفوعات',
                      onTap: () {
                        Get.back();
                        Get.to(
                          () => const DebtsScreen(),
                        );
                      },
                    ),

                  const _DrawerSectionTitle(
                    title: 'المخزون',
                  ),
                  if (featureEnabled(AppFeature.warehouses))
                    _DrawerItem(
                      icon: Icons.warehouse_rounded,
                      title: 'المستودعات',
                      onTap: () {
                        Get.back();
                        Get.to(
                          () => const WarehouseListScreen(),
                        );
                      },
                    ),
                  _DrawerItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'المخزون العام',
                    onTap: () {
                      Get.back();
                      Get.to(
                        () => const InventoryScreen(),
                      );
                    },
                  ),
                  if (featureEnabled(AppFeature.returnablePackaging))
                    _DrawerItem(
                      icon: Icons.liquor_outlined,
                      title: 'العبوات القابلة للإرجاع',
                      onTap: () {
                        Get.back();
                        Get.toNamed('/packaging');
                      },
                    ),

                  const _DrawerSectionTitle(
                    title: 'المالية والتقارير',
                  ),
                  if (featureEnabled(AppFeature.waste) ||
                      featureEnabled(AppFeature.expiry))
                    _DrawerItem(
                      icon: Icons.delete_forever_outlined,
                      title: 'إتلاف ومرتجع منتهي',
                      onTap: () {
                        Get.back();
                        Get.to(() => const InventoryScreen(initialTab: 2));
                      },
                    ),
                  if (featureEnabled(AppFeature.expenses))
                    _DrawerItem(
                      icon: Icons.money_off_rounded,
                      title: 'المصاريف',
                      onTap: () {
                        Get.back();
                        Get.to(
                          () => const ExpenseListScreen(),
                        );
                      },
                    ),
                  _DrawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'التقارير',
                    onTap: () {
                      Get.back();
                      Get.to(
                        () => const ReportScreen(),
                      );
                    },
                  ),
                ],
              );
              }),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Get.back();
                  Get.toNamed('/settings');
                },
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'الإعدادات',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// REUSABLE COMPONENTS
// ============================================================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.more_horiz_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final bool emphasize;

  const _FinancialRow({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 17,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: const Color(0xFF4B5563),
              fontSize: 13,
              fontWeight:
                  emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          MoneyUtils.formatMoney(value),
          style: TextStyle(
            color: emphasize
                ? color
                : const Color(0xFF111827),
            fontSize: emphasize ? 15 : 13,
            fontWeight:
                emphasize ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DebtCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final IconData icon;
  final Color color;

  const _DebtCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withOpacity(0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            MoneyUtils.formatMoney(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  final String title;
  final int count;
  final int value;
  final IconData icon;
  final Color color;

  const _OperationRow({
    required this.title,
    required this.count,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count عملية',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            MoneyUtils.formatMoney(value),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: color.withOpacity(0.6),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badgeCount;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Icon(
        icon,
        size: 21,
        color: const Color(0xFF4B5563),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
      trailing: badgeCount > 0
          ? Badge(
              backgroundColor: const Color(0xFFB91C1C),
              label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
            )
          : const Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
    );
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  final String title;

  const _DrawerSectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        14,
        12,
        6,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFDC2626),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'تعذر تحميل لوحة التحكم',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}