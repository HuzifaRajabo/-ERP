import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/party_controller.dart';
import '../../models/party_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../shared/shared_components.dart';

class PartyListScreen extends GetView<PartyController> {
  const PartyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأطراف'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshParties,
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: controller),
          _FilterChips(controller: controller),
          const Expanded(child: _PartyList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed('/party-form'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==============================
// Search Bar
// ==============================

class _SearchBar extends StatelessWidget {
  final PartyController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Obx(
        () => AppSearchField(
          hint: 'بحث عن طرف...',
          onChanged: controller.search,
          onClear: controller.searchKeyword.value.isNotEmpty
              ? controller.clearSearch
              : null,
        ),
      ),
    );
  }
}

// ==============================
// Filter Chips
// ==============================

class _FilterChips extends StatelessWidget {
  final PartyController controller;

  const _FilterChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _Chip(
              label: 'الكل',
              selected: controller.selectedType.value == null,
              onTap: () => controller.filterByType(null),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'عملاء',
              selected: controller.selectedType.value == PartyType.customer,
              color: AppColors.primary,
              onTap: () => controller.filterByType(PartyType.customer),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'موردين',
              selected: controller.selectedType.value == PartyType.supplier,
              color: AppColors.warning,
              onTap: () => controller.filterByType(PartyType.supplier),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'كلاهما',
              selected: controller.selectedType.value == PartyType.both,
              color: Theme.of(context).colorScheme.secondary,
              onTap: () => controller.filterByType(PartyType.both),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

// ==============================
// Party List
// ==============================

class _PartyList extends GetView<PartyController> {
  const _PartyList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading) {
        return const AppLoadingState();
      }

      if (controller.hasError) {
        return _ErrorView(
          message: controller.errorMessage.value ?? 'خطأ غير معروف',
          onRetry: controller.refreshParties,
        );
      }

      if (controller.isEmpty) {
        return _EmptyView(
          isSearching: controller.searchKeyword.value.isNotEmpty,
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            controller.loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: controller.refreshParties,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount:
                controller.parties.length + (controller.hasMore.value ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == controller.parties.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _PartyCard(party: controller.parties[index]);
            },
          ),
        ),
      );
    });
  }
}

// ==============================
// Party Card
// ==============================

class _PartyCard extends GetView<PartyController> {
  final PartyModel party;

  const _PartyCard({required this.party});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => Get.toNamed('/party-details', arguments: party),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: _typeColor(party.type).withOpacity(0.15),
          child: Icon(_typeIcon(party.type), color: _typeColor(party.type)),
        ),
        title: Text(
          party.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (party.phone != null)
              Text(party.phone!, style: TextStyle(color: Colors.grey[600])),
            if (party.address != null)
              Text(
                party.address!,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            _TypeBadge(type: party.type),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon:               Icon(
                Icons.edit_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => Get.toNamed('/party-form', arguments: party),
            ),
            IconButton(
              icon:               Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف الطرف'),
        content: Text('هل تريد حذف "${party.name}"؟'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteParty(party.id!);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _typeColor(PartyType type) => switch (type) {
    PartyType.customer => Colors.blue,
    PartyType.supplier => Colors.orange,
    PartyType.both => Colors.purple,
  };

  IconData _typeIcon(PartyType type) => switch (type) {
    PartyType.customer => Icons.person_outline,
    PartyType.supplier => Icons.local_shipping_outlined,
    PartyType.both => Icons.people_outline,
  };
}

// ==============================
// Type Badge
// ==============================

class _TypeBadge extends StatelessWidget {
  final PartyType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      PartyType.customer => ('عميل', AppColors.primary),
      PartyType.supplier => ('مورد', AppColors.warning),
      PartyType.both => ('عميل ومورد', Theme.of(context).colorScheme.secondary),
    };

    return AppStatusBadge(label: label, color: color);
  }
}

// ==============================
// Empty & Error Views
// ==============================

class _EmptyView extends StatelessWidget {
  final bool isSearching;

  const _EmptyView({required this.isSearching});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: isSearching ? Icons.search_off : Icons.people_outline,
      title: isSearching ? 'لا توجد نتائج' : 'لا توجد أطراف',
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      message: message,
      onRetry: onRetry,
    );
  }
}
