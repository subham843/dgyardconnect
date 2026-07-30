/// One row in the bulk delete picker.
class ShopBulkListItem {
  const ShopBulkListItem({
    required this.id,
    required this.label,
    this.subtitle,
    this.parentId,
  });

  final String id;
  final String label;
  final String? subtitle;

  /// e.g. attribute_id when deleting attribute_options.
  final String? parentId;
}
