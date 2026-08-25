import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/utils/money_utils.dart';
import '../../models/product_model.dart';
import '../../models/product_unit_model.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  State<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState
    extends State<ProductDetailsScreen> {
  final ProductController controller =
      Get.find<ProductController>();

  late ProductModel product;

  List<ProductUnitModel> units = [];

  bool isLoadingUnits = true;

  @override
  void initState() {
    super.initState();

    product = Get.arguments as ProductModel;

    _loadUnits();

    AppEventBus.instance.listenToProducts(
      _refreshProduct,
    );
  }

  Future<void> _refreshProduct() async {
    if (!mounted || product.id == null) {
      return;
    }

    final updated =
        await controller.getProductById(product.id!);

    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      product = updated;
    });

    await _loadUnits();
  }

  Future<void> _loadUnits() async {
    if (product.id == null) return;

    if (mounted) {
      setState(() {
        isLoadingUnits = true;
      });
    }

    try {
      final result =
          await controller.getProductUnits(
        product.id!,
        activeOnly: true,
      );

      if (!mounted) return;

      setState(() {
        units = _sortUnits(result);
        isLoadingUnits = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        units = [];
        isLoadingUnits = false;
      });
    }
  }

  List<ProductUnitModel> _sortUnits(
    List<ProductUnitModel> value,
  ) {
    final result = [...value];

    result.sort(
      (a, b) {
        if (a.isBaseUnit && !b.isBaseUnit) {
          return 1;
        }

        if (!a.isBaseUnit && b.isBaseUnit) {
          return -1;
        }

        if (a.isDefaultSellUnit &&
            !b.isDefaultSellUnit) {
          return -1;
        }

        if (!a.isDefaultSellUnit &&
            b.isDefaultSellUnit) {
          return 1;
        }

        return a.conversionFactor.compareTo(
          b.conversionFactor,
        );
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            tooltip: 'حذف المنتج',
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUnits,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 18),
            _buildUnitsSection(),
            const SizedBox(height: 18),
            _buildLegacyPriceSummary(),
            const SizedBox(height: 24),
            _buildEditButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Header
  // ============================================================

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(.08),
                    borderRadius:
                        BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Row(
                        children: [
                          _StatusBadge(
                            icon: Icons.check_circle_outline,
                            text: 'فعال',
                            color: Colors.green,
                          ),
                          if (product.categoryName !=
                                  null &&
                              product.categoryName!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(width: 7),
                            Flexible(
                              child: _StatusBadge(
                                icon:
                                    Icons.category_outlined,
                                text:
                                    product.categoryName!,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (product.description
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        product.description,
                        style: TextStyle(
                          height: 1.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Units
  // ============================================================

  Widget _buildUnitsSection() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.all_inbox_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'الوحدات والأسعار',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${units.length} وحدة',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (isLoadingUnits)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (units.isEmpty)
              _buildNoUnits()
            else
              _buildUnitsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsList() {
    return Column(
      children: [
        _buildUnitsHeader(),

        const SizedBox(height: 8),

        ...units.map(_buildUnitRow),
      ],
    );
  }

  Widget _buildUnitsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'الوحدة',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'التحويل',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'التكلفة',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'البيع',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitRow(
    ProductUnitModel unit,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: unit.isDefaultSellUnit
            ? Theme.of(context)
                .colorScheme
                .primary
                .withOpacity(.035)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unit.isDefaultSellUnit
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(.20)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        unit.unitName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit.isBaseUnit) ...[
                      const SizedBox(width: 5),
                      const _TinyBadge(
                        text: 'أساسية',
                      ),
                    ],
                  ],
                ),
              ),

              Expanded(
                flex: 2,
                child: Text(
                  _conversionText(unit),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),

              Expanded(
                flex: 2,
                child: Text(
                  unit.costPrice == null
                      ? '-'
                      : _money(unit.costPrice!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Expanded(
                flex: 2,
                child: Text(
                  _money(unit.defaultSalePrice),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                if (unit.canBuy)
                  const _TinyBadge(
                    icon: Icons.shopping_cart_outlined,
                    text: 'شراء',
                  ),
                if (unit.canSell)
                  const _TinyBadge(
                    icon: Icons.sell_outlined,
                    text: 'بيع',
                  ),
                if (unit.isDefaultSellUnit)
                  const _TinyBadge(
                    icon: Icons.check_circle_outline,
                    text: 'وحدة البيع الافتراضية',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUnits() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 38,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          const Text(
            'لا توجد وحدات معرفة لهذا المنتج',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _conversionText(
    ProductUnitModel unit,
  ) {
    final factor = unit.conversionFactor ==
            unit.conversionFactor.roundToDouble()
        ? unit.conversionFactor.toInt().toString()
        : unit.conversionFactor.toStringAsFixed(2);

    final baseUnit = units
        .firstWhereOrNull(
          (u) => u.isBaseUnit,
        )
        ?.unitName ??
        'قطعة';

    return '$factor $baseUnit';
  }

  // ============================================================
  // Legacy / Compatibility Summary
  // ============================================================

  Widget _buildLegacyPriceSummary() {
    final defaultUnit =
        units.firstWhereOrNull(
      (unit) => unit.isDefaultSellUnit,
    );

    if (defaultUnit == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.withOpacity(.15),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'وحدة البيع الافتراضية: '
              '${defaultUnit.unitName}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            _money(defaultUnit.defaultSalePrice),
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Actions
  // ============================================================

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _editProduct,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('تعديل المنتج'),
      ),
    );
  }

  void _editProduct() {
    Get.toNamed(
      '/product-form',
      arguments: product,
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text(
          'هل تريد حذف "${product.name}"؟',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();

              if (product.id == null) {
                return;
              }

              await controller.deleteProduct(
                product.id!,
              );

              if (!controller.hasError) {
                Get.back();
              }
            },
            child: const Text(
              'حذف',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _money(int value) {
    return MoneyUtils.formatMoney(
      value,
      symbol: 'د.أ',
    );
  }
}

// ============================================================
// UI Components
// ============================================================

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _TinyBadge({
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}