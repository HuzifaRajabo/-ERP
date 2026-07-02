import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/database/database_helper.dart';
import 'bindings/product_binding.dart';
import 'bindings/party_binding.dart';
import 'bindings/invoice_binding.dart';
import 'bindings/inventory_binding.dart';
import 'views/main_screen.dart';
import 'views/product/product_details_screen.dart';
import 'views/product/product_form_screen.dart';
import 'views/party/party_details_screen.dart';
import 'views/party/party_form_screen.dart';
import 'views/invoice/invoice_details_screen.dart';
import 'views/invoice/invoice_form_screen.dart';
import 'views/inventory/inventory_screen.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة قاعدة البيانات
  await DatabaseHelper.instance.database;

  runApp(const MyApp());

}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ERP',
      initialRoute: '/',
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      getPages: [
        GetPage(
          name: '/',
          page: () => MainScreen(),
        ),
        GetPage(
          name: '/product-form',
          page: () => const ProductFormScreen(),
          binding: ProductBinding(),
        ),
        GetPage(
          name: '/product-details',
          page: () => const ProductDetailsScreen(),
          binding: ProductBinding(),
        ),
        GetPage(
          name: '/party-form',
          page: () => const PartyFormScreen(),
          binding: PartyBinding(),
        ),
        GetPage(
          name: '/party-details',
          page: () => const PartyDetailsScreen(),
          binding: PartyBinding(),
        ),
        GetPage(
          name: '/invoice-form',
          page: () => const InvoiceFormScreen(),
          binding: InvoiceBinding(),
        ),
        GetPage(
          name: '/invoice-details',
          page: () => const InvoiceDetailsScreen(),
          binding: InvoiceBinding(),
        ),
        GetPage(
          name: '/inventory',
          page: () => const InventoryScreen(),
          binding: InventoryBinding(),
        ),
      ],
    );
  }
}