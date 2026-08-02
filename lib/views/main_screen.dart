import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'product/product_list_screen.dart';
import 'debts/debts_screen.dart';
import 'expense/expense_list_screen.dart';
import 'party/party_list_screen.dart';
import 'report/report_screen.dart';
import 'invoice/invoice_list_screen.dart';
import 'inventory/inventory_screen.dart';

import '../controllers/report_controller.dart';
import '../core/utils/money_utils.dart';

class MainScreen extends StatelessWidget {
  MainScreen({super.key});

  final RxInt currentIndex = 0.obs;

  final List<Widget> _pages = const [
    HomeScreen(),
    ProductListScreen(),
    PartyListScreen(),
    InvoiceListScreen(),
    ExpenseListScreen(),
    InventoryScreen(),
    DebtsScreen(),
    ReportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: IndexedStack(index: currentIndex.value, children: _pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex.value,
          onTap: (index) => currentIndex.value = index,
          selectedItemColor: Colors.blue.shade700,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'المنتجات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'الأطراف',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'الفواتير',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.money_off_outlined),
              activeIcon: Icon(Icons.money_off),
              label: 'المصاريف',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warehouse_outlined),
              activeIcon: Icon(Icons.warehouse),
              label: 'المستودع',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'الديون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'التقارير',
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// Home Screen
// ==============================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final ReportController controller;

  late AnimationController _animationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    controller = Get.find<ReportController>();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await controller.loadOverview();

    _animationController
      ..reset()
      ..forward();
  }

