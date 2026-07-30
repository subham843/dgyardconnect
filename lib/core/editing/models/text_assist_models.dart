enum TextAssistAction {
  fixSpelling('fix_spelling', 'Fix spelling'),
  improveGrammar('improve_grammar', 'Improve grammar'),
  professionalRewrite('professional_rewrite', 'Professional rewrite'),
  seoOptimize('seo_optimize', 'SEO optimize'),
  shorten('shorten', 'Shorten'),
  expand('expand', 'Expand'),
  generateProductDescription('generate_product_description', 'Generate product description'),
  generateProductShortDescription('generate_product_short_description', 'Generate short description'),
  generateCategoryDescription('generate_category_description', 'Generate description'),
  generateMetaDescription('generate_meta_description', 'Generate meta description'),
  suggestSeoTitle('suggest_seo_title', 'Suggest SEO title'),
  suggestMetaDescription('suggest_meta_description', 'Suggest meta description'),
  suggestSlug('suggest_slug', 'Suggest slug'),
  spellCheck('spell_check', 'Spell check'),
  capitalize('capitalize', 'Auto capitalize');

  const TextAssistAction(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum TextAssistLanguage { auto, en, hi }

class TextAssistContext {
  const TextAssistContext({
    this.productName,
    this.categoryName,
    this.brandName,
    this.subCategoryName,
    this.companyName,
    this.companySite,
  });

  final String? productName;
  final String? categoryName;
  final String? brandName;
  final String? subCategoryName;
  final String? companyName;
  final String? companySite;

  Map<String, dynamic> toJson() => {
        if (productName != null && productName!.isNotEmpty) 'productName': productName,
        if (categoryName != null && categoryName!.isNotEmpty) 'categoryName': categoryName,
        if (brandName != null && brandName!.isNotEmpty) 'brandName': brandName,
        if (subCategoryName != null && subCategoryName!.isNotEmpty) 'subCategoryName': subCategoryName,
        if (companyName != null && companyName!.isNotEmpty) 'companyName': companyName,
        if (companySite != null && companySite!.isNotEmpty) 'companySite': companySite,
      };
}

class TextAssistResponse {
  const TextAssistResponse({
    required this.suggestion,
    this.issues = const [],
    this.error,
    this.provider,
    this.fromKnowledge = false,
  });

  final String suggestion;
  final List<String> issues;
  final String? error;
  final String? provider;
  final bool fromKnowledge;

  String get providerLabel {
    if (fromKnowledge) return 'DG Yard learned';
    return switch (provider) {
      'groq' => 'Groq',
      'gemini' => 'Gemini',
      'openai' => 'OpenAI',
      'local-rules' => 'Built-in rules',
      _ => provider ?? 'AI',
    };
  }

  factory TextAssistResponse.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TextAssistResponse(suggestion: '', error: 'No response');
    }
    if (json['error'] != null) {
      return TextAssistResponse(suggestion: '', error: json['error'] as String);
    }
    final issues = (json['suggestions'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    return TextAssistResponse(
      suggestion: json['suggestion'] as String? ?? '',
      issues: issues,
      provider: json['provider'] as String?,
      fromKnowledge: json['fromKnowledge'] == true,
    );
  }
}
