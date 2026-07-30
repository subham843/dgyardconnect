enum ShopBulkImportType {
  categories,
  attributeMaster,
  attributeOptions,
  attributeGroups,
  brands,
  subCategories,
  products,
  productAttributes,
  suppliers,
  customers,
}

extension ShopBulkImportTypeX on ShopBulkImportType {
  String get label => switch (this) {
        ShopBulkImportType.categories => 'Categories',
        ShopBulkImportType.attributeMaster => 'Attribute master',
        ShopBulkImportType.attributeOptions => 'Attribute options',
        ShopBulkImportType.attributeGroups => 'Attribute groups',
        ShopBulkImportType.brands => 'Brands',
        ShopBulkImportType.subCategories => 'Sub categories',
        ShopBulkImportType.products => 'Products',
        ShopBulkImportType.productAttributes => 'Product attribute values',
        ShopBulkImportType.suppliers => 'Suppliers',
        ShopBulkImportType.customers => 'Customers',
      };

  String get exportFilename => switch (this) {
        ShopBulkImportType.categories => 'shop_categories_export.csv',
        ShopBulkImportType.attributeMaster => 'shop_attribute_master_export.csv',
        ShopBulkImportType.attributeOptions => 'shop_attribute_options_export.csv',
        ShopBulkImportType.attributeGroups => 'shop_attribute_groups_export.csv',
        ShopBulkImportType.brands => 'shop_brands_export.csv',
        ShopBulkImportType.subCategories => 'shop_sub_categories_export.csv',
        ShopBulkImportType.products => 'shop_products_export.csv',
        ShopBulkImportType.productAttributes => 'shop_product_attributes_export.csv',
        ShopBulkImportType.suppliers => 'shop_suppliers_export.csv',
        ShopBulkImportType.customers => 'shop_customers_export.csv',
      };

  String get sampleFilename => switch (this) {
        ShopBulkImportType.categories => 'shop_categories_sample.csv',
        ShopBulkImportType.attributeMaster => 'shop_attribute_master_sample.csv',
        ShopBulkImportType.attributeOptions => 'shop_attribute_options_sample.csv',
        ShopBulkImportType.attributeGroups => 'shop_attribute_groups_sample.csv',
        ShopBulkImportType.brands => 'shop_brands_sample.csv',
        ShopBulkImportType.subCategories => 'shop_sub_categories_sample.csv',
        ShopBulkImportType.products => 'shop_products_sample.csv',
        ShopBulkImportType.productAttributes => 'shop_product_attributes_sample.csv',
        ShopBulkImportType.suppliers => 'shop_suppliers_sample.csv',
        ShopBulkImportType.customers => 'shop_customers_sample.csv',
      };

  /// Row-based imports (product attribute values) have no deletable entities here.
  bool get supportsBulkDelete => this != ShopBulkImportType.productAttributes;

  int get recommendedOrder => switch (this) {
        ShopBulkImportType.categories => 1,
        ShopBulkImportType.attributeMaster => 2,
        ShopBulkImportType.attributeOptions => 3,
        ShopBulkImportType.attributeGroups => 4,
        ShopBulkImportType.brands => 5,
        ShopBulkImportType.subCategories => 6,
        ShopBulkImportType.products => 7,
        ShopBulkImportType.productAttributes => 8,
        ShopBulkImportType.suppliers => 9,
        ShopBulkImportType.customers => 10,
      };
}
