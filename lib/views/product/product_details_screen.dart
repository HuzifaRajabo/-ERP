import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/money_utils.dart';
import '../../models/product_model.dart';
import '../../models/product_unit_model.dart';
import '../../views/shared/shared_components.dart';

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
              color: AppColors.error,
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
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _StatusBadge(
                          icon: Icons.check_circle_outline,
                          text: 'فعال',
                          color: Colors.green,
                        ),
                        if (product.categoryName != null &&
                            product.categoryName!.trim().isNotEmpty)
                          _StatusBadge(
                            icon: Icons.category_outlined,
                            text: product.categoryName!,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (product.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.md + AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      product.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // Units
  // ============================================================

  Widget _buildUnitsSection() {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'الوحدات والأسعار',
            subtitle: '${units.length} وحدة',
          ),

          const SizedBox(height: AppSpacing.lg),

          if (isLoadingUnits)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'الوحدة',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'التحويل',
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'التكلفة',
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'البيع',
              style: Theme.of(context).textTheme.labelSmall,
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: unit.isDefaultSellUnit
            ? Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.035)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: unit.isDefaultSellUnit
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.20)
              : AppColors.border,
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
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit.isBaseUnit) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const _TinyBadge(text: 'أساسية'),
                    ],
                  ],
                ),
              ),

              Expanded(
                flex: 2,
                child: Text(
                  _conversionText(unit),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              Expanded(
                flex: 2,
                child: Text(
                  unit.costPrice == null ? '-' : _money(unit.costPrice!),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),

              Expanded(
                flex: 2,
                child: Text(
                  _money(unit.defaultSalePrice),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
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
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 38,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'لا توجد وحدات معرفة لهذا المنتج',
            style: TextStyle(fontWeight: FontWeight.w600),
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
      padding: EdgeInsets.all(AppSpacing.md + AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
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
              color: AppColors.success,
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
    AppConfirmDialog.show(
      context,
      title: 'حذف المنتج',
      message: 'هل تريد حذف "${product.name}"؟',
      confirmLabel: 'حذف',
      cancelLabel: 'إلغاء',
      isDestructive: true,
    ).then((confirmed) async {
      if (confirmed != true || product.id == null) return;

      await controller.deleteProduct(product.id!);

      if (!controller.hasError) {
        Get.back();
      }
    });
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
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}