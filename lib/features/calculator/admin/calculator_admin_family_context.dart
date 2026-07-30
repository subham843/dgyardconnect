import 'package:flutter/foundation.dart';

import '../../shop/data/shop_catalog_repository.dart';
import '../../shop/domain/shop_attribute.dart';
import '../../shop/domain/shop_category.dart';
import '../data/calculator_repository.dart';
import '../domain/calculator_models.dart';

/// Shared selection + cache for Calculator admin pages (Families / Options / Rules).
class CalculatorAdminFamilyContext extends ChangeNotifier {
  CalculatorAdminFamilyContext._();
  static final CalculatorAdminFamilyContext instance =
      CalculatorAdminFamilyContext._();

  final CalculatorRepository _repo = CalculatorRepository();
  final ShopCatalogRepository _catalog = ShopCatalogRepository();

  List<CalculatorFamily> families = [];
  List<ShopAttributeMaster> calcAttributes = [];
  List<ShopSubCategory> subCategories = [];
  final linksByFamily = <String, List<CalculatorFamilyAttributeLink>>{};
  final pathsByFamily = <String, List<CalculatorFamilyOptionPath>>{};
  final groupsByFamily = <String, List<CalculatorQuestionGroup>>{};

  String? selectedFamilyId;
  bool loading = false;
  String? error;

  CalculatorFamily? get selectedFamily {
    final id = selectedFamilyId;
    if (id == null) return null;
    return families.where((f) => f.id == id).firstOrNull;
  }

  List<CalculatorFamilyAttributeLink> get selectedLinks =>
      linksByFamily[selectedFamilyId] ?? const [];

  List<CalculatorFamilyOptionPath> get selectedPaths =>
      pathsByFamily[selectedFamilyId] ?? const [];

  List<CalculatorQuestionGroup> get selectedGroups =>
      groupsByFamily[selectedFamilyId] ?? const [];

  Future<void> ensureLoaded({bool force = false}) async {
    if (loading) return;
    if (!force && families.isNotEmpty) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      families = await _repo.listFamilies(activeOnly: false);
      calcAttributes = await _catalog.listCalculatorAttributes();
      subCategories = await _catalog.listAllSubCategories(activeOnly: true);
      linksByFamily.clear();
      pathsByFamily.clear();
      groupsByFamily.clear();
      for (final f in families) {
        linksByFamily[f.id] = await _repo.listFamilyAttributeLinks(f.id);
        pathsByFamily[f.id] = await _repo.listFamilyOptionPaths(f.id);
        groupsByFamily[f.id] = await _repo.listQuestionGroups(f.id);
      }
      if (selectedFamilyId != null &&
          !families.any((f) => f.id == selectedFamilyId)) {
        selectedFamilyId = null;
      }
      // Auto-pick a family so Groups / Options / Rules are never blank by default.
      if (selectedFamilyId == null && families.isNotEmpty) {
        selectedFamilyId = families.first.id;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSelectedFamily() async {
    final id = selectedFamilyId;
    if (id == null) return;
    linksByFamily[id] = await _repo.listFamilyAttributeLinks(id);
    pathsByFamily[id] = await _repo.listFamilyOptionPaths(id);
    groupsByFamily[id] = await _repo.listQuestionGroups(id);
    final updated = await _repo.listFamilies(activeOnly: false);
    families = updated;
    notifyListeners();
  }

  void selectFamily(String? id) {
    if (selectedFamilyId == id) return;
    selectedFamilyId = id;
    notifyListeners();
  }

  void selectFamilyObject(CalculatorFamily family) {
    selectFamily(family.id);
  }

  ShopAttributeMaster? attributeById(String id) =>
      calcAttributes.where((a) => a.id == id).firstOrNull;
}
