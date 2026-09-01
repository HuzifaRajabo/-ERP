import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../core/utils/money_utils.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/product_unit_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../views/shared/shared_components.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final ProductController controller =
      Get.find<ProductController>();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _baseUnitController;

  ProductModel? get product =>
      Get.arguments as ProductModel?;

  bool get isEditing => product != null;

  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();

    final currentProduct = product;

    _nameController = TextEditingController(
      text: currentProduct?.name ?? '',
    );

    _descriptionController = TextEditingController(
      text: currentProduct?.description ?? '',
    );

    _baseUnitController = TextEditingController(
      text: 'قطعة',
    );

    _selectedCategoryId = currentProduct?.categoryId;

    _initializeUnits();
  }

  Future<void> _initializeUnits() async {
    controller.clearTempUnits();

    if (isEditing) {
      await controller.loadProductUnits(product!.id!);

      if (!mounted) return;

      final baseUnit = controller.tempUnits
          .firstWhereOrNull((unit) => unit.isBaseUnit);

      if (baseUnit != null) {
        _baseUnitController.text = baseUnit.unitName;
      }

      setState(() {});
      return;
    }

    final baseUnit = controller.buildDefaultBaseUnit(
      costPrice: 0,
      salePrice: 0,
      unitName: 'قطعة',
    );

    controller.addTempUnit(baseUnit);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _baseUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل المنتج' : 'إضافة منتج',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInformation(),
            const SizedBox(height: 18),
            _buildUnitsManager(),
            const SizedBox(height: 18),
            _buildSaveError(),
            const SizedBox(height: 8),
            _buildSaveButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Basic Information
  // ============================================================

  Widget _buildBasicInformation() {
    return _SectionCard(
      title: 'البيانات الأساسية',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          _FormField(
            controller: _nameController,
            label: 'اسم المنتج',
            hint: 'مثال: مياه معدنية',
            icon: Icons.inventory_2_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'اسم المنتج مطلوب';
              }

              return null;
            },
          ),

          const SizedBox(height: 14),

          _FormField(
            controller: _descriptionController,
            label: 'الوصف',
            hint: 'وصف اختياري للمنتج',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),

          const SizedBox(height: 14),

          _buildCategoryDropdown(),

          const SizedBox(height: 14),

          _FormField(
            controller: _baseUnitController,
            label: 'الوحدة الأساسية',
            hint: 'قطعة',
            icon: Icons.straighten_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الوحدة الأساسية مطلوبة';
              }

              return null;
            },
            onChanged: (value) {
              _syncBaseUnitName(value);
            },
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الوحدة الأساسية هي الوحدة التي يحسب بها المخزون، '
              'ومعامل تحويلها يساوي 1.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Obx(
      () => DropdownButtonFormField<int?>(
        initialValue: _selectedCategoryId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'التصنيف',
          prefixIcon: const Icon(
            Icons.category_outlined,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('بدون تصنيف'),
          ),
          ...controller.categories
              .where((category) => category.isActive)
              .map(
                (CategoryModel category) {
                  return DropdownMenuItem<int?>(
                    value: category.id,
                    child: Text(category.name),
                  );
                },
              ),
        ],
        onChanged: (value) {
          setState(() {
            _selectedCategoryId = value;
          });
        },
      ),
    );
  }

  void _syncBaseUnitName(String value) {
    final name = value.trim();

    final baseIndex = controller.tempUnits.indexWhere(
      (unit) => unit.isBaseUnit,
    );

    if (baseIndex == -1 || name.isEmpty) return;

    final base = controller.tempUnits[baseIndex];

    controller.updateTempUnit(
      baseIndex,
      base.copyWith(
        unitName: name,
        conversionFactor: 1,
        isBaseUnit: true,
      ),
    );
  }

  // ============================================================
  // Distribution Units Manager
  // ============================================================

  Widget _buildUnitsManager() {
    return _SectionCard(
      title: 'إدارة وحدات التوزيع',
      icon: Icons.all_inbox_outlined,
      child: Obx(
        () {
          final units = controller.tempUnits;

          return Column(
            children: [
              if (units.isEmpty)
                _buildEmptyUnits()
              else
                ...units.asMap().entries.map(
                  (entry) => _buildUnitCard(
                    entry.key,
                    entry.value,
                  ),
                ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openUnitDialog,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'إضافة وحدة توزيع',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyUnits() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 42,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          const Text(
            'لا توجد وحدات توزيع',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'أضف الوحدة الأساسية أو وحدات مثل كرتون، طرد، صندوق...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCard(
    int index,
    ProductUnitModel unit,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unit.isDefaultSellUnit
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(.35)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    unit.isBaseUnit
                        ? Icons.star_outline
                        : Icons.inventory_2_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.unitName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        _conversionText(unit),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (unit.isBaseUnit)
                            const _SmallBadge(
                              icon: Icons.star_outline,
                              text: 'أساسية',
                            ),
                          if (unit.canBuy)
                            const _SmallBadge(
                              icon: Icons.shopping_cart_outlined,
                              text: 'شراء',
                            ),
                          if (unit.canSell)
                            const _SmallBadge(
                              icon: Icons.sell_outlined,
                              text: 'بيع',
                            ),
                          if (unit.isDefaultSellUnit)
                            const _SmallBadge(
                              icon: Icons.check_circle_outline,
                              text: 'بيع افتراضي',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editUnit(index);
                    } else if (value == 'delete') {
                      _deleteUnit(index);
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      if (!unit.isBaseUnit)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 8),
                              Text('حذف'),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ),

            const Divider(height: 24),

            Row(
              children: [
                Expanded(
                  child: _UnitPrice(
                    label: 'التكلفة',
                    value: unit.costPrice == null
                        ? '-'
                        : _money(unit.costPrice!),
                    icon: Icons.price_change_outlined,
                  ),
                ),
                Expanded(
                  child: _UnitPrice(
                    label: 'سعر البيع',
                    value: _money(
                      unit.defaultSalePrice,
                    ),
                    icon: Icons.sell_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _conversionText(ProductUnitModel unit) {
    final factor = _formatNumber(
      unit.conversionFactor,
    );

    if (unit.isBaseUnit) {
      return '1 ${unit.unitName} = 1 ${_baseUnitController.text}';
    }

    return '1 ${unit.unitName} = $factor '
        '${_baseUnitController.text}';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // Unit Dialog
  // ============================================================

  Future<void> _openUnitDialog() async {
    final unit = await showDialog<ProductUnitModel>(
      context: context,
      builder: (_) => UnitFormDialog(
        productId: product?.id ?? 0,
        baseUnitName: _baseUnitController.text.trim(),
        existingUnits: controller.tempUnits.toList(),
      ),
    );

    if (unit == null) return;

    _addUnitWithDefaultHandling(unit);
  }

  Future<void> _editUnit(int index) async {
    final oldUnit = controller.tempUnits[index];

    final unit = await showDialog<ProductUnitModel>(
      context: context,
      builder: (_) => UnitFormDialog(
        productId: product?.id ?? 0,
        baseUnitName: _baseUnitController.text.trim(),
        existingUnits: controller.tempUnits.toList(),
        initialUnit: oldUnit,
      ),
    );

    if (unit == null) return;

    if (unit.isDefaultSellUnit) {
      _clearDefaultSellUnitExcept(index);
    }

    controller.updateTempUnit(index, unit);
  }

  void _addUnitWithDefaultHandling(
    ProductUnitModel unit,
  ) {
    if (unit.isDefaultSellUnit) {
      for (var i = 0; i < controller.tempUnits.length; i++) {
        final old = controller.tempUnits[i];

        controller.updateTempUnit(
          i,
          old.copyWith(
            isDefaultSellUnit: false,
          ),
        );
      }
    }

    controller.addTempUnit(unit);
  }

  void _clearDefaultSellUnitExcept(int exceptIndex) {
    for (var i = 0; i < controller.tempUnits.length; i++) {
      if (i == exceptIndex) continue;

      final old = controller.tempUnits[i];

      if (old.isDefaultSellUnit) {
        controller.updateTempUnit(
          i,
          old.copyWith(
            isDefaultSellUnit: false,
          ),
        );
      }
    }
  }

  void _deleteUnit(int index) {
    final unit = controller.tempUnits[index];

    if (unit.isBaseUnit) {
      Get.snackbar(
        'لا يمكن الحذف',
        'لا يمكن حذف الوحدة الأساسية للمنتج.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('حذف الوحدة'),
        content: Text(
          'هل تريد حذف وحدة "${unit.unitName}"؟',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.removeTempUnit(index);
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Save
  // ============================================================

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final units = controller.tempUnits.toList();

    if (units.isEmpty) {
      Get.snackbar(
        'بيانات ناقصة',
        'يجب إضافة وحدة توزيع واحدة على الأقل.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final baseUnit = units.firstWhereOrNull(
      (unit) => unit.isBaseUnit,
    );

    if (baseUnit == null) {
      Get.snackbar(
        'بيانات ناقصة',
        'يجب وجود وحدة أساسية واحدة للمنتج.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final productModel = ProductModel(
      id: product?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryId: _selectedCategoryId,
      categoryName: product?.categoryName,
      costPrice: baseUnit.costPrice ?? 0,
      salePrice: baseUnit.defaultSalePrice,
      createdAt: product?.createdAt,
    );

    final productId = await controller.saveProduct(
      productModel,
      units,
    );

    if (!mounted) return;

    if (productId != null) {
      Get.back(result: productId);
    }
  }

  Widget _buildSaveError() {
    return Obx(
      () {
        final message =
            controller.unitFormError.value;

        if (message == null || message.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.error,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Obx(
      () {
        final saving =
            controller.isSavingProduct.value;

        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: saving ? null : _saveProduct,
            icon: saving
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              saving
                  ? 'جاري الحفظ...'
                  : isEditing
                      ? 'حفظ تعديلات المنتج'
                      : 'حفظ المنتج',
            ),
          ),
        );
      },
    );
  }

  String _money(int value) {
    return MoneyUtils.formatMoney(
      value,
      symbol: '\$',
    );
  }
}

// ============================================================
// Unit Form Dialog
// ============================================================

class UnitFormDialog extends StatefulWidget {
  final int productId;
  final String baseUnitName;
  final List<ProductUnitModel> existingUnits;
  final ProductUnitModel? initialUnit;

  const UnitFormDialog({
    super.key,
    required this.productId,
    required this.baseUnitName,
    required this.existingUnits,
    this.initialUnit,
  });

  @override
  State<UnitFormDialog> createState() =>
      _UnitFormDialogState();
}

class _UnitFormDialogState
    extends State<UnitFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _factorController;
  late final TextEditingController _costController;
  late final TextEditingController _saleController;

  late bool _canBuy;
  late bool _canSell;
  late bool _isDefaultSellUnit;

  bool get isEditing =>
      widget.initialUnit != null;

  bool get isBaseUnit =>
      widget.initialUnit?.isBaseUnit ?? false;

  @override
  void initState() {
    super.initState();

    final unit = widget.initialUnit;

    _nameController = TextEditingController(
      text: unit?.unitName ?? '',
    );

    _factorController = TextEditingController(
      text: unit == null
          ? ''
          : _formatNumber(unit.conversionFactor),
    );

    _costController = TextEditingController(
      text: unit?.costPrice == null
          ? ''
          : MoneyUtils.formatInput(
              unit!.costPrice!,
            ),
    );

    _saleController = TextEditingController(
      text: unit == null
          ? ''
          : MoneyUtils.formatInput(
              unit.defaultSalePrice,
            ),
    );

    _canBuy = unit?.canBuy ?? true;
    _canSell = unit?.canSell ?? true;
    _isDefaultSellUnit =
        unit?.isDefaultSellUnit ?? false;

    if (isBaseUnit) {
      _isDefaultSellUnit =
          unit!.isDefaultSellUnit;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _factorController.dispose();
    _costController.dispose();
    _saleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isEditing
            ? 'تعديل وحدة التوزيع'
            : 'إضافة وحدة توزيع',
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  controller: _nameController,
                  label: 'اسم الوحدة',
                  hint: 'مثال: كرتون / طرد / صندوق',
                  icon: Icons.inventory_2_outlined,
                  validator: _validateName,
                ),

                const SizedBox(height: 14),

                _field(
                  controller: _factorController,
                  label: 'معامل التحويل',
                  hint: 'مثال: 30',
                  icon: Icons.sync_alt_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateFactor,
                ),

                const SizedBox(height: 14),

                _field(
                  controller: _costController,
                  label: 'سعر التكلفة',
                  hint: 'مثال: 100',
                  icon: Icons.price_change_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMoney,
                ),

                const SizedBox(height: 14),

                _field(
                  controller: _saleController,
                  label: 'سعر البيع الافتراضي',
                  hint: 'مثال: 125',
                  icon: Icons.sell_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMoney,
                ),

                const SizedBox(height: 10),

                _buildBuySwitch(),
                _buildSellSwitch(),
                _buildDefaultSellSwitch(),

                if (isBaseUnit)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(.08),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذه هي الوحدة الأساسية. '
                            'معامل التحويل لها يساوي 1 ولا يمكن تغيير ذلك.',
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: Text(
            isEditing ? 'حفظ' : 'إضافة',
          ),
        ),
      ],
    );
  }

  Widget _buildBuySwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _canBuy,
      title: const Text('تُستخدم للشراء'),
      subtitle: const Text(
        'السماح باستخدام هذه الوحدة في المشتريات',
      ),
      secondary: const Icon(
        Icons.shopping_cart_outlined,
      ),
      onChanged: (value) {
        setState(() {
          _canBuy = value;
        });
      },
    );
  }

  Widget _buildSellSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _canSell,
      title: const Text('تُستخدم للبيع'),
      subtitle: const Text(
        'السماح باستخدام هذه الوحدة في المبيعات',
      ),
      secondary: const Icon(
        Icons.sell_outlined,
      ),
      onChanged: (value) {
        setState(() {
          _canSell = value;

          if (!_canSell) {
            _isDefaultSellUnit = false;
          }
        });
      },
    );
  }

  Widget _buildDefaultSellSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _isDefaultSellUnit,
      title: const Text(
        'وحدة البيع الافتراضية',
      ),
      subtitle: Text(
        _canSell
            ? 'تستخدم افتراضياً عند بيع هذا المنتج'
            : 'يجب تفعيل البيع أولاً',
      ),
      secondary: const Icon(
        Icons.check_circle_outline,
      ),
      onChanged: !_canSell
          ? null
          : (value) {
              setState(() {
                _isDefaultSellUnit = value;
              });
            },
    );
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'اسم الوحدة مطلوب';
    }

    final duplicate = widget.existingUnits.any(
      (unit) =>
          unit.id != widget.initialUnit?.id &&
          unit.unitName.trim().toLowerCase() ==
              name.toLowerCase(),
    );

    if (duplicate) {
      return 'هذه الوحدة موجودة مسبقاً';
    }

    return null;
  }

  String? _validateFactor(String? value) {
    final factor = double.tryParse(
      value?.trim() ?? '',
    );

    if (factor == null || factor <= 0) {
      return 'أدخل معامل تحويل أكبر من صفر';
    }

    if (isBaseUnit && factor != 1) {
      return 'معامل الوحدة الأساسية يجب أن يكون 1';
    }

    return null;
  }

  String? _validateMoney(String? value) {
    final amount = MoneyUtils.parseAmount(value);

    if (amount == null || amount < 0) {
      return 'أدخل مبلغاً صحيحاً';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isDefaultSellUnit && !_canSell) {
      Get.snackbar(
        'بيانات غير صحيحة',
        'وحدة البيع الافتراضية يجب أن تكون مفعلة للبيع.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final factor = double.parse(
      _factorController.text.trim(),
    );

    final cost = MoneyUtils.parseAmount(
      _costController.text,
    );

    final sale = MoneyUtils.parseAmount(
      _saleController.text,
    );

    if (cost == null || sale == null) {
      return;
    }

    final old = widget.initialUnit;

    final result = ProductUnitModel(
      id: old?.id,
      productId: widget.productId,
      unitName: _nameController.text.trim(),
      conversionFactor: isBaseUnit ? 1 : factor,
      costPrice: cost,
      defaultSalePrice: sale,
      canBuy: _canBuy,
      canSell: _canSell,
      isDefaultSellUnit: _isDefaultSellUnit,
      isBaseUnit: old?.isBaseUnit ?? false,
      isActive: old?.isActive ?? true,
      createdAt: old?.createdAt,
      updatedAt: old?.updatedAt,
    );

    Get.back(result: result);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}

// ============================================================
// UI Components
// ============================================================

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
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
      ),
    );
  }
}

class _UnitPrice extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _UnitPrice({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallBadge({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}