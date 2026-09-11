import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/party_controller.dart';
import '../../controllers/feature_controller.dart';
import '../../models/business_config.dart';
import '../../models/party_model.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../packaging/packaging_screens.dart';
import '../shared/shared_components.dart';

class PartyDetailsScreen extends GetView<PartyController> {
  const PartyDetailsScreen({super.key});

  PartyModel get party => Get.arguments as PartyModel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = context.semantic;
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
            onPressed: () => _confirmDelete(context),
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
                    colors,
                    semantic,
                  ).withValues(alpha: 0.15),
                  child: Icon(
                    _typeIcon(party.type),
                    size: 32,
                    color: _typeColor(party.type, colors, semantic),
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
              color: semantic.success,
            ),

          if (party.address != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'العنوان',
              value: party.address!,
              color: semantic.info,
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
          if (featureEnabled(AppFeature.returnablePackaging) &&
              party.id != null &&
              (party.type == PartyType.customer ||
                  party.type == PartyType.both))
            PartyPackagingSection(partyId: party.id!),

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

  void _confirmDelete(BuildContext context) {
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
            child: Text('حذف', style: TextStyle(color: context.semantic.error)),
          ),
        ],
      ),
    );
  }

  Color _typeColor(PartyType type, ColorScheme colors, AppSemanticColors semantic) =>
      switch (type) {
        PartyType.customer => colors.primary,
        PartyType.supplier => semantic.warning,
        PartyType.both => colors.secondary,
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
                style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
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
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (type) {
      PartyType.customer => ('عميل', colors.primary),
      PartyType.supplier => ('مورد', context.semantic.warning),
      PartyType.both => ('عميل ومورد', Theme.of(context).colorScheme.secondary),
    };

    return AppStatusBadge(label: label, color: color);
  }
}