import 'dart:async';

import 'package:flutter/material.dart';

import 'local_text_rules.dart';
import 'models/text_assist_models.dart';
import 'platform_text_assist_service.dart';

/// Text field with spell/grammar hints and optional AI assist (never auto-applies).
class DgAssistTextField extends StatefulWidget {
  const DgAssistTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.readOnly = false,
    this.enabled = true,
    this.assistProfile = TextAssistProfile.general,
    this.language = TextAssistLanguage.auto,
    this.contextHints,
    this.showAssistButton = true,
    this.debounceSpellMs = 800,
    this.showLanguagePicker = false,
    this.enableRemoteSpellCheck = true,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final bool enabled;
  final TextAssistProfile assistProfile;
  final TextAssistLanguage language;
  final TextAssistContext? contextHints;
  final bool showAssistButton;
  final int debounceSpellMs;
  final bool showLanguagePicker;

  /// When false, only fast local checks (no AI spell API on every keystroke).
  final bool enableRemoteSpellCheck;

  @override
  State<DgAssistTextField> createState() => _DgAssistTextFieldState();
}

/// Controls which AI actions appear in the popup menu for this field.
enum TextAssistProfile {
  /// Product / category / brand / sub-category name fields.
  entityName,
  /// Product short description — polish only, no full generate.
  productShortDesc,
  /// Product full description — includes generate product copy.
  productFullDesc,
  /// Category description field.
  categoryDesc,
  /// Sub-category description field.
  subCategoryDesc,
  /// Technical / installation notes.
  technicalNotes,
  /// ERP purchase / quotation notes.
  erpNotes,
  /// SEO title field.
  seoTitle,
  /// Meta description field.
  seoMeta,
  /// URL slug field.
  seoSlug,
  /// Generic text — grammar tools only.
  general,
}

class _DgAssistTextFieldState extends State<DgAssistTextField> {
  final _assist = PlatformTextAssistService();
  Timer? _debounce;
  List<String> _inlineIssues = [];
  var _checking = false;
  TextAssistLanguage _language = TextAssistLanguage.auto;

