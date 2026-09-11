/// تعبير SQL موحّد لكمية المخزون الموقّعة بالوحدة الأساسية.
/// الأنواع الجديدة (WASTE / EXPIRED_RETURN) تُنقص المخزون مثل البيع.
class InventoryStockSql {
  InventoryStockSql._();

  static String signedQuantityCase({
    String typeColumn = 'type',
    String quantityColumn = 'quantity',
  }) =>
      '''
        CASE
          WHEN $typeColumn IN ('PURCHASE','SALE_RETURN','TRANSFER_IN')
            THEN $quantityColumn
          WHEN $typeColumn IN ('SALE','PURCHASE_RETURN','TRANSFER_OUT','WASTE','EXPIRED_RETURN')
            THEN -$quantityColumn
          ELSE 0
        END
      ''';
}
