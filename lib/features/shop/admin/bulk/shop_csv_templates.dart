import 'shop_bulk_import_type.dart';

abstract final class ShopCsvTemplates {
  static List<String> headersFor(ShopBulkImportType type) {
    final line = sampleFor(type).trim().split('\n').first;
    return line.split(',').map((e) => e.trim()).toList();
  }

  static String sampleFor(ShopBulkImportType type) => switch (type) {
        ShopBulkImportType.categories => _categories,
        ShopBulkImportType.attributeMaster => _attributeMaster,
        ShopBulkImportType.attributeOptions => _attributeOptions,
        ShopBulkImportType.attributeGroups => _attributeGroups,
        ShopBulkImportType.brands => _brands,
        ShopBulkImportType.subCategories => _subCategories,
        ShopBulkImportType.products => _products,
        ShopBulkImportType.productAttributes => _productAttributes,
        ShopBulkImportType.suppliers => _suppliers,
        ShopBulkImportType.customers => _customers,
      };

  static const _categories = '''
name,sort_order,is_active,slug,seo_title,meta_description
CCTV,0,true,cctv,CCTV Security,CCTV cameras and accessories
Networking,1,true,networking,Networking,LAN and Wi-Fi equipment
''';

  static const _attributeMaster = '''
key,label,data_type,unit,is_required,use_in_filter,use_in_calculator,is_active,allowed_values
resolution,Resolution,select,,false,true,false,true,2MP|4MP|8MP
cable_length,Cable length,number,m,false,false,false,true,
night_vision,Night vision,bool,,false,true,false,true,
''';

  static const _attributeOptions = '''
attribute_key,label,sort_order,is_active
resolution,2MP,0,true
resolution,4MP,1,true
resolution,8MP,2,true
''';

  static const _attributeGroups = '''
group_name,description,is_active,attribute_keys,required_attribute_keys
Camera specs,Specs for IP cameras,true,resolution|night_vision,resolution
Cabling,Cable attributes,true,cable_length,
''';

  static const _brands = '''
name,is_active
Hikvision,true
D-Link,true
''';

  /// Images are not imported — upload in Sub category editor.
  static const _subCategories = '''
category_slug,name,description,sort_order,is_active,gst_percentage,hsn_code,attribute_group_names,slug,seo_title,meta_description
cctv,IP Cameras,Indoor and outdoor IP cameras,0,true,18,85258090,Camera specs,ip-cameras,IP Cameras,Buy IP cameras online
cctv,Cables,Network and power cables,1,true,18,85444299,Cabling,cables,Cables,CCTV cabling
''';

  /// `calculator_family_name`: one name OR comma-separated multi
  /// (e.g. `HD CCTV, IP CCTV, Computer Assemble`).
  static const _products = '''
category_slug,sub_category_slug,name,sku,brand_name,barcode,model_name,hsn_code,gst_percentage,use_gst_override,tax_class,cost_price,mrp,online_price,dealer_price,distributor_price,warranty,warranty_months,track_serial,track_batch,short_description,description,technical_notes,installation_notes,is_active,qty_on_hand,reorder_level,unit,stock_status,show_in_calculator,calculator_family_name,calculator_priority,datasheet_urls,brochure_urls,slug,seo_title,seo_description
cctv,ip-cameras,4MP Dome Camera,,Hikvision,,DS-2CD1143G0-I,85258090,18,false,,2500,4500,3999,3600,3400,2 Years,24,false,false,4MP indoor dome,Full HD dome with night vision,IP66 rated,Wall/ceiling mount,true,0,5,pcs,in_stock,false,,0,https://example.com/datasheet.pdf,,4mp-dome-camera,4MP Dome Camera,4MP dome CCTV camera
''';

  static const _productAttributes = '''
product_sku,attribute_key,value
4mp-dome-camera,resolution,4MP
4mp-dome-camera,night_vision,true
4mp-dome-camera,cable_length,3
''';

  static const _suppliers = '''
code,name,contact_name,email,phone,gstin,is_active
SUP01,ABC Distributors,Rajesh,raj@abc.com,9876543210,27AAAAA0000A1Z5,true
''';

  static const _customers = '''
code,name,email,phone,gstin,is_active
CUST01,Green Tech Solutions,info@greentech.com,9123456780,27BBBBB0000B1Z6,true
''';
}