  static const _polish = <TextAssistAction>[
    TextAssistAction.fixSpelling,
    TextAssistAction.improveGrammar,
    TextAssistAction.professionalRewrite,
    TextAssistAction.shorten,
    TextAssistAction.expand,
  ];

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (widget.debounceSpellMs <= 0) return;
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: widget.debounceSpellMs), _runSpellHints);
  }

  Future<void> _runSpellHints() async {
    final text = widget.controller.text;
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _inlineIssues = []);
      return;
    }
    final local = LocalTextRules.quickIssues(
      text,
      hindiExpected: _language == TextAssistLanguage.hi || LocalTextRules.looksHindi(text),
    );
    if (!mounted) return;
    if (!widget.enableRemoteSpellCheck) {
      setState(() => _inlineIssues = local);
      return;
    }
    setState(() {
      _inlineIssues = local;
      _checking = true;
    });
    final remote = await _assist.run(
      action: TextAssistAction.spellCheck,
      text: text,
      language: _language,
      context: widget.contextHints,
    );
    if (!mounted) return;
    setState(() {
      _checking = false;
      _inlineIssues = [...local, ...remote.issues];
    });
  }

  List<TextAssistAction> get _menuActions {
    switch (widget.assistProfile) {
      case TextAssistProfile.entityName:
        return [TextAssistAction.capitalize, TextAssistAction.fixSpelling, TextAssistAction.improveGrammar];
      case TextAssistProfile.productShortDesc:
        return [..._polish, TextAssistAction.generateProductShortDescription];
      case TextAssistProfile.productFullDesc:
        return [..._polish, TextAssistAction.generateProductDescription];
      case TextAssistProfile.categoryDesc:
        return [..._polish, TextAssistAction.generateCategoryDescription];
      case TextAssistProfile.subCategoryDesc:
        return [..._polish, TextAssistAction.generateCategoryDescription];
      case TextAssistProfile.technicalNotes:
      case TextAssistProfile.erpNotes:
        return [
          TextAssistAction.fixSpelling,
          TextAssistAction.improveGrammar,
          TextAssistAction.professionalRewrite,
          TextAssistAction.shorten,
        ];
      case TextAssistProfile.seoTitle:
        return [
          TextAssistAction.suggestSeoTitle,
          TextAssistAction.seoOptimize,
          TextAssistAction.fixSpelling,
          TextAssistAction.improveGrammar,
          TextAssistAction.shorten,
          TextAssistAction.professionalRewrite,
        ];
      case TextAssistProfile.seoMeta:
        return [
          TextAssistAction.suggestMetaDescription,
          TextAssistAction.generateMetaDescription,
          TextAssistAction.seoOptimize,
          TextAssistAction.fixSpelling,
          TextAssistAction.improveGrammar,
          TextAssistAction.shorten,
        ];
      case TextAssistProfile.seoSlug:
        return [
          TextAssistAction.suggestSlug,
          TextAssistAction.fixSpelling,
        ];
      case TextAssistProfile.general:
        return _polish;
    }
  }

  Future<void> _runAction(TextAssistAction action) async {
    final text = widget.controller.text;
    if (action == TextAssistAction.suggestSlug) {
      final h = widget.contextHints;
      final hasName = text.trim().isNotEmpty ||
          (h?.productName?.isNotEmpty ?? false) ||
          (h?.categoryName?.isNotEmpty ?? false) ||
          (h?.subCategoryName?.isNotEmpty ?? false) ||
          (h?.brandName?.isNotEmpty ?? false);
      if (!hasName) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name for slug suggestion')));
        return;
      }
    }
    final res = await _assist.run(
      action: action,
      text: text,
      language: _language,
      context: widget.contextHints,
    );
    if (!mounted) return;
    if (res.error != null && res.suggestion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error!)));
      return;
    }
    if (res.suggestion.isEmpty && res.issues.isEmpty) return;
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action.label),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Source: ${res.providerLabel}', style: Theme.of(ctx).textTheme.labelSmall),
              const SizedBox(height: 8),
              if (res.issues.isNotEmpty) ...[
                const Text('Suggestions:', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final i in res.issues) Text('• $i'),
                const SizedBox(height: 12),
              ],
              if (res.suggestion.isNotEmpty) ...[
                const Text('Proposed text:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SelectableText(res.suggestion),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          if (res.suggestion.isNotEmpty)
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (apply == true && mounted) {
      widget.controller.text = res.suggestion;
      widget.controller.selection = TextSelection.collapsed(offset: res.suggestion.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showLanguagePicker) ...[
          SegmentedButton<TextAssistLanguage>(
            segments: const [
              ButtonSegment(value: TextAssistLanguage.auto, label: Text('Auto')),
              ButtonSegment(value: TextAssistLanguage.en, label: Text('English')),
              ButtonSegment(value: TextAssistLanguage.hi, label: Text('हिंदी')),
            ],
            selected: {_language},
            onSelectionChanged: (s) => setState(() => _language = s.first),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: widget.controller,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            suffixIcon: widget.showAssistButton && widget.enabled && !widget.readOnly
                ? PopupMenuButton<TextAssistAction>(
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    tooltip: 'AI assist',
                    onSelected: _runAction,
                    itemBuilder: (_) => [
                      for (final a in _menuActions)
                        PopupMenuItem(value: a, child: Text(a.label)),
                    ],
                  )
                : widget.decoration?.suffixIcon,
          ),
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
        ),
        if (_inlineIssues.isNotEmpty || _checking)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_checking)
                  Chip(
                    label: Text('Checking…', style: Theme.of(context).textTheme.bodySmall),
                    visualDensity: VisualDensity.compact,
                  ),
                for (final issue in _inlineIssues.take(4))
                  ActionChip(
                    label: Text(issue, style: Theme.of(context).textTheme.bodySmall),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _runAction(TextAssistAction.fixSpelling),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
