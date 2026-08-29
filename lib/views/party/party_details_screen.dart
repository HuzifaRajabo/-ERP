import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/party_controller.dart';
import '../../models/party_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../shared/shared_components.dart';

class PartyDetailsScreen extends GetView<PartyController> {
  const PartyDetailsScreen({super.key});

  PartyModel get party => Get.arguments as PartyModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(party.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Get.toNamed('/party-form', arguments: party),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _confirmDelete(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ==============================
          // Header
          // ==============================
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: _typeColor(
                    party.type,
                  ).withValues(alpha: 0.15),
                  child: Icon(
                    _typeIcon(party.type),
                    size: 32,
                    color: _typeColor(party.type),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  party.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                _TypeBadge(type: party.type),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ==============================
          // Info
          // ==============================
          if (party.phone != null)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'الهاتف',
              value: party.phone!,
              color: AppColors.success,
            ),

          if (party.address != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'العنوان',
              value: party.address!,
              color: AppColors.info,
            ),
          ],

          if (party.createdAt != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'تاريخ الإضافة',
              value: party.createdAt!,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
          const SizedBox(height: 32),

          // ==============================
          // Edit Button
          // ==============================
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed('/party-form', arguments: party),
              icon: const Icon(Icons.edit),
              label: const Text('تعديل'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف الطرف'),
        content: Text('هل تريد حذف "${party.name}"؟'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Get.back();
              await controller.deleteParty(party.id!);
              if (!controller.hasError) Get.back();
            },
            child: Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Color _typeColor(PartyType type) => switch (type) {
    PartyType.customer => AppColors.primary,
    PartyType.supplier => AppColors.warning,
    PartyType.both => AppColors.secondary,
  };

  IconData _typeIcon(PartyType type) => switch (type) {
    PartyType.customer => Icons.person_outline,
    PartyType.supplier => Icons.local_shipping_outlined,
    PartyType.both => Icons.people_outline,
  };
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final PartyType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      PartyType.customer => ('عميل', AppColors.primary),
      PartyType.supplier => ('مورد', AppColors.warning),
      PartyType.both => ('عميل ومورد', AppColors.secondary),
    };

    return AppStatusBadge(label: label, color: color);
  }
}
