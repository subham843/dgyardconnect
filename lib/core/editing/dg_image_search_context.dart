/// Search hints passed into image search (product / category / brand names).
class DgImageSearchContext {
  const DgImageSearchContext({
    this.productName,
    this.categoryName,
    this.brandName,
  });

  final String? productName;
  final String? categoryName;
  final String? brandName;

  String buildSearchQuery() {
    return [productName, categoryName, brandName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
}
