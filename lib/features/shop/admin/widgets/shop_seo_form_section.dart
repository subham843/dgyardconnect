import 'package:flutter/material.dart';

import '../../../../core/editing/dg_assist_text_field.dart';
import '../../../../core/editing/models/text_assist_models.dart';
import '../validation/shop_erp_validation.dart';

/// Minimal admin SEO with assist (title, description, slug).
class ShopSeoFormSection extends StatelessWidget {
  const ShopSeoFormSection({
    super.key,
    required this.seoTitleController,
    required this.metaDescriptionController,
    required this.slugController,
    this.slugAutoHint,
    this.canonicalPreview,
    this.contextHints,
    this.enableRemoteSpellCheck = true,
    this.debounceSpellMs = 800,
  });

  final TextEditingController seoTitleController;
  final TextEditingController metaDescriptionController;
  final TextEditingController slugController;
  final String? slugAutoHint;
  final String? canonicalPreview;
  final TextAssistContext? contextHints;
  final bool enableRemoteSpellCheck;
  final int debounceSpellMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Canonical URL, Open Graph title/description, and OG image are generated automatically when you save.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 12),
        DgAssistTextField(
          controller: seoTitleController,
          assistProfile: TextAssistProfile.seoTitle,
          enableRemoteSpellCheck: enableRemoteSpellCheck,
          debounceSpellMs: debounceSpellMs,
          contextHints: contextHints,
          decoration: const InputDecoration(
            labelText: 'SEO title',
            border: OutlineInputBorder(),
            helperText: 'Search & social headline',
          ),
        ),
        const SizedBox(height: 12),
        DgAssistTextField(
          controller: metaDescriptionController,
          maxLines: 3,
          assistProfile: TextAssistProfile.seoMeta,
          enableRemoteSpellCheck: enableRemoteSpellCheck,
          debounceSpellMs: debounceSpellMs,
          contextHints: contextHints,
          decoration: const InputDecoration(
            labelText: 'Meta description',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DgAssistTextField(
          controller: slugController,
          assistProfile: TextAssistProfile.seoSlug,
          enableRemoteSpellCheck: enableRemoteSpellCheck,
          debounceSpellMs: debounceSpellMs,
          textCapitalization: TextCapitalization.none,
          contextHints: contextHints,
          decoration: InputDecoration(
            labelText: 'Slug',
            border: const OutlineInputBorder(),
            helperText: slugAutoHint ?? 'Auto-generated from name if left empty',
          ),
        ),
        if (canonicalPreview != null && canonicalPreview!.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            'Preview: $canonicalPreview',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }

  static String? validateSlug(String? slug) => ShopErpValidation.urlSlug(slug?.trim().isEmpty == true ? null : slug);
}
