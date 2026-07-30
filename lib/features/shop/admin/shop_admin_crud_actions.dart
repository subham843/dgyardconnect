import 'package:flutter/material.dart';

import '../data/shop_catalog_repository.dart';
import '../data/supabase_repository_base.dart';
import '../domain/shop_attribute.dart';
import '../domain/shop_category.dart';
import '../domain/shop_product.dart';
import '../data/shop_media_repository.dart';
import '../domain/shop_media_models.dart';
import '../../../../core/editing/dg_assist_text_field.dart';
import '../../../../core/editing/dg_image_search_context.dart';
import '../domain/shop_seo.dart';
import '../domain/brand_logo_layout.dart';
import 'widgets/brand_logo_field.dart';
import 'widgets/shop_entity_image_field.dart';
import 'shop_text_assist.dart';
import 'widgets/shop_seo_form_section.dart';

/// Shared edit / hide / delete dialogs for Supabase shop admin.
abstract final class ShopAdminCrudActions {
  static final _repo = ShopCatalogRepository();
  static final _mediaRepo = ShopMediaRepository();

  static Future<bool> confirmDelete(BuildContext context, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text('Remove "$label"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static Future<void> addCategory(BuildContext context, VoidCallback onDone) async {
    final name = TextEditingController();
    final sort = TextEditingController(text: '0');
    final seoTitle = TextEditingController();
    final metaDesc = TextEditingController();
    final slug = TextEditingController();
    ProcessedShopImage? pendingImage;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New category'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DgAssistTextField(
                    controller: name,
                    assistProfile: TextAssistProfile.entityName,
                    textCapitalization: TextCapitalization.words,
                    contextHints: ShopTextAssist.category(categoryName: name.text),
                    decoration: const InputDecoration(
                      labelText: 'Category name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sort order',
                      border: OutlineInputBorder(),
                      helperText: 'Lower numbers appear first',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShopEntityImageField(
                    label: 'Category image',
                    preset: ShopImagePreset.category,
                    entityName: name.text,
                    searchContext: DgImageSearchContext(categoryName: name.text),
                    pending: pendingImage,
                    onPendingChanged: (p) => setDialogState(() => pendingImage = p),
                    onClear: () => setDialogState(() => pendingImage = null),
                  ),
                  const SizedBox(height: 16),
                  ShopSeoFormSection(
                    seoTitleController: seoTitle,
                    metaDescriptionController: metaDesc,
                    slugController: slug,
                    contextHints: ShopTextAssist.category(categoryName: name.text),
                    slugAutoHint: 'Auto from name if empty, e.g. cctv-security',
                    canonicalPreview: name.text.trim().isEmpty
                        ? null
                        : ShopSeoService.resolveCategory(
                            input: ShopSeoAdminInput(
                              seoTitle: seoTitle.text,
                              metaDescription: metaDesc.text,
                              slugOverride: slug.text,
                            ),
                            name: name.text,
                            imageUrl: pendingImage?.publicUrl,
                          ).canonicalUrl,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (ok == true && name.text.trim().isNotEmpty) {
      final slugErr = ShopSeoFormSection.validateSlug(slug.text);
      if (slugErr != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(slugErr)));
        }
        for (final ctrl in [name, sort, seoTitle, metaDesc, slug]) {
          ctrl.dispose();
        }
        return;
      }
      try {
        final id = await _repo.createCategory(
          name: name.text.trim(),
          sortOrder: int.tryParse(sort.text.trim()) ?? 0,
          imagePublicUrl: pendingImage?.publicUrl,
          seo: ShopSeoAdminInput(
            seoTitle: seoTitle.text,
            metaDescription: metaDesc.text,
            slugOverride: slug.text,
          ),
        );
        if (id != null && pendingImage != null) {
          final up = await uploadPendingCategoryImage(categoryId: id, pending: pendingImage);
          if (up != null) await _mediaRepo.applyCategoryMedia(id, uploaded: up);
        }
        onDone();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category created')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.red.shade800),
          );
        }
      }
    }
    for (final ctrl in [name, sort, seoTitle, metaDesc, slug]) {
      ctrl.dispose();
    }
  }

  static Future<void> editCategory(BuildContext context, ShopCategory c, VoidCallback onDone) async {
    final fresh = await _repo.getCategory(c.id) ?? c;
    final name = TextEditingController(text: fresh.name);
    final sort = TextEditingController(text: '${fresh.sortOrder}');
    final seoTitle = TextEditingController(text: fresh.seo.seoTitle ?? '');
    final metaDesc = TextEditingController(text: fresh.seo.metaDescription ?? '');
    final slug = TextEditingController(text: fresh.slug);
    ProcessedShopImage? pendingImage;
    var existingImageUrl = fresh.imageUrl ?? fresh.seo.ogImage;
    var mediaCleared = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit category'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DgAssistTextField(
                    controller: name,
                    assistProfile: TextAssistProfile.entityName,
                    textCapitalization: TextCapitalization.words,
                    contextHints: ShopTextAssist.category(categoryName: name.text),
                    decoration: const InputDecoration(
                      labelText: 'Category name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sort order',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShopEntityImageField(
                    label: 'Category image',
                    preset: ShopImagePreset.category,
                    entityName: name.text,
                    searchContext: DgImageSearchContext(categoryName: name.text),
                    pending: pendingImage,
                    existingUrl: existingImageUrl,
                    onPendingChanged: (p) => setDialogState(() {
                      pendingImage = p;
                      mediaCleared = false;
                    }),
                    onClear: () => setDialogState(() {
                      pendingImage = null;
                      existingImageUrl = null;
                      mediaCleared = true;
                    }),
                  ),
                  const SizedBox(height: 16),
                  ShopSeoFormSection(
                    seoTitleController: seoTitle,
                    metaDescriptionController: metaDesc,
                    slugController: slug,
                    contextHints: ShopTextAssist.category(categoryName: name.text),
                    slugAutoHint: 'Auto from name if empty, e.g. cctv-security',
                    canonicalPreview: ShopSeoService.resolveCategory(
                      input: ShopSeoAdminInput(
                        seoTitle: seoTitle.text,
                        metaDescription: metaDesc.text,
                        slugOverride: slug.text,
                      ),
                      name: name.text,
                      existingSlug: fresh.slug,
                      imageUrl: pendingImage?.publicUrl ?? existingImageUrl,
                    ).canonicalUrl,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final slugErr = ShopSeoFormSection.validateSlug(slug.text);
      if (slugErr != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(slugErr)));
        }
        for (final ctrl in [name, sort, seoTitle, metaDesc, slug]) {
          ctrl.dispose();
        }
        return;
      }
      await _repo.updateCategory(
        c.id,
        name: name.text.trim(),
        sortOrder: int.tryParse(sort.text.trim()),
        imagePublicUrl: pendingImage?.publicUrl ?? existingImageUrl,
        existingSlug: fresh.slug,
        seo: ShopSeoAdminInput(
          seoTitle: seoTitle.text,
          metaDescription: metaDesc.text,
          slugOverride: slug.text,
        ),
      );
      if (mediaCleared && pendingImage == null) {
        await _mediaRepo.applyCategoryMedia(c.id, uploaded: null, clear: true);
      } else {
        final up = await uploadPendingCategoryImage(categoryId: c.id, pending: pendingImage);
        if (up != null) await _mediaRepo.applyCategoryMedia(c.id, uploaded: up);
      }
      onDone();
    }
    for (final ctrl in [name, sort, seoTitle, metaDesc, slug]) {
      ctrl.dispose();
    }
  }

  static Future<void> toggleCategoryActive(BuildContext context, ShopCategory c, VoidCallback onDone) async {
    await _repo.updateCategory(c.id, name: c.name, isActive: !c.isActive, existingSlug: c.slug);
    onDone();
  }

  static Future<void> deleteCategory(BuildContext context, ShopCategory c, VoidCallback onDone) async {
    if (!await confirmDelete(context, c.name)) return;
    await _repo.deleteCategory(c.id);
    onDone();
  }

  static Future<void> editSubCategory(BuildContext context, ShopSubCategory s, VoidCallback onDone) async {
    final name = TextEditingController(text: s.name);
    final sort = TextEditingController(text: '${s.sortOrder}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit sub category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sort order')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await _repo.updateSubCategory(s.id, name: name.text.trim(), sortOrder: int.tryParse(sort.text.trim()), existingSlug: s.slug);
      onDone();
    }
    name.dispose();
    sort.dispose();
  }

  static Future<void> toggleSubCategoryActive(BuildContext context, ShopSubCategory s, VoidCallback onDone) async {
    await _repo.updateSubCategory(s.id, name: s.name, isActive: !s.isActive, existingSlug: s.slug);
    onDone();
  }

  static Future<void> deleteSubCategory(BuildContext context, ShopSubCategory s, VoidCallback onDone) async {
    if (!await confirmDelete(context, s.name)) return;
    await _repo.deleteSubCategory(s.id);
    onDone();
  }

  static Future<void> editBrand(BuildContext context, ShopBrand b, VoidCallback onDone) async {
    final name = TextEditingController(text: b.name);
    final shortDesc = TextEditingController(text: b.shortDescription ?? '');
    final displayOrder = TextEditingController(text: b.displayOrder.toString());
    ProcessedShopImage? pendingLogo;
    var existingLogoUrl = b.logoUrl;
    var existingMime = b.logoMimeType;
    var logoLayout = b.logoLayout;
    var featured = b.isFeaturedOnHomepage;
    var mediaCleared = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit brand'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DgAssistTextField(
                    controller: name,
                    assistProfile: TextAssistProfile.entityName,
                    textCapitalization: TextCapitalization.words,
                    contextHints: ShopTextAssist.brand(brandName: name.text),
                    decoration: const InputDecoration(labelText: 'Brand name *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: shortDesc,
                    decoration: const InputDecoration(
                      labelText: 'Short description (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Shown on homepage brand cards',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Featured on homepage'),
                    subtitle: const Text('Trusted Brands section on public website'),
                    value: featured,
                    onChanged: (v) => setDialogState(() => featured = v),
                  ),
                  TextField(
                    controller: displayOrder,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display order',
                      border: OutlineInputBorder(),
                      hintText: 'Lower numbers appear first',
                    ),
                  ),
                  const SizedBox(height: 16),
                  BrandLogoField(
                    brandName: name.text,
                    layout: logoLayout,
                    existingLogoUrl: existingLogoUrl,
                    existingMimeType: existingMime,
                    pendingProcessed: pendingLogo,
                    onLayoutChanged: (layout) => setDialogState(() => logoLayout = layout),
                    onPendingChanged: (p) => setDialogState(() {
                      pendingLogo = p;
                      mediaCleared = false;
                    }),
                    onClear: () => setDialogState(() {
                      pendingLogo = null;
                      existingLogoUrl = null;
                      existingMime = null;
                      mediaCleared = true;
                      logoLayout = const BrandLogoLayout();
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await _repo.updateBrand(
        b.id,
        name: name.text.trim(),
        logoLayout: logoLayout,
        shortDescription: shortDesc.text,
        isFeaturedOnHomepage: featured,
        displayOrder: int.tryParse(displayOrder.text.trim()) ?? b.displayOrder,
      );
      if (mediaCleared && pendingLogo == null) {
        await _mediaRepo.applyBrandMedia(b.id, uploaded: null, clear: true);
      } else {
        final up = await uploadPendingBrandLogo(brandId: b.id, pending: pendingLogo);
        if (up != null) {
          await _mediaRepo.applyBrandMedia(b.id, uploaded: up);
          await _repo.updateBrand(b.id, name: name.text.trim(), logoMimeType: up.mimeType);
        }
      }
      onDone();
    }
    name.dispose();
    shortDesc.dispose();
    displayOrder.dispose();
  }

  static Future<void> toggleBrandActive(BuildContext context, ShopBrand b, VoidCallback onDone) async {
    await _repo.updateBrand(b.id, name: b.name, isActive: !b.isActive);
    onDone();
  }

  static Future<void> deleteBrand(BuildContext context, ShopBrand b, VoidCallback onDone) async {
    if (!await confirmDelete(context, b.name)) return;
    await _repo.deleteBrand(b.id);
    onDone();
  }

  static Future<void> deleteAttributeMaster(
    BuildContext context,
    ShopAttributeMaster a,
    VoidCallback onDone,
  ) async {
    if (!await confirmDelete(context, a.label)) return;
    await _repo.deleteAttributeMaster(a.id);
    onDone();
  }

  static Future<void> editAttributeGroup(
    BuildContext context,
    ShopAttributeGroup g,
    VoidCallback onDone,
  ) async {
    final name = TextEditingController(text: g.name);
    final desc = TextEditingController(text: g.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit attribute group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await _repo.updateAttributeGroup(g.id, name: name.text.trim(), description: desc.text.trim());
      onDone();
    }
    name.dispose();
    desc.dispose();
  }

  static Future<void> deleteAttributeGroup(
    BuildContext context,
    ShopAttributeGroup g,
    VoidCallback onDone,
  ) async {
    if (!await confirmDelete(context, g.name)) return;
    await _repo.deleteAttributeGroup(g.id);
    onDone();
  }

  static Future<void> toggleProductActive(BuildContext context, ShopProduct p, VoidCallback onDone) async {
    await _repo.setProductActive(p.id, !p.isActive);
    onDone();
  }

  static Future<void> deleteProduct(BuildContext context, ShopProduct p, VoidCallback onDone) async {
    if (!await confirmDelete(context, p.name)) return;
    await _repo.deleteProduct(p.id);
    onDone();
  }

  static String slugify(String input) => SupabaseRepositoryBase.slugify(input);
}

/// Edit / hide / delete icon row for shop admin list tiles.
class ShopAdminRowActions extends StatelessWidget {
  const ShopAdminRowActions({
    super.key,
    required this.isActive,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: 'Edit',
          onPressed: onEdit,
        ),
        IconButton(
          icon: Icon(isActive ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
          tooltip: isActive ? 'Visible on homepage — tap to hide' : 'Hidden from homepage — tap to show',
          onPressed: onToggleActive,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
          tooltip: 'Delete',
          onPressed: onDelete,
        ),
      ],
    );
  }
}
