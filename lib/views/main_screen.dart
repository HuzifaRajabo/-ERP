import 'package:erp/bindings/party_binding.dart';
import 'package:erp/bindings/product_binding.dart';
import '../bindings/invoice_binding.dart';
import '../bindings/inventory_binding.dart';

import 'product/product_list_screen.dart';
import 'party/party_list_screen.dart';
import 'invoice/invoice_list_screen.dart';
import 'inventory/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MainScreen extends StatelessWidget {
  MainScreen({super.key}){
    ProductBinding().dependencies();
    PartyBinding().dependencies();
    InvoiceBinding().dependencies();
    InventoryBinding().dependencies();
  }

  final RxInt currentIndex = 0.obs;

  final List<Widget> _pages = [
    const HomeScreen(),
    const ProductListScreen(),
    const PartyListScreen(),
    const InvoiceListScreen(),
    const InventoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      body: _pages[currentIndex.value],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex.value,
        onTap: (index) => currentIndex.value = index,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
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
          // BottomNavigationBar
          BottomNavigationBarItem(
            icon: Icon(Icons.warehouse_outlined),
            activeIcon: Icon(Icons.warehouse),
            label: 'المستودع',
          ),
        ],
      ),
    ));
  }
}

// ==============================
// Home Screen
// ==============================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 80, color: Colors.blue.shade300),
            const SizedBox(height: 16),
            const Text(
              'مرحباً بك في نظام ERP',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'استخدم القائمة أدناه للتنقل',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}