  @override
  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF7F8FA),

    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black87,

      title: const Text(
        'الرئيسية',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),

      centerTitle: false,

      actions: [
        Obx(
          () => IconButton(
            onPressed: controller.isLoading.value ? null : _refresh,
            tooltip: 'تحديث',
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
    ),

    body: Obx(() {
      final overview = controller.overview.value;

      if (controller.isLoading.value && overview == null) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (overview == null) {
        return _buildErrorState();
      }

      return FutureBuilder<int>(
        future: getTodayProfit(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('تعذر تحميل أرباح اليوم'),
            );
          }

          final int todayProfit = snapshot.data ?? 0;

          final int inventoryCost = overview.inventoryValue;

          final int debtsOwedToUs = overview.debtsOwedToUs;

          final int debtsOwedByUs = overview.debtsOwedByUs;

          return RefreshIndicator(
            onRefresh: _refresh,

            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                30,
              ),

              child: FadeTransition(
                opacity: _fadeAnimation,

                child: SlideTransition(
                  position: _slideAnimation,

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,

                    children: [
                      // ==============================
                      // الترحيب
                      // ==============================
                      _buildWelcomeCard(
                        todayProfit: todayProfit,
                      ),

                      const SizedBox(height: 22),

                      // ==============================
                      // ربح اليوم
                      // ==============================
                      _buildTodayProfitCard(
                        todayProfit: todayProfit,
                      ),

                      const SizedBox(height: 14),

                      // ==============================
                      // المخزون
                      // ==============================
                      _buildInfoCard(
                        title: 'قيمة المخزون',
                        value: MoneyUtils.formatMoney(
                          inventoryCost,
                        ),
                        subtitle: 'بسعر التكلفة الحالي',
                        icon: Icons.inventory_2_rounded,
                        iconColor: Colors.blue,
                      ),

                      const SizedBox(height: 14),

                      // ==============================
                      // الديون
                      // ==============================
                      Row(
                        children: [
                          Expanded(
                            child: _buildDebtCard(
                              title: 'ديون لنا',
                              value: debtsOwedToUs,
                              subtitle: 'مستحقات العملاء',
                              icon: Icons.arrow_downward_rounded,
                              iconColor: Colors.green,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: _buildDebtCard(
                              title: 'ديون علينا',
                              value: debtsOwedByUs,
                              subtitle: 'مستحقات الموردين',
                              icon: Icons.arrow_upward_rounded,
                              iconColor: Colors.red,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // ==============================
                      // رسالة توجيهية
                      // ==============================
                      _buildGuidanceMessage(
                        todayProfit: todayProfit,
                        debtsOwedToUs: debtsOwedToUs,
                        debtsOwedByUs: debtsOwedByUs,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }),
  );
}

  Future<int> getTodayProfit() async {
    final now = DateTime.now();

    final startOfToday = DateTime(
      now.year,
      now.month,
      now.day,
      0,
      0,
      0,
    ).toUtc();

    final endOfToday = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
    ).toUtc();

    final todayOverview = await controller.repo.getOverview(
      from: startOfToday,
      to: endOfToday,
    );

    return todayOverview.netProfit;
  }

  // ============================================================
  // Welcome Card
  // ============================================================

  Widget _buildWelcomeCard({required int todayProfit}) {
    final message = _getWelcomeMessage(todayProfit);

    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),

        borderRadius: BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.waving_hand_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'أهلاً بك 👋',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),

                const SizedBox(height: 5),

                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Today Profit
  // ============================================================

  Widget _buildTodayProfitCard({required int todayProfit}) {
    final bool positive = todayProfit >= 0;

    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.green.withOpacity(0.12)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,

                decoration: BoxDecoration(
                  color: positive
                      ? Colors.green.withOpacity(0.10)
                      : Colors.red.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),

                child: Icon(
                  positive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,

                  color: positive ? Colors.green : Colors.red,

                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'أرباح اليوم',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),

                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),

                child: const Text(
                  'اليوم',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Align(
            alignment: Alignment.centerRight,

            child: FittedBox(
              child: Text(
                MoneyUtils.formatMoney(todayProfit),

                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: positive ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 5),

          Align(
            alignment: Alignment.centerRight,

            child: Text(
              positive
                  ? 'أداء إيجابي اليوم 👍'
                  : 'هناك خسارة اليوم، راجع حركة المبيعات والتكاليف',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Inventory Card
  // ============================================================

  Widget _buildInfoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,

            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: iconColor, size: 25),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 5),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,

                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Debt Card
  // ============================================================

  Widget _buildDebtCard({
    required String title,
    required int value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
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
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),

                child: Icon(icon, color: iconColor, size: 20),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,

            child: Text(
              MoneyUtils.formatMoney(value),

              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Guidance
  // ============================================================

  Widget _buildGuidanceMessage({
    required int todayProfit,
    required int debtsOwedToUs,
    required int debtsOwedByUs,
  }) {
    String title;
    String message;
    IconData icon;
    Color color;

    if (debtsOwedToUs > debtsOwedByUs && debtsOwedToUs > 0) {
      title = 'تنبيه مالي';
      message =
          'لديك مبالغ مستحقة من العملاء. متابعة التحصيل تساعد على تحسين السيولة.';
      icon = Icons.notifications_active_rounded;
      color = Colors.orange;
    } else if (debtsOwedByUs > 0 && debtsOwedByUs > debtsOwedToUs) {
      title = 'مستحقات الموردين';
      message =
          'لديك مبالغ مستحقة للموردين. راجع مواعيد السداد للحفاظ على تدفق مالي جيد.';
      icon = Icons.schedule_rounded;
      color = Colors.deepOrange;
    } else if (todayProfit > 0) {
      title = 'استمر بهذا الأداء 🚀';
      message =
          'نتيجة اليوم إيجابية. حافظ على المبيعات وراقب التكاليف لتحقيق ربح أفضل.';
      icon = Icons.auto_graph_rounded;
      color = Colors.green;
    } else if (todayProfit == 0) {
      title = 'ابدأ يومك بقوة 💪';
      message =
          'لم يتم تسجيل ربح اليوم حتى الآن. تابع حركة المبيعات لتحقيق نتيجة أفضل.';
      icon = Icons.lightbulb_outline_rounded;
      color = Colors.blue;
    } else {
      title = 'راجع أداء اليوم';
      message =
          'النتيجة الحالية سالبة. من المفيد مراجعة المبيعات والتكاليف والمرتجعات.';
      icon = Icons.warning_amber_rounded;
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: color, size: 25),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Dynamic Welcome Message
  // ============================================================

  String _getWelcomeMessage(int todayProfit) {
    if (todayProfit > 0) {
      return 'يوم جيد! استمر في تحقيق المزيد من الأرباح 🚀';
    }

    if (todayProfit == 0) {
      return 'نتمنى لك يوماً مليئاً بالمبيعات والنجاح 🌟';
    }

    return 'لا بأس، راجع أداء اليوم واجعل الغد أفضل 💪';
  }

  // ============================================================
  // Error
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 60,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 15),

            const Text(
              'تعذر تحميل بيانات الصفحة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              controller.errorMessage.value ?? 'حدث خطأ أثناء تحميل البيانات',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
