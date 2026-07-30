import '../../web_public/data/models/public_store_models.dart';
import '../../web_public/data/repositories/public_catalog_repository.dart';
import '../../web_public/state/public_cart.dart';
import '../data/quotation_repository.dart';
import '../domain/calculator_models.dart';

/// Adds calculator / quotation product lines into the public store cart.
class QuotationOrderHelper {
  QuotationOrderHelper({PublicCatalogRepository? catalog})
      : _catalog = catalog ?? PublicCatalogRepository();

  final PublicCatalogRepository _catalog;

  /// Returns how many product lines were added successfully.
  Future<int> addSuggestedLinesToCart(List<CalculatorSuggestedLine> lines) async {
    var added = 0;
    for (final line in lines) {
      final id = line.productId;
      if (id == null || id.isEmpty) continue;
      final row = await _catalog.getProductById(id);
      if (row == null) continue;
      final product = PublicProduct.fromRow(Map<String, dynamic>.from(row));
      final qty = line.qty.round().clamp(1, 999);
      PublicCart.instance.addProduct(product, qty: qty);
      added++;
    }
    return added;
  }

  Future<int> addQuotationLinesToCart(List<QuotationLine> lines) async {
    var added = 0;
    for (final line in lines) {
      final id = line.productId;
      if (id == null || id.isEmpty) continue;
      final row = await _catalog.getProductById(id);
      if (row == null) continue;
      final product = PublicProduct.fromRow(Map<String, dynamic>.from(row));
      final qty = line.qty.round().clamp(1, 999);
      PublicCart.instance.addProduct(product, qty: qty);
      added++;
    }
    return added;
  }
}
