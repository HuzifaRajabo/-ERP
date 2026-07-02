import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/party_controller.dart';
import '../../models/party_model.dart';

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
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ==============================
          // Header
          // ==============================

          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: _typeColor(party.type).withOpacity(0.15),
              child: Icon(
                _typeIcon(party.type),
                size: 40,
                color: _typeColor(party.type),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              party.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(child: _TypeBadge(type: party.type)),
          const SizedBox(height: 24),

          // ==============================
          // Info
          // ==============================

          if (party.phone != null)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'الهاتف',
              value: party.phone!,
              color: Colors.green,
            ),

          if (party.address != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'العنوان',
              value: party.address!,
              color: Colors.teal,
            ),
          ],

          if (party.createdAt != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'تاريخ الإضافة',
              value: party.createdAt!,
              color: Colors.purple,
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
    Get.dialog(AlertDialog(
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
          child: const Text('حذف', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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
      PartyType.customer => ('عميل', Colors.blue),
      PartyType.supplier => ('مورد', Colors.orange),
      PartyType.both => ('عميل ومورد', Colors.purple),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}