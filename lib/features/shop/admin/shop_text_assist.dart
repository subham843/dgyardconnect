import '../../../core/editing/models/text_assist_models.dart';
import '../config/shop_seo_config.dart';

/// Rich context for shop admin AI assist (SEO uses company + brand + category).
abstract final class ShopTextAssist {
  ShopTextAssist._();

  static TextAssistContext withCompany({
    String? productName,
    String? categoryName,
    String? subCategoryName,
    String? brandName,
  }) =>
      TextAssistContext(
        companyName: ShopSeoConfig.companyName,
        companySite: ShopSeoConfig.companySiteHost,
        productName: productName,
        categoryName: categoryName,
        subCategoryName: subCategoryName,
        brandName: brandName,
      );

  static TextAssistContext category({required String categoryName}) => withCompany(categoryName: categoryName);

  static TextAssistContext brand({required String brandName}) => withCompany(brandName: brandName);

  static TextAssistContext subCategory({
    required String subCategoryName,
    String? categoryName,
  }) =>
      withCompany(subCategoryName: subCategoryName, categoryName: categoryName);

  static TextAssistContext product({
    required String productName,
    String? categoryName,
    String? subCategoryName,
    String? brandName,
  }) =>
      withCompany(
        productName: productName,
        categoryName: categoryName,
        subCategoryName: subCategoryName,
        brandName: brandName,
      );
}
