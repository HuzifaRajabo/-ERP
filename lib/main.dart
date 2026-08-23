import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bindings/app_binding.dart';
import 'core/database/database_helper.dart';
import 'views/main_screen.dart';
import 'views/product/category_list_screen.dart';
import 'views/product/product_details_screen.dart';
import 'views/product/product_form_screen.dart';
import 'views/party/party_details_screen.dart';
import 'views/party/party_form_screen.dart';
import 'views/invoice/invoice_details_screen.dart';
import 'views/invoice/invoice_form_screen.dart';
import 'views/debts/debts_screen.dart';
import 'views/debts/party_invoices_screen.dart';
import 'views/invoice/return_details_screen.dart';
import 'views/invoice/return_form_screen.dart';
import 'views/expense/expense_list_screen.dart';
import 'views/expense/expense_form_screen.dart';
import 'views/report/report_screen.dart';

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
      initialBinding: AppBinding(), // ← يُشغَّل مرة واحدة عند البدء
      initialRoute: '/',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      getPages: [
        GetPage(
          name: '/',
          page: () => MainScreen(),
          // ← لا binding هنا
        ),
        GetPage(name: '/product-form', page: () => const ProductFormScreen()),
        GetPage(
          name: '/product-categories',
          page: () => const ProductCategoryListScreen(),
        ),
        GetPage(
          name: '/product-details',
          page: () => const ProductDetailsScreen(),
        ),
        GetPage(name: '/party-form', page: () => const PartyFormScreen()),
        GetPage(name: '/party-details', page: () => const PartyDetailsScreen()),
        GetPage(name: '/invoice-form', page: () => const InvoiceFormScreen()),
        GetPage(
          name: '/invoice-details',
          page: () => const InvoiceDetailsScreen(),
        ),
        GetPage(
          name: '/party-invoices',
          page: () => const PartyInvoicesScreen(),
        ),
        GetPage(name: '/debts', page: () => const DebtsScreen()),
        GetPage(name: '/expense-list', page: () => const ExpenseListScreen()),
        GetPage(name: '/expense-form', page: () => const ExpenseFormScreen()),
        GetPage(name: '/reports', page: () => const ReportScreen()),
        GetPage(name: '/return-form', page: () => const ReturnFormScreen()),
        GetPage(
          name: '/return-details',
          page: () => const ReturnDetailsScreen(),
        ),
      ],
    );
  }
}
