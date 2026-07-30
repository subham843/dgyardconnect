// Premium product detail — Apple Store–inspired glass morphism layout.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/bootstrap/firebase_auth_safe.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/seo/public_seo_registry.dart';
import '../../../../core/seo/web_seo_binder.dart';
import '../../../../core/seo/web_seo_meta.dart';
import '../../../../shared/services/auth_post_login.dart';
import '../../../../shared/widgets/brand_logo_canvas.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/v2_text.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../widgets/public_floating_menu.dart';
import '../../../customer/account/customer_account_shell.dart';
import '../../v2/widgets/v2_page_container.dart';
import '../../data/models/public_brand.dart';
import '../../data/models/public_store_models.dart';
import '../../data/repositories/public_store_repository.dart';
import '../../state/public_cart.dart';
import 'widgets/product_detail_glass.dart';
import 'widgets/store_atoms.dart';
import 'widgets/store_product_card.dart';
import '../../data/models/public_image_placements.dart';
import 'widgets/store_product_image.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productSlug});

  final String productSlug;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _repository = PublicStoreRepository();
  final _scroll = ScrollController();

  ProductDetailData? _data;
  bool _loading = true;
  int _selectedImage = 0;

  static const _pageBg = Color(0xFFF5F5F7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productSlug != widget.productSlug) {
      setState(() {
        _loading = true;
        _selectedImage = 0;
      });
      _load();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _repository.loadProductDetail(widget.productSlug);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addToCart(PublicProduct p) {
    PublicCart.instance.addProduct(p);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.name} added to bag'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: V2Colors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'View bag',
          textColor: V2Colors.ember,
          onPressed: () => context.go(RouteNames.publicCart),
        ),
      ),
    );
  }

  void _buyNow(PublicProduct p) {
    PublicCart.instance.addProduct(p);
    if (FirebaseAuthSafe.isSignedIn) {
      context.go(RouteNames.publicCheckout);
      return;
    }
    context.go(AuthPostLogin.loginUrlWithReturn(RouteNames.publicCheckout));
  }

  String _priceLabel(PublicProduct p) {
    if (p.price != null) return formatINR(p.price);
    return 'Price on request';
  }

  WebSeoMeta _seoMeta() {
    final data = _data;
    final path = '/product/${widget.productSlug}';
    if (!_loading && data == null) {
      return PublicSeoRegistry.softNotFound(
        title: 'Product not found',
        path: path,
      );
    }
    if (data != null) {
      final p = data.product;
      return PublicSeoRegistry.product(
        slug: widget.productSlug,
        name: p.name,
        description: p.shortDescription ?? p.description,
        image: p.imageUrl,
        sku: p.sku,
        price: p.price,
        brand: p.brandName,
      );
    }
    return PublicSeoRegistry.store();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final data = _data;

    return WebSeoScope(
      meta: _seoMeta(),
      child: Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          const Positioned.fill(child: ProductDetailAmbientBg()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (data == null)
            _notFound()
          else
            SingleChildScrollView(
              controller: _scroll,
              child: _buildContent(context, data),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PublicFloatingMenu(
              active: CustomerAccountTab.shop,
              above: data != null && v.isMobile
                  ? ProductStickyBuyBar(
                      productName: data.product.name,
                      priceLabel: _priceLabel(data.product),
                      onBuyNow: () => _buyNow(data.product),
                      onAddToCart: () => _addToCart(data.product),
                    )
                  : null,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _notFound() {
    return Center(
      child: ProductGlassPanel(
        padding: const EdgeInsets.all(V2.s12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 72, color: V2Colors.fgFaint),
            const SizedBox(height: V2.s6),
            Text('Product not found', style: V2Text.h3(context)),
            const SizedBox(height: V2.s6),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: V2Colors.ink),
              onPressed: () => context.go(RouteNames.publicStore),
              child: const Text('Back to store'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProductDetailData data) {
    final v = V2Responsive(context);
    final bottomPad = v.isMobile ? 100.0 : 0.0;

    return Column(
      children: [
        SizedBox(height: v.r(xs: 16, lg: 24)),
        V2PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _breadcrumb(data).animate().fadeIn(duration: 320.ms),
              SizedBox(height: v.r(xs: V2.s6, lg: V2.s10)),
              v.isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _gallery(data.product)
                              .animate()
                              .fadeIn(duration: 450.ms)
                              .slideY(begin: 0.04, end: 0),
                        ),
                        const SizedBox(width: V2.s12),
                        Expanded(
                          flex: 5,
                          child: _info(context, data)
                              .animate()
                              .fadeIn(delay: 80.ms, duration: 450.ms)
                              .slideY(begin: 0.04, end: 0),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _gallery(data.product)
                            .animate()
                            .fadeIn(duration: 450.ms)
                            .slideY(begin: 0.04, end: 0),
                        const SizedBox(height: V2.s8),
                        _info(context, data)
                            .animate()
                            .fadeIn(delay: 80.ms, duration: 450.ms)
                            .slideY(begin: 0.04, end: 0),
                      ],
                    ),
              SizedBox(height: v.r(xs: V2.s12, lg: V2.s20)),
              if (data.product.description != null &&
                  data.product.description!.trim().isNotEmpty)
                _descriptionBlock(data.product),
              if ((data.product.technicalNotes ?? '').trim().isNotEmpty)
                _notesBlock('Technical details', data.product.technicalNotes!),
              if ((data.product.installationNotes ?? '').trim().isNotEmpty)
                _notesBlock('Installation', data.product.installationNotes!),
              if (data.specs.isNotEmpty) _specsBlock(data.specs),
              if (data.documents.isNotEmpty) _documentsBlock(data.documents),
              if (data.brand != null) _brandBlock(context, data.brand!),
              if (data.related.isNotEmpty) _relatedBlock(data.related),
            ],
          ),
        ),
        SizedBox(height: bottomPad + V2.s16),
        const V2Footer(),
        SizedBox(height: PublicFloatingMenu.contentBottomInset(context, hasAbove: true)),
      ],
    );
  }

  Widget _breadcrumb(ProductDetailData data) {
    Widget crumb(String label, VoidCallback? onTap, {bool last = false}) {
      final style = V2Text.small().copyWith(
        color: last ? V2Colors.ink : V2Colors.fgSubtle,
        fontWeight: last ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: 0.1,
      );
      if (onTap == null) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.55,
          ),
          child: Text(
            label,
            style: style,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: Text(label, style: style)),
      );
    }

    const sep = Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.chevron_right_rounded, size: 14, color: V2Colors.fgFaint),
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        crumb('Store', () => context.go(RouteNames.publicStore)),
        if (data.categoryName != null && data.categorySlug != null) ...[
          sep,
          crumb(data.categoryName!,
              () => context.go(RouteNames.publicStoreCategory(data.categorySlug!))),
        ],
        sep,
        crumb(data.product.name, null, last: true),
      ],
    );
  }

  // --- Gallery ---------------------------------------------------------------

  Widget _gallery(PublicProduct product) {
    final v = V2Responsive(context);
    final images = product.galleryUrls;
    final idx = _selectedImage.clamp(0, images.isEmpty ? 0 : images.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductGlassPanel(
          highlight: true,
          padding: EdgeInsets.all(v.r(xs: 20, lg: 32)),
          radius: v.r(xs: 28, lg: 32),
          child: _HeroImage(product: product, imageIndex: idx),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: V2.s4),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _ThumbnailTile(
                product: product,
                index: i,
                imageUrl: images[i],
                selected: i == _selectedImage,
                onTap: () => setState(() => _selectedImage = i),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- Info ------------------------------------------------------------------

  Widget _info(BuildContext context, ProductDetailData data) {
    final v = V2Responsive(context);
    final p = data.product;

    return ProductGlassPanel(
      highlight: true,
      padding: EdgeInsets.all(v.r(xs: V2.s6, lg: V2.s10)),
      radius: v.r(xs: 24, lg: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((p.brandName ?? '').isNotEmpty)
            Text(
              p.brandName!.toUpperCase(),
              style: V2Text.micro().copyWith(
                color: V2Colors.fgSubtle,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          if ((p.brandName ?? '').isNotEmpty) const SizedBox(height: V2.s3),
          Text(
            p.name,
            style: TextStyle(
              fontSize: v.r(xs: 28, md: 34, lg: 40),
              fontWeight: FontWeight.w700,
              height: 1.08,
              letterSpacing: -0.8,
              color: V2Colors.ink,
            ),
          ),
          const SizedBox(height: V2.s4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const ProductMetaChip(
                label: 'In stock',
                icon: Icons.check_circle_rounded,
                color: V2Colors.aurora,
              ),
              if (p.sku != null && p.sku!.isNotEmpty)
                ProductMetaChip(label: 'SKU ${p.sku}', icon: Icons.tag_rounded),
              if (p.hasDiscount)
                ProductMetaChip(
                  label: '${p.discountPercent}% off',
                  icon: Icons.local_offer_outlined,
                  color: const Color(0xFFEF4444),
                ),
            ],
          ),
          const SizedBox(height: V2.s6),
          if (p.price != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatINR(p.price),
                  style: TextStyle(
                    fontSize: v.r(xs: 32, lg: 36),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: V2Colors.ink,
                  ),
                ),
                if (p.hasDiscount) ...[
                  const SizedBox(width: V2.s4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      formatINR(p.mrp),
                      style: V2Text.bodyEmph().copyWith(
                        color: V2Colors.fgSubtle,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            Text(
              'Price on request',
              style: V2Text.h3(context).copyWith(color: V2Colors.plasma),
            ),
          if ((p.shortDescription ?? '').isNotEmpty) ...[
            const SizedBox(height: V2.s6),
            Text(
              p.shortDescription!,
              style: V2Text.bodyLg(context).copyWith(
                color: V2Colors.fgMuted,
                height: 1.55,
              ),
            ),
          ],
          if (!v.isMobile) ...[
            const SizedBox(height: V2.s8),
            ProductActionButtons(
              onBuyNow: () => _buyNow(p),
              onAddToCart: () => _addToCart(p),
            ),
          ],
          if (data.documents.isNotEmpty) ...[
            const SizedBox(height: V2.s4),
            _datasheetButton(data.documents),
          ],
          const SizedBox(height: V2.s6),
          _assuranceRow(p),
        ],
      ),
    );
  }

  Widget _datasheetButton(List<PublicDocument> documents) {
    final doc = documents.firstWhere(
      (d) => d.mediaType == 'datasheet',
      orElse: () => documents.first,
    );
    return _GlassSecondaryButton(
      onPressed: () => _openDocument(doc),
      label: 'Download ${doc.typeLabel}',
      icon: Icons.picture_as_pdf_outlined,
    );
  }

  Widget _assuranceRow(PublicProduct p) {
    final items = <(IconData, String)>[
      (Icons.verified_user_outlined, 'Genuine product'),
      if ((p.warranty ?? '').isNotEmpty)
        (Icons.workspace_premium_outlined, 'Warranty: ${p.warranty}')
      else
        (Icons.workspace_premium_outlined, 'Manufacturer warranty'),
      (Icons.local_shipping_outlined, 'Pan-India delivery'),
    ];

    return Container(
      padding: const EdgeInsets.all(V2.s5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 20,
                color: V2Colors.border.withValues(alpha: 0.6),
              ),
            Row(
              children: [
                Icon(items[i].$1, size: 18, color: V2Colors.plasma),
                const SizedBox(width: V2.s4),
                Expanded(child: Text(items[i].$2, style: V2Text.small())),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- Content blocks --------------------------------------------------------

  Widget _glassSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: V2.s10),
      child: ProductGlassPanel(
        padding: const EdgeInsets.all(V2.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: V2Text.h3(context).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: V2.s6),
            child,
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.03, end: 0);
  }

  Widget _descriptionBlock(PublicProduct p) {
    return _glassSection(
      title: 'Overview',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Text(
          p.description!,
          style: V2Text.bodyLg(context).copyWith(height: 1.65),
        ),
      ),
    );
  }

  Widget _notesBlock(String title, String text) {
    return _glassSection(
      title: title,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Text(text, style: V2Text.bodyLg(context).copyWith(height: 1.65)),
      ),
    );
  }

  Future<void> _openDocument(PublicDocument doc) async {
    final uri = Uri.tryParse(doc.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _documentsBlock(List<PublicDocument> documents) {
    return _glassSection(
      title: 'Documents & downloads',
      child: Column(
        children: [
          for (final doc in documents)
            Padding(
              padding: const EdgeInsets.only(bottom: V2.s3),
              child: _DocumentRow(doc: doc, onOpen: () => _openDocument(doc)),
            ),
        ],
      ),
    );
  }

  Widget _specsBlock(List<ProductSpec> specs) {
    final v = V2Responsive(context);
    return _glassSection(
      title: 'Specifications',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (var i = 0; i < specs.length; i++)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: V2.s5,
                  vertical: V2.s4,
                ),
                decoration: BoxDecoration(
                  color: i.isEven
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.15),
                  border: Border(
                    bottom: BorderSide(
                      color: V2Colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: v.isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            specs[i].label,
                            style: V2Text.smallStrong()
                                .copyWith(color: V2Colors.fgMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(specs[i].value, style: V2Text.body()),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              specs[i].label,
                              style: V2Text.smallStrong()
                                  .copyWith(color: V2Colors.fgMuted),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Text(
                              specs[i].value,
                              style: V2Text.body().copyWith(color: V2Colors.ink),
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _brandBlock(BuildContext context, PublicBrand brand) {
    final v = V2Responsive(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: V2.s10),
      child: ProductGlassPanel(
        padding: const EdgeInsets.all(V2.s8),
        child: v.isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brandLogo(brand),
                  const SizedBox(height: V2.s6),
                  _brandText(context, brand),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _brandLogo(brand),
                  const SizedBox(width: V2.s8),
                  Expanded(child: _brandText(context, brand)),
                ],
              ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _brandLogo(PublicBrand brand) {
    return Container(
      width: 180,
      height: 96,
      padding: const EdgeInsets.all(V2.s4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(V2.rXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BrandLogoCanvas(
        width: 150,
        height: 64,
        logoUrl: brand.logoUrl,
        mimeType: brand.logoMimeType,
        layout: brand.logoLayout,
        fallbackLabel: brand.name,
      ),
    );
  }

  Widget _brandText(BuildContext context, PublicBrand brand) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About ${brand.name}', style: V2Text.h3(context)),
        if ((brand.shortDescription ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: V2.s2),
          Text(
            brand.shortDescription!,
            style: V2Text.body(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: V2.s4),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('${RouteNames.publicStore}?brand=${brand.slug}'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Shop all ${brand.name}',
                  style: V2Text.smallStrong().copyWith(
                    color: V2Colors.plasma,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: V2Colors.plasma),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _relatedBlock(List<PublicProduct> related) {
    return Padding(
      padding: const EdgeInsets.only(bottom: V2.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: V2.s6),
            child: Text(
              'You may also like',
              style: V2Text.h3(context).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(
            height: 420,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: related.length,
              separatorBuilder: (_, _) => const SizedBox(width: V2.s5),
              itemBuilder: (context, i) => SizedBox(
                width: 260,
                child: StoreProductCard(
                  product: related[i],
                  onTap: () => context.go('/product/${related[i].slug}'),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _GlassSecondaryButton extends StatelessWidget {
  const _GlassSecondaryButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: V2Colors.ink,
          backgroundColor: Colors.white.withValues(alpha: 0.5),
          side: BorderSide(color: V2Colors.border.withValues(alpha: 0.8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

class _DocumentRow extends StatefulWidget {
  const _DocumentRow({required this.doc, required this.onOpen});
  final PublicDocument doc;
  final VoidCallback onOpen;

  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final meta = [doc.typeLabel, if (doc.readableSize != null) doc.readableSize!]
        .join(' · ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(V2.s4),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover ? V2Colors.plasma.withValues(alpha: 0.4) : V2Colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  doc.isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.insert_drive_file_outlined,
                  color: const Color(0xFFEF4444),
                  size: 22,
                ),
              ),
              const SizedBox(width: V2.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2Text.bodyEmph().copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(meta, style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onOpen,
                icon: const Icon(Icons.download_rounded),
                color: V2Colors.plasma,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatefulWidget {
  const _HeroImage({required this.product, required this.imageIndex});

  final PublicProduct product;
  final int imageIndex;

  @override
  State<_HeroImage> createState() => _HeroImageState();
}

class _HeroImageState extends State<_HeroImage> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final images = widget.product.galleryUrls;
    final isMain = widget.imageIndex == 0;
    final v = V2Responsive(context);

    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(v.r(xs: 20, lg: 24)),
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 1.1,
              colors: [
                Colors.white.withValues(alpha: 0.95),
                _ProductDetailPageState._pageBg.withValues(alpha: 0.4),
              ],
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: V2Colors.plasma.withValues(alpha: 0.12),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedScale(
            scale: _hover ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            child: isMain
                ? StoreProductImage(
                    product: widget.product,
                    slotId: 'product_detail',
                    fit: BoxFit.contain,
                  )
                : StoreImage(
                    url: images.length > widget.imageIndex
                        ? images[widget.imageIndex]
                        : widget.product.imageUrl,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailTile extends StatefulWidget {
  const _ThumbnailTile({
    required this.product,
    required this.index,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  final PublicProduct product;
  final int index;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<_ThumbnailTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.selected
                  ? V2Colors.ink
                  : (_hover ? V2Colors.border : Colors.white.withValues(alpha: 0.6)),
              width: widget.selected ? 2 : 1.2,
            ),
            color: Colors.white.withValues(alpha: widget.selected ? 0.9 : 0.55),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.index == 0
              ? StoreProductImage(
                  product: widget.product,
                  slotId: PublicImagePlacements.defaultSlotId,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                )
              : StoreImage(url: widget.imageUrl, fit: BoxFit.cover),
        ),
      ),
    );
  }
}