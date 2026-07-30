import 'dart:async';
import 'dart:ui';

import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bootstrap/firebase_auth_safe.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/seo/public_seo_registry.dart';
import '../../../../core/seo/web_seo_binder.dart';
import '../../../../core/seo/web_seo_meta.dart';
import '../../../../shared/services/auth_post_login.dart';
import '../../../calculator/data/calculator_repository.dart';
import '../../../calculator/data/quotation_repository.dart';
import '../../../calculator/domain/calculator_engine.dart';
import '../../../calculator/domain/calculator_models.dart';
import '../../../calculator/presentation/quotation_save_popup.dart';
import '../../../calculator/services/quotation_order_helper.dart';
import '../../../customer/account/customer_account_shell.dart';
import '../../data/repositories/public_calculator_repository.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_font_styles.dart';
import '../../v2/v2_text.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../v2/widgets/v2_page_container.dart';
import '../../widgets/public_floating_menu.dart';
import '../shop/widgets/store_atoms.dart';
import 'calculator_guest_draft.dart';
import 'calculator_price_privacy.dart';
import 'calculator_suggested_quick_view.dart';

enum _CalcWizardStep { specs, products, rates }

/// Apple-inspired price calculator — specs → products → rates.
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, this.initialFamilySlug});

  final String? initialFamilySlug;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _scroll = ScrollController();
  final _repo = PublicCalculatorRepository();
  final _authRepo = CalculatorRepository();
  final _quotationRepo = QuotationRepository();
  late final CalculatorEngine _engine = CalculatorEngine(
    productLookup: (slug, {String? nameContains, Map<String, String>? attributes}) =>
        _repo.findProductsBySubCategorySlug(
          slug,
          nameContains: nameContains,
          attributes: attributes,
        ),
    attributeProductLookup: (attrs) => _repo.findProductsMatchingAttributes(attrs),
  );

  List<CalculatorFamily> _families = [];
  CalculatorFamily? _selectedFamily;
  CalculatorTemplate? _template;
  List<CalculatorQuestion> _questions = [];
  List<CalculatorRule> _rules = [];
  List<CalculatorQuestionGroup> _groups = [];
  final _answers = <String, dynamic>{};
  final _textControllers = <String, TextEditingController>{};
  /// User-picked product overrides for attribute-matched lines (selectionKey → productId).
  final _productOverrides = <String, String>{};

  CalculatorResult? _result;
  bool _loadingFamilies = true;
  bool _loadingTemplate = false;
  bool _evaluating = false;
  bool _saving = false;
  bool _ordering = false;
  Timer? _evaluateDebounce;
  int _evaluateGen = 0;
  final _orderHelper = QuotationOrderHelper();
  StreamSubscription<dynamic>? _authSub;
  var _signedIn = FirebaseAuthSafe.isSignedIn;
  _CalcWizardStep _step = _CalcWizardStep.specs;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
    _authSub = FirebaseAuthSafe.authStateChanges().listen((user) {
      if (!mounted) return;
      final next = user != null;
      if (next == _signedIn) return;
      setState(() => _signedIn = next);
      // Prices unlock after login — re-run estimate if answers already restored.
      if (next && _readyForEstimate) _scheduleEvaluate();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _evaluateDebounce?.cancel();
    _scroll.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFamilies() async {
    setState(() => _loadingFamilies = true);
    try {
      final families = await _repo.listFamilies();
      if (!mounted) return;
      CalculatorFamily? selected;
      if (widget.initialFamilySlug != null && widget.initialFamilySlug!.isNotEmpty) {
        final match = families.where((f) => f.slug == widget.initialFamilySlug);
        selected = match.isNotEmpty ? match.first : (families.isNotEmpty ? families.first : null);
      } else {
        selected = families.isNotEmpty ? families.first : null;
      }
      setState(() {
        _families = families;
        _selectedFamily = selected;
        _loadingFamilies = false;
      });
      if (selected != null) await _selectFamily(selected, updateUrl: false);
    } catch (_) {
      if (mounted) setState(() => _loadingFamilies = false);
    }
  }

  Future<void> _selectFamily(CalculatorFamily family, {bool updateUrl = true}) async {
    if (_selectedFamily?.id == family.id && _template != null && _questions.isNotEmpty) {
      return;
    }
    setState(() {
      _selectedFamily = family;
      _loadingTemplate = true;
      _result = null;
      _template = null;
      _questions = [];
      _rules = [];
      _groups = [];
      _answers.clear();
      _productOverrides.clear();
      _step = _CalcWizardStep.specs;
    });
    if (updateUrl && family.slug.isNotEmpty) {
      context.go('/calculator/${family.slug}');
    }
    try {
      final templates = await _repo.listPublishedTemplates(family.id);
      if (!mounted) return;
      final template = templates.isNotEmpty ? templates.first : null;
      final groups = await _repo.listQuestionGroups(family.id);
      final rawQuestions = await _repo.listQuestionsForFamily(
        familyId: family.id,
        templateId: template?.id,
      );
      final rules = template != null
          ? await _repo.listRules(template.id)
          : <CalculatorRule>[];
      if (!mounted) return;
      final questions = CalculatorRepository.enrichQuestionsWithGroups(
        CalculatorQuestion.attachOptionScopeVisibility(rawQuestions, rules),
        groups,
      );
      for (final c in _textControllers.values) {
        c.dispose();
      }
      _textControllers.clear();
      for (final q in questions) {
        // No defaults — wait for the user to choose before suggestions run.
        // Numbers stay unset (not 0) so rules like "cameras <= 4" do not fire early.
        if (q.uiType == 'number' ||
            q.uiType == 'slider' ||
            q.uiType == 'integer') {
          _textControllers[q.questionKey] = TextEditingController(text: '');
        } else {
          _answers[q.questionKey] = '';
          if (q.uiType == 'text') {
            _textControllers[q.questionKey] = TextEditingController(text: '');
          }
        }
      }
      setState(() {
        _template = template;
        _questions = questions;
        _rules = rules;
        _groups = [...groups]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _loadingTemplate = false;
        _result = null;
      });
      // After "See price" → login, restore the guest's qty / product picks.
      final restored = await _restoreGuestDraftIfAny(family.slug);
      if (restored && mounted) _scheduleEvaluate();
    } catch (_) {
      if (mounted) setState(() => _loadingTemplate = false);
    }
  }

  /// Applies a pending guest draft for [familySlug]. Returns true if estimate-ready.
  Future<bool> _restoreGuestDraftIfAny(String familySlug) async {
    final draft = await CalculatorDraftStore.load();
    if (draft == null || draft.familySlug != familySlug) return false;
    final knownKeys = _questions.map((q) => q.questionKey).toSet();
    for (final entry in draft.answers.entries) {
      if (!knownKeys.contains(entry.key)) continue;
      _answers[entry.key] = entry.value;
      final controller = _textControllers[entry.key];
      if (controller != null) {
        final text = entry.value?.toString() ?? '';
        if (controller.text != text) controller.text = text;
      }
    }
    _productOverrides
      ..clear()
      ..addAll(draft.productOverrides);
    await CalculatorDraftStore.clear();
    if (mounted) setState(() {});
    return _readyForEstimate;
  }

  void _scheduleEvaluate() {
    _evaluateDebounce?.cancel();
    _evaluateDebounce = Timer(const Duration(milliseconds: 450), _evaluate);
  }

  bool _isAnswered(CalculatorQuestion q) {
    final v = _answers[q.questionKey];
    if (q.uiType == 'number' || q.uiType == 'slider' || q.uiType == 'integer') {
      return _toNum(v) > 0;
    }
    return v != null && v.toString().trim().isNotEmpty;
  }

  bool _isRootFamilyQuestion(CalculatorQuestion q) =>
      q.showWhenKey == null || q.showWhenKey!.isEmpty;

  bool get _hasPathFollowUps =>
      _questions.any((q) => !_isRootFamilyQuestion(q));

  /// Root family option picks only unlock follow-ups — never estimate alone.
  bool get _readyForEstimate {
    for (final q in _questions) {
      if (!q.isVisibleGiven(_answers)) continue;
      if (_isRootFamilyQuestion(q)) {
        final selectLike = q.uiType == 'select' ||
            q.uiType == 'chips' ||
            q.uiType == 'radio' ||
            (q.options?.isNotEmpty ?? false);
        if (selectLike) continue;
      }
      if (_isAnswered(q)) return true;
    }
    return false;
  }

  bool get _canGoToProducts => _readyForEstimate && !_loadingTemplate;

  int get _pickableProductCount {
    final lines = _result?.suggestedLines ?? const <CalculatorSuggestedLine>[];
    return lines.where(_isPickableSuggestion).length;
  }

  Future<void> _goWizardNext() async {
    if (_step == _CalcWizardStep.specs) {
      if (!_canGoToProducts) return;
      await _evaluate();
      if (!mounted) return;
      setState(() => _step = _CalcWizardStep.products);
      _scrollToTop();
      return;
    }
    if (_step == _CalcWizardStep.products) {
      setState(() => _step = _CalcWizardStep.rates);
      _scrollToTop();
    }
  }

  void _goWizardBack() {
    if (_step == _CalcWizardStep.products) {
      setState(() => _step = _CalcWizardStep.specs);
      _scrollToTop();
      return;
    }
    if (_step == _CalcWizardStep.rates) {
      setState(() => _step = _CalcWizardStep.products);
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  double _toNum(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> _evaluate() async {
    if (_questions.isEmpty) return;
    if (!_readyForEstimate) {
      if (mounted) {
        setState(() {
          _result = null;
          _evaluating = false;
        });
      }
      return;
    }
    final gen = ++_evaluateGen;
    setState(() => _evaluating = true);
    try {
      var result = await _engine.evaluate(
        questions: _questions,
        rules: _rules,
        answers: Map<String, dynamic>.from(_answers),
      );
      result = _applyProductOverrides(result);
      if (!mounted || gen != _evaluateGen) return;
      setState(() {
        _result = result;
        _evaluating = false;
      });
    } catch (_) {
      if (!mounted || gen != _evaluateGen) return;
      setState(() => _evaluating = false);
    }
  }

  CalculatorResult _applyProductOverrides(CalculatorResult result) {
    if (_productOverrides.isEmpty) return result;
    final lines = <CalculatorSuggestedLine>[];
    for (final line in result.suggestedLines) {
      final key = line.selectionKey;
      if (key == null || !_productOverrides.containsKey(key)) {
        lines.add(line);
        continue;
      }
      final productId = _productOverrides[key]!;
      final match = line.alternatives.where((a) => a.productId == productId);
      if (match.isEmpty) {
        // Answers changed — drop stale override, keep cheapest default.
        _productOverrides.remove(key);
        lines.add(line);
        continue;
      }
      lines.add(line.copyWithProduct(match.first));
    }
    return result.withLines(lines);
  }

  void _pickAlternative(CalculatorSuggestedLine line, CalculatorProductOption option) {
    final key = line.selectionKey;
    if (key == null || _result == null) return;
    setState(() {
      _productOverrides[key] = option.productId;
      _result = _applyProductOverrides(_result!);
    });
  }

  Future<void> _goLoginForPrices() async {
    final slug = _selectedFamily?.slug ?? '';
    await CalculatorDraftStore.save(
      familySlug: slug,
      answers: Map<String, dynamic>.from(_answers),
      productOverrides: Map<String, String>.from(_productOverrides),
    );
    if (!mounted) return;
    final returnPath =
        slug.isNotEmpty ? '/calculator/$slug' : RouteNames.publicCalculatorList;
    context.go(AuthPostLogin.loginUrlWithReturn(returnPath));
  }

  Future<void> _saveQuotation() async {
    final user = FirebaseAuthSafe.currentUser;
    if (user == null) {
      _goLoginForPrices();
      return;
    }
    if (_result == null || _template == null) return;

    await showQuotationSavePopup(
      context: context,
      result: _result!,
      onSave: ({
        String? customerName,
        String? customerAddress,
        String? customerPhone,
      }) async {
        setState(() => _saving = true);
        try {
          final sessionId = await _authRepo.createSession(
            templateId: _template!.id,
            answers: _answers,
            result: {'ok': true},
          );
          if (sessionId == null) throw StateError('Could not create session');
          final qid = await _quotationRepo.createFromCalculatorResult(
            sessionId: sessionId,
            templateId: _template!.id,
            result: _result!,
            customerName: customerName,
            customerAddress: customerAddress,
            customerPhone: customerPhone,
          );
          return qid;
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
    );
  }

  Future<void> _orderNow() async {
    final r = _result;
    if (r == null || _ordering) return;
    final lines = r.suggestedLines.where((l) => (l.productId ?? '').isNotEmpty).toList();
    if (lines.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nothing to order'),
          content: const Text('Complete the calculator so products appear in your estimate first.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    setState(() => _ordering = true);
    try {
      // Persist quotation when signed in so it appears under Saved quotations.
      if (FirebaseAuthSafe.isSignedIn && _template != null) {
        try {
          final sessionId = await _authRepo.createSession(
            templateId: _template!.id,
            answers: _answers,
            result: {'ok': true},
          );
          if (sessionId != null) {
            await _quotationRepo.createFromCalculatorResult(
              sessionId: sessionId,
              templateId: _template!.id,
              result: r,
            );
          }
        } catch (_) {
          // Cart order still proceeds even if save fails.
        }
      }

      final added = await _orderHelper.addSuggestedLinesToCart(lines);
      if (!mounted) return;
      setState(() => _ordering = false);
      if (added == 0) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Could not add products'),
            content: const Text('Suggested products are unavailable right now. Try again later.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
        return;
      }
      final goCart = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Added to cart'),
          content: Text(
            '$added product${added == 1 ? '' : 's'} added to your cart.'
            '${FirebaseAuthSafe.isSignedIn ? ' Quotation was also saved to your account.' : ''}'
            '\n\nContinue to cart to place your order?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay here')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Go to cart')),
          ],
        ),
      );
      if (goCart == true && mounted) context.go(RouteNames.publicCart);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ordering = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Order failed'),
          content: Text('$e'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  }

  WebSeoMeta _seoMeta() {
    final family = _selectedFamily;
    if (family != null && family.slug.isNotEmpty) {
      return PublicSeoRegistry.calculatorDetail(
        name: family.name,
        slug: family.slug,
        description: family.description,
      );
    }
    return PublicSeoRegistry.calculatorList();
  }

  double get _estimatedTotal {
    final r = _result;
    if (r == null) return 0;
    var total = 0.0;
    for (final line in r.suggestedLines) {
      if (line.unitPrice != null) total += line.unitPrice! * line.qty;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return WebSeoScope(
      meta: _seoMeta(),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          body: Stack(
            children: [
              const _CalcAmbientMesh(),
              Column(
                children: [
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollStartNotification) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        }
                        return false;
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.deferToChild,
                        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                        child: CustomScrollView(
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: SizedBox(height: v.r(xs: 20, lg: 28))),
                            SliverToBoxAdapter(
                              child: V2PageContainer(
                                maxWidth: V2.maxContentWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: AccountBackButton(fallback: RouteNames.publicHome),
                                    ).animate().fadeIn(duration: 280.ms).slideX(begin: -0.04, end: 0),
                                    SizedBox(height: v.r(xs: 10, md: 20)),
                                    _hero(context, v)
                                        .animate()
                                        .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
                                        .slideY(begin: 0.04, end: 0, duration: 480.ms, curve: Curves.easeOutCubic),
                                    SizedBox(height: v.r(xs: 18, md: 40)),
                                    _workspace(context, v)
                                        .animate()
                                        .fadeIn(duration: 480.ms, delay: 40.ms)
                                        .slideY(begin: 0.03, end: 0, duration: 520.ms, delay: 40.ms),
                                    const SizedBox(height: V2.s16),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: V2Footer()),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: PublicFloatingMenu.contentBottomInset(
                                  context,
                                  hasAbove: !v.isDesktop,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!v.isDesktop)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: PublicFloatingMenu(
                    active: CustomerAccountTab.calculator,
                    above: _mobilePayDock(context),
                  ),
                )
              else
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: PublicFloatingMenu(active: CustomerAccountTab.calculator),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, V2Responsive v) {
    // Mobile: Apple-compact header — one job, no hero essay.
    if (!v.isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'D.G.YARD CALCULATOR',
            style: V2FontStyles.display(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: V2Colors.fgSubtle,
            ),
          )
              .animate()
              .fadeIn(duration: 360.ms)
              .slideX(begin: -0.06, end: 0, duration: 420.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 10),
          Text(
            'Specs. Products. Rates.',
            style: V2FontStyles.display(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              height: 1.08,
              color: V2Colors.ink,
            ),
          )
              .animate()
              .fadeIn(duration: 420.ms, delay: 40.ms)
              .slideY(begin: 0.08, end: 0, duration: 480.ms, delay: 40.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 8),
          Text(
            'Three calm steps to a clean quote.',
            style: V2Text.body().copyWith(
              color: V2Colors.fgSubtle,
              height: 1.4,
              fontSize: 15,
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 90.ms),
        ],
      );
    }

    return Column(
      children: [
        Text(
          'D.G.Yard',
          style: V2FontStyles.display(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: V2Colors.fgSubtle,
          ),
        )
            .animate()
            .fadeIn(duration: 480.ms)
            .slideY(begin: 0.2, end: 0, duration: 560.ms, curve: Curves.easeOutCubic),
        const SizedBox(height: 18),
        Text(
          'Specs. Products. Rates.',
          textAlign: TextAlign.center,
          style: V2FontStyles.display(
            fontSize: v.r(xs: 36, md: 52, lg: 60),
            fontWeight: FontWeight.w700,
            letterSpacing: -1.8,
            height: 1.02,
            color: V2Colors.ink,
          ),
        )
            .animate()
            .fadeIn(duration: 560.ms, delay: 60.ms)
            .slideY(begin: 0.12, end: 0, duration: 680.ms, delay: 60.ms, curve: Curves.easeOutCubic),
        const SizedBox(height: 10),
        Text(
          'Build a quote in three steps.',
          textAlign: TextAlign.center,
          style: V2FontStyles.display(
            fontSize: v.r(xs: 22, md: 28, lg: 32),
            fontWeight: FontWeight.w500,
            letterSpacing: -0.8,
            height: 1.15,
            color: V2Colors.fgSubtle,
          ),
        )
            .animate()
            .fadeIn(duration: 560.ms, delay: 120.ms)
            .slideY(begin: 0.12, end: 0, duration: 680.ms, delay: 120.ms, curve: Curves.easeOutCubic),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Answer your setup, pick matching gear, then lock the total — calm, fast, clear.',
            textAlign: TextAlign.center,
            style: V2Text.body().copyWith(
              color: V2Colors.fgSubtle,
              height: 1.55,
              fontSize: v.r(xs: 16, md: 17),
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 520.ms, delay: 180.ms)
            .slideY(begin: 0.06, end: 0, duration: 620.ms, delay: 180.ms),
      ],
    );
  }

  Widget _workspace(BuildContext context, V2Responsive v) {
    if (_loadingFamilies) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_families.isEmpty) {
      return _GlassCard(
        child: Text('No calculators published yet.', style: V2Text.body()),
      );
    }

    if (!v.isDesktop) {
      return _mobileWorkspace(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category', style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
              const SizedBox(height: 12),
              _SegmentedFamilies(
                families: _families,
                selectedId: _selectedFamily?.id,
                onSelect: _selectFamily,
              ),
              if (_selectedFamily != null) ...[
                const SizedBox(height: 16),
                Text(
                  _selectedFamily!.name,
                  style: V2Text.bodyEmph().copyWith(fontSize: 20),
                ),
                if ((_selectedFamily!.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _selectedFamily!.description!,
                    style: V2Text.small().copyWith(height: 1.45, color: V2Colors.fgSubtle),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _wizardProgressChrome(compact: false),
        const SizedBox(height: 20),
        if (_loadingTemplate)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_step == _CalcWizardStep.rates)
          Sticky(
            child: KeyedSubtree(
              key: const ValueKey('rates'),
              child: _estimateCard(context),
            )
                .animate()
                .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
                .slideY(begin: 0.035, end: 0, duration: 440.ms, curve: Curves.easeOutCubic)
                .scale(begin: const Offset(0.985, 0.985), end: const Offset(1, 1), duration: 440.ms),
          )
        else if (_questions.isEmpty)
          _GlassCard(
            child: Text(
              'No attributes or questions for this family yet. Add them in Admin → Family master.',
              style: V2Text.small(),
            ),
          )
        else
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.02, 0.03),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_step),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_step == _CalcWizardStep.specs) ...[
                        Text(
                          'Step 1 · Specs',
                          style: V2FontStyles.display(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: V2Colors.fgSubtle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tell us the setup',
                          style: V2FontStyles.display(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.7,
                            color: V2Colors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Answer every question first. Product picks come next.',
                          style: V2Text.small().copyWith(color: V2Colors.fgFaint, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        ..._buildGroupedQuestions(context, includeSuggestions: false),
                      ] else ...[
                        Text(
                          'Step 2 · Products',
                          style: V2FontStyles.display(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: V2Colors.fgSubtle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose your gear',
                          style: V2FontStyles.display(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.7,
                            color: V2Colors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Indoor, Outdoor, DVR, SMPS — tap a card to select.',
                          style: V2Text.small().copyWith(color: V2Colors.fgFaint, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        ..._buildProductsStep(context),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _wizardNavRow(showTotalChip: true),
              ],
            ),
          ),
        if (_step == _CalcWizardStep.rates) ...[
          const SizedBox(height: 16),
          _wizardNavRow(showTotalChip: false),
        ],
      ],
    );
  }

  /// Mobile: Apple Settings–style flow — chips, inset groups, step wizard.
  Widget _mobileWorkspace(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Category',
          style: V2Text.micro().copyWith(
            color: V2Colors.fgSubtle,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        _FamilyChipRow(
          families: _families,
          selectedId: _selectedFamily?.id,
          onSelect: _selectFamily,
        ),
        if ((_selectedFamily?.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _selectedFamily!.description!,
            style: V2Text.small().copyWith(height: 1.4, color: V2Colors.fgSubtle),
          ),
        ],
        const SizedBox(height: 18),
        _wizardProgressChrome(compact: true),
        const SizedBox(height: 16),
        if (_loadingTemplate)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_step == _CalcWizardStep.rates)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step 3 · Rates',
                style: V2Text.micro().copyWith(
                  color: V2Colors.fgSubtle,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your quote',
                style: V2FontStyles.display(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: V2Colors.ink,
                ),
              ),
              const SizedBox(height: 12),
              _estimateCard(context)
                  .animate()
                  .fadeIn(duration: 360.ms)
                  .slideY(begin: 0.03, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
            ],
          )
        else if (_questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'No questions for this category yet.',
              style: V2Text.small().copyWith(color: V2Colors.fgSubtle),
            ),
          )
        else ...[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0.04),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey('m-$_step'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _step == _CalcWizardStep.specs
                      ? 'Step 1 · Specs'
                      : 'Step 2 · Products',
                  style: V2Text.micro().copyWith(
                    color: V2Colors.fgSubtle,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _step == _CalcWizardStep.specs
                      ? 'Tell us the setup'
                      : 'Choose your gear',
                  style: V2FontStyles.display(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: V2Colors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _step == _CalcWizardStep.specs
                      ? 'Finish every question, then move to products.'
                      : 'Tap a card for Indoor, Outdoor, DVR, and more.',
                  style: V2Text.small().copyWith(color: V2Colors.fgSubtle, height: 1.35),
                ),
                const SizedBox(height: 14),
                if (_step == _CalcWizardStep.specs)
                  ..._buildGroupedQuestions(context, appleMobile: true, includeSuggestions: false)
                else
                  ..._buildProductsStep(context, appleMobile: true),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _wizardProgressChrome({required bool compact}) {
    const labels = ['Specs', 'Products', 'Rates'];
    final active = _step.index;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: V2Colors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: compact ? 16 : 18),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: i <= active ? 1 : 0),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: V2Colors.border.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: t.clamp(0.0, 1.0),
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: V2Colors.ink.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            _WizardStepDot(
              index: i + 1,
              label: labels[i],
              active: i == active,
              done: i < active,
              compact: compact,
              onTap: i < active
                  ? () {
                      setState(() => _step = _CalcWizardStep.values[i]);
                      _scrollToTop();
                    }
                  : null,
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 360.ms)
        .slideY(begin: 0.04, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _wizardNavRow({required bool showTotalChip}) {
    final canNext = _step == _CalcWizardStep.specs
        ? _canGoToProducts
        : _step == _CalcWizardStep.products;
    final nextLabel = _step == _CalcWizardStep.specs
        ? 'Continue to products'
        : _step == _CalcWizardStep.products
            ? 'See rates'
            : 'Done';
    final total = _estimatedTotal;
    return Row(
      children: [
        if (_step != _CalcWizardStep.specs)
          _CalcGhostButton(
            label: 'Back',
            icon: Icons.arrow_back_rounded,
            onTap: _goWizardBack,
          )
        else
          const SizedBox(width: 8),
        if (showTotalChip && (_pickableProductCount > 0 || total > 0)) ...[
          const SizedBox(width: 10),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: Text(
                _signedIn
                    ? 'Est. ${CalculatorPricePrivacy.formatOrDash(total)}'
                    : '$_pickableProductCount product${_pickableProductCount == 1 ? '' : 's'} ready',
                key: ValueKey('chip-$_signedIn-$_pickableProductCount-$total'),
                style: V2Text.micro().copyWith(
                  color: V2Colors.fgSubtle,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (_step != _CalcWizardStep.rates)
          _CalcInkButton(
            label: nextLabel,
            trailing: Icons.arrow_forward_rounded,
            enabled: canNext && !_evaluating,
            loading: _evaluating && _step == _CalcWizardStep.specs,
            onTap: () => _goWizardNext(),
          ),
        if (_step == _CalcWizardStep.rates)
          _CalcGhostButton(
            label: 'Edit specs',
            icon: Icons.tune_rounded,
            onTap: () {
              setState(() => _step = _CalcWizardStep.specs);
              _scrollToTop();
            },
          ),
      ],
    );
  }

  List<Widget> _buildProductsStep(BuildContext context, {bool appleMobile = false}) {
    final lines = (_result?.suggestedLines ?? const <CalculatorSuggestedLine>[])
        .where(_isPickableSuggestion)
        .toList();
    if (lines.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _evaluating
                ? 'Matching products…'
                : 'Nothing matched yet — go back and tweak quantities.',
            style: V2Text.small().copyWith(color: V2Colors.fgSubtle, height: 1.4),
          ),
        ),
      ];
    }

    lines.sort((a, b) {
      final an = (a.matchGroupName ?? a.label).toLowerCase();
      final bn = (b.matchGroupName ?? b.label).toLowerCase();
      final ai = an.contains('indoor')
          ? 0
          : (an.contains('outdoor')
              ? 1
              : (an.contains('dvr')
                  ? 2
                  : (an.contains('smps') ? 3 : 4)));
      final bi = bn.contains('indoor')
          ? 0
          : (bn.contains('outdoor')
              ? 1
              : (bn.contains('dvr')
                  ? 2
                  : (bn.contains('smps') ? 3 : 4)));
      if (ai != bi) return ai.compareTo(bi);
      return an.compareTo(bn);
    });

    final out = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final title = (line.matchGroupName ?? '').trim().isNotEmpty
          ? line.matchGroupName!.trim()
          : (line.label.trim().isNotEmpty ? line.label.trim() : 'Suggested products');
      out.add(
        Padding(
          padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : (appleMobile ? 12 : 16)),
          child: appleMobile
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: _GroupProductSuggestions(
                    matchLine: line,
                    title: title,
                    evaluating: _evaluating,
                    compact: true,
                    onPick: (picked, opt) => _pickAlternative(picked, opt),
                  ),
                )
              : _GroupProductSuggestions(
                  matchLine: line,
                  title: title,
                  evaluating: _evaluating,
                  compact: false,
                  onPick: (picked, opt) => _pickAlternative(picked, opt),
                ),
        )
            .animate()
            .fadeIn(duration: 320.ms, delay: (30 * i).ms)
            .slideY(begin: 0.02, end: 0, duration: 360.ms, delay: (30 * i).ms),
      );
    }
    return out;
  }
  List<Widget> _buildGroupedQuestions(
    BuildContext context, {
    bool appleMobile = false,
    bool includeSuggestions = true,
  }) {
    final visible = _questions.where((q) => q.isVisibleGiven(_answers)).toList();
    final familyTitle = _selectedFamily?.name.trim().isNotEmpty == true
        ? _selectedFamily!.name.trim()
        : 'Main options';

    // Prefer DB sort_order (not list index) so admin reorder always wins.
    final groupOrder = <String, int>{
      for (final g in _groups) g.id: g.sortOrder,
    };
    final groupNameById = <String, String>{
      for (final g in _groups) g.id: g.name,
    };

    // Put root attributes + follow-ups into the same quotation group when groupId is set
    // (e.g. Camera type + quantity + resolution under "Camera").
    final sections = <String, List<CalculatorQuestion>>{};
    final sectionMeta = <String, ({String title, int sort})>{};
    final ungroupedRoots = <CalculatorQuestion>[];

    for (final q in visible) {
      final hasGroup = q.groupId != null && q.groupId!.isNotEmpty;
      final isRoot = q.showWhenKey == null || q.showWhenKey!.isEmpty;
      if (isRoot && !hasGroup) {
        ungroupedRoots.add(q);
        continue;
      }
      final key = hasGroup
          ? q.groupId!
          : '__ungrouped__';
      sections.putIfAbsent(key, () => []).add(q);
      sectionMeta.putIfAbsent(
        key,
        () => (
          title: (q.groupName ?? '').trim().isNotEmpty
              ? q.groupName!.trim()
              : (groupNameById[key] ?? 'More options'),
          sort: groupOrder[key] ?? q.groupSortOrder,
        ),
      );
    }

    ungroupedRoots.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final list in sections.values) {
      list.sort((a, b) {
        // Root family attributes first, then follow-ups by saved question order.
        final ar = (a.showWhenKey == null || a.showWhenKey!.isEmpty) ? 0 : 1;
        final br = (b.showWhenKey == null || b.showWhenKey!.isEmpty) ? 0 : 1;
        if (ar != br) return ar.compareTo(br);
        final so = a.sortOrder.compareTo(b.sortOrder);
        if (so != 0) return so;
        return a.label.compareTo(b.label);
      });
    }

    // Product-only empty groups (DVR/SMPS) belong on Products step, not Specs.
    if (includeSuggestions) {
      for (final g in _groups) {
        if (sections.containsKey(g.id)) continue;
        final hasLines = (_result?.suggestedLines ?? const <CalculatorSuggestedLine>[])
            .any(
              (l) =>
                  _isDisplayableSuggestion(l) &&
                  (l.showUnderQuestionKey ?? '').trim().isEmpty &&
                  l.matchGroupId == g.id,
            );
        if (!hasLines) continue;
        sections[g.id] = [];
        sectionMeta[g.id] = (title: g.name, sort: g.sortOrder);
      }
    }

    final groupKeys = sections.keys.toList()
      ..sort((a, b) {
        final sa = groupOrder[a] ?? sectionMeta[a]?.sort ?? 9999;
        final sb = groupOrder[b] ?? sectionMeta[b]?.sort ?? 9999;
        if (sa != sb) return sa.compareTo(sb);
        if (a == '__ungrouped__') return 1;
        if (b == '__ungrouped__') return -1;
        final ta = groupNameById[a] ?? sectionMeta[a]?.title ?? a;
        final tb = groupNameById[b] ?? sectionMeta[b]?.title ?? b;
        return ta.compareTo(tb);
      });

    // Drop empty question sections on Specs (no suggestion-only chrome).
    if (!includeSuggestions) {
      groupKeys.removeWhere((k) => (sections[k] ?? const []).isEmpty);
    }

    final showOrphans = includeSuggestions && _hasOrphanRuleSuggestions;
    final out = <Widget>[];
    var sectionIndex = 0;

    if (ungroupedRoots.isNotEmpty) {
      out.add(
        _questionSectionCard(
          key: '__family_root__',
          title: familyTitle,
          questions: ungroupedRoots,
          sectionIndex: sectionIndex++,
          isLast: groupKeys.isEmpty && !showOrphans,
          appleMobile: appleMobile,
          includeSuggestions: includeSuggestions,
        ),
      );
    }

    for (var i = 0; i < groupKeys.length; i++) {
      final key = groupKeys[i];
      out.add(
        _questionSectionCard(
          key: key,
          title: groupNameById[key] ?? sectionMeta[key]!.title,
          questions: sections[key]!,
          sectionIndex: sectionIndex++,
          isLast: i == groupKeys.length - 1 && !showOrphans,
          appleMobile: appleMobile,
          includeSuggestions: includeSuggestions,
        ),
      );
    }

    // Suggest-product rules without a question group still show pickable cards.
    if (showOrphans) {
      out.add(_orphanRuleSuggestionsCard(sectionIndex: sectionIndex, appleMobile: appleMobile));
    }
    return out;
  }
  /// True when [matchGroupId] maps to a real question-group section on this page.
  bool _isAttachedToQuestionGroup(String? matchGroupId) {
    final id = (matchGroupId ?? '').trim();
    if (id.isEmpty) return false;
    if (id == '__family_root__' || id == '__ungrouped__') return true;
    if (id == '__rule_suggests__') return false;
    return _groups.any((g) => g.id == id);
  }

  bool _isPickableSuggestion(CalculatorSuggestedLine l) =>
      l.selectionKey != null && l.alternatives.isNotEmpty;

  bool _isChargeLine(CalculatorSuggestedLine l) =>
      (l.selectionKey ?? '').startsWith('charge:') &&
      (l.unitPrice ?? 0) > 0 &&
      l.qty > 0;

  bool _isDisplayableSuggestion(CalculatorSuggestedLine l) =>
      _isPickableSuggestion(l) || _isChargeLine(l);

  /// Attach Indoor/Outdoor (and similar) rule lines to the section that holds their qty.
  bool _ruleLineBelongsInSection(
    CalculatorSuggestedLine l,
    String sectionKey,
    List<CalculatorQuestion> questions,
  ) {
    if (!_isDisplayableSuggestion(l)) return false;
    // Placed directly under a question — not at section footer.
    if ((l.showUnderQuestionKey ?? '').trim().isNotEmpty) return false;
    if (l.matchGroupId == sectionKey) return true;
    // Already owned by another real group section — don't duplicate.
    if (_isAttachedToQuestionGroup(l.matchGroupId)) return false;

    final keys = questions.map((q) => q.questionKey).toSet();
    final gid = (l.matchGroupId ?? '').trim().toLowerCase();
    final name = (l.matchGroupName ?? '').trim().toLowerCase();

    final looksIndoor = gid.contains('indoor') || name.contains('indoor');
    final looksOutdoor = gid.contains('outdoor') || name.contains('outdoor');
    if (looksIndoor && !looksOutdoor) {
      return keys.contains('indoor_qty') || keys.contains('Indoor_Camera_Quantity');
    }
    if (looksOutdoor) {
      return keys.contains('outdoor_qty') || keys.contains('Outdoor_Camera_Quantity');
    }
    return false;
  }

  List<CalculatorSuggestedLine> _suggestionsUnderQuestion(String questionKey) {
    final key = questionKey.trim();
    if (key.isEmpty) return const [];
    final list = (_result?.suggestedLines ?? const <CalculatorSuggestedLine>[])
        .where(
          (l) =>
              _isDisplayableSuggestion(l) &&
              (l.showUnderQuestionKey ?? '').trim() == key,
        )
        .toList();
    return list;
  }

  Widget _suggestionsBlockForQuestion(
    CalculatorQuestion q, {
    required bool appleMobile,
  }) {
    final lines = _suggestionsUnderQuestion(q.questionKey);
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(
        top: appleMobile ? 8 : 10,
        bottom: appleMobile ? 4 : 4,
      ),
      child: Column(
        children: [
          for (final line in lines)
            if (_isChargeLine(line))
              _EstimateLine(
                line: line,
                showPrices: CalculatorPricePrivacy.canSeePrices,
              )
            else
              _GroupProductSuggestions(
                matchLine: line,
                title: (line.matchGroupName ?? '').trim().isNotEmpty
                    ? line.matchGroupName!.trim()
                    : 'Suggested products',
                evaluating: _evaluating,
                compact: appleMobile,
                onPick: (picked, opt) => _pickAlternative(picked, opt),
              ),
        ],
      ),
    );
  }

  bool get _hasOrphanRuleSuggestions {
    final lines = _result?.suggestedLines ?? const <CalculatorSuggestedLine>[];
    final byGroup = <String, List<CalculatorQuestion>>{};
    for (final q in _questions) {
      final gid = q.groupId;
      if (gid == null || gid.isEmpty) continue;
      byGroup.putIfAbsent(gid, () => []).add(q);
    }
    return lines.any((l) {
      if (!_isPickableSuggestion(l)) return false;
      if ((l.showUnderQuestionKey ?? '').trim().isNotEmpty) {
        // Shown under that question when visible; otherwise orphan fallback.
        final under = l.showUnderQuestionKey!.trim();
        final visible = _questions.any(
          (q) => q.questionKey == under && q.isVisibleGiven(_answers),
        );
        return !visible;
      }
      if (l.matchGroupId == '__rule_suggests__') return true;
      if (_isAttachedToQuestionGroup(l.matchGroupId)) return false;
      for (final e in byGroup.entries) {
        if (_ruleLineBelongsInSection(l, e.key, e.value)) return false;
      }
      return true;
    });
  }

  Widget _orphanRuleSuggestionsCard({
    required int sectionIndex,
    bool appleMobile = false,
  }) {
    final byGroup = <String, List<CalculatorQuestion>>{};
    for (final q in _questions) {
      final gid = q.groupId;
      if (gid == null || gid.isEmpty) continue;
      byGroup.putIfAbsent(gid, () => []).add(q);
    }
    final lines = (_result?.suggestedLines ?? const <CalculatorSuggestedLine>[])
        .where((l) {
          if (!_isPickableSuggestion(l)) return false;
          if ((l.showUnderQuestionKey ?? '').trim().isNotEmpty) {
            final under = l.showUnderQuestionKey!.trim();
            final visible = _questions.any(
              (q) => q.questionKey == under && q.isVisibleGiven(_answers),
            );
            return !visible;
          }
          if (_isAttachedToQuestionGroup(l.matchGroupId) &&
              l.matchGroupId != '__rule_suggests__') {
            return false;
          }
          if (l.matchGroupId == '__rule_suggests__') return true;
          for (final e in byGroup.entries) {
            if (_ruleLineBelongsInSection(l, e.key, e.value)) return false;
          }
          return true;
        })
        .toList();
    // Stable order: Indoor before Outdoor, then name.
    lines.sort((a, b) {
      final an = (a.matchGroupName ?? a.label).toLowerCase();
      final bn = (b.matchGroupName ?? b.label).toLowerCase();
      final ai = an.contains('indoor') ? 0 : (an.contains('outdoor') ? 1 : 2);
      final bi = bn.contains('indoor') ? 0 : (bn.contains('outdoor') ? 1 : 2);
      if (ai != bi) return ai.compareTo(bi);
      return an.compareTo(bn);
    });
    return Container(
      margin: EdgeInsets.only(bottom: appleMobile ? 14 : 8),
      padding: EdgeInsets.fromLTRB(
        appleMobile ? 0 : 16,
        appleMobile ? 4 : 16,
        appleMobile ? 0 : 16,
        appleMobile ? 4 : 8,
      ),
      decoration: appleMobile
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: const Color(0xFFF7F7F9),
              border: Border.all(color: V2Colors.border.withValues(alpha: 0.65)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (appleMobile)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'SUGGESTED',
                style: V2Text.micro().copyWith(
                  color: V2Colors.fgSubtle,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            )
          else ...[
            Text(
              'Suggested products',
              style: V2Text.bodyEmph().copyWith(
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Indoor and outdoor cameras appear as separate picks',
              style: V2Text.micro().copyWith(color: V2Colors.fgSubtle, height: 1.35),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: appleMobile
                ? BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            padding: appleMobile ? const EdgeInsets.fromLTRB(14, 12, 14, 8) : EdgeInsets.zero,
            child: Column(
              children: [
                for (final line in lines)
                  _GroupProductSuggestions(
                    matchLine: line,
                    title: (line.matchGroupName ?? '').trim().isNotEmpty
                        ? line.matchGroupName!.trim()
                        : 'Suggested products',
                    evaluating: _evaluating,
                    compact: appleMobile,
                    onPick: (picked, opt) => _pickAlternative(picked, opt),
                  ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 360.ms, delay: (40 * sectionIndex).ms)
        .slideY(begin: 0.02, end: 0, duration: 400.ms, delay: (40 * sectionIndex).ms);
  }

  Widget _questionSectionCard({
    required String key,
    required String title,
    required List<CalculatorQuestion> questions,
    required int sectionIndex,
    required bool isLast,
    bool appleMobile = false,
    bool includeSuggestions = true,
  }) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!appleMobile)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: V2Colors.plasma.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: V2Text.bodyEmph().copyWith(
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '${questions.length}',
                style: V2Text.micro().copyWith(color: V2Colors.fgFaint),
              ),
            ],
          ),
        if (!appleMobile) const SizedBox(height: 14),
        for (var qi = 0; qi < questions.length; qi++) ...[
          _questionField(questions[qi], appleMobile: appleMobile)
              .animate()
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.03, end: 0, duration: 320.ms),
          if (includeSuggestions)
            _suggestionsBlockForQuestion(
              questions[qi],
              appleMobile: appleMobile,
            ),
          if (qi < questions.length - 1)
            appleMobile
                ? Divider(height: 1, thickness: 0.5, color: V2Colors.border.withValues(alpha: 0.7))
                : const SizedBox(height: 16)
          else if (!appleMobile)
            const SizedBox(height: 8),
        ],
        if (includeSuggestions && key != '__family_root__')
          ...[
            for (final line in () {
              final list = (_result?.suggestedLines ??
                      const <CalculatorSuggestedLine>[])
                  .where((l) => _ruleLineBelongsInSection(l, key, questions))
                  .toList();
              list.sort((a, b) {
                final an = (a.matchGroupName ?? a.label).toLowerCase();
                final bn = (b.matchGroupName ?? b.label).toLowerCase();
                final ai =
                    an.contains('indoor') ? 0 : (an.contains('outdoor') ? 1 : 2);
                final bi =
                    bn.contains('indoor') ? 0 : (bn.contains('outdoor') ? 1 : 2);
                if (ai != bi) return ai.compareTo(bi);
                return an.compareTo(bn);
              });
              return list;
            }())
              if (_isChargeLine(line))
                Padding(
                  padding: EdgeInsets.only(
                    top: appleMobile ? 8 : 10,
                    bottom: appleMobile ? 4 : 6,
                  ),
                  child: _EstimateLine(
                    line: line,
                    showPrices: CalculatorPricePrivacy.canSeePrices,
                  ),
                )
              else
                _GroupProductSuggestions(
                  matchLine: line,
                  title: (line.matchGroupName ?? '').trim().isNotEmpty
                      ? line.matchGroupName!.trim()
                      : (line.sourceRuleId != null
                          ? 'Suggested products'
                          : 'Suggested for this group'),
                  evaluating: _evaluating,
                  compact: appleMobile,
                  onPick: (picked, opt) => _pickAlternative(picked, opt),
                ),
          ],
        if (includeSuggestions && key == '__family_root__')
          ...[
            for (final line in (_result?.suggestedLines ?? const <CalculatorSuggestedLine>[])
                .where(
                  (l) =>
                      l.matchGroupId == '__family_root__' &&
                      _isPickableSuggestion(l),
                ))
              _GroupProductSuggestions(
                matchLine: line,
                title: (line.matchGroupName ?? '').trim().isNotEmpty
                    ? line.matchGroupName!.trim()
                    : 'Suggested products',
                evaluating: _evaluating,
                compact: appleMobile,
                onPick: (picked, opt) => _pickAlternative(picked, opt),
              ),
          ],
      ],
    );

    if (appleMobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: isLast ? 8 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                title.toUpperCase(),
                style: V2Text.micro().copyWith(
                  color: V2Colors.fgSubtle,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: body,
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 320.ms, delay: (30 * sectionIndex).ms)
          .slideY(begin: 0.02, end: 0, duration: 360.ms, delay: (30 * sectionIndex).ms);
    }

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 8 : 20),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFF7F7F9),
        border: Border.all(color: V2Colors.border.withValues(alpha: 0.65)),
      ),
      child: body,
    )
        .animate()
        .fadeIn(duration: 360.ms, delay: (40 * sectionIndex).ms)
        .slideY(begin: 0.02, end: 0, duration: 400.ms, delay: (40 * sectionIndex).ms);
  }

  Widget _questionField(CalculatorQuestion q, {bool appleMobile = false}) {
    return _QuestionField(
      question: q,
      value: _answers[q.questionKey],
      controller: _textControllers[q.questionKey],
      appleMobile: appleMobile,
      onChanged: (v) {
        setState(() {
          _answers[q.questionKey] = v;
          for (final other in _questions) {
            if (!other.isVisibleGiven(_answers)) {
              _answers.remove(other.questionKey);
              continue;
            }
            // Newly unlocked follow-ups need a blank slot (not removed key).
            if (!_answers.containsKey(other.questionKey)) {
              if (other.uiType == 'number' ||
                  other.uiType == 'slider' ||
                  other.uiType == 'integer') {
                if (!_textControllers.containsKey(other.questionKey)) {
                  _textControllers[other.questionKey] =
                      TextEditingController(text: '');
                }
              } else {
                _answers[other.questionKey] = '';
                if (other.uiType == 'text' &&
                    !_textControllers.containsKey(other.questionKey)) {
                  _textControllers[other.questionKey] =
                      TextEditingController(text: '');
                }
              }
            }
          }
        });
        _scheduleEvaluate();
      },
    );
  }
  Widget _estimateCard(BuildContext context) {
    final r = _result;
    final total = _estimatedTotal;
    final hasLines = r != null && (r.suggestedLines.isNotEmpty || r.formulas.isNotEmpty);
    final showPrices = _signedIn;

    return _GlassCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 3 · Rates',
                      style: V2FontStyles.display(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: V2Colors.fgSubtle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your estimate',
                      style: V2FontStyles.display(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: V2Colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: _evaluating ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasLines
                ? (showPrices
                    ? 'Products and installation charges from your setup.'
                    : 'Lines are ready. Sign in to unlock live pricing.')
                : 'Complete Specs and Products, then your estimate appears here.',
            style: V2Text.small().copyWith(color: V2Colors.fgSubtle, height: 1.45),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: !hasLines
                ? Container(
                    key: const ValueKey('empty'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF7F7F9), Color(0xFFEEEEF1)],
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 30,
                          color: V2Colors.ink.withValues(alpha: 0.45),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(0.94, 0.94),
                              end: const Offset(1.06, 1.06),
                              duration: 1600.ms,
                              curve: Curves.easeInOut,
                            ),
                        const SizedBox(height: 14),
                        Text(
                          _hasPathFollowUps
                              ? 'Select options, then answer follow-ups'
                              : 'Select options to build your estimate',
                          textAlign: TextAlign.center,
                          style: V2Text.small().copyWith(color: V2Colors.fgSubtle),
                        ),
                      ],
                    ),
                  )
                : Column(
                    key: ValueKey('lines-${r.suggestedLines.length}-$total-$showPrices'),
                    children: [
                      for (var i = 0; i < r.suggestedLines.length; i++) ...[
                        _EstimateLine(
                          line: r.suggestedLines[i],
                          showPrices: showPrices,
                        )
                            .animate()
                            .fadeIn(duration: 320.ms, delay: (40 * i).ms)
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              duration: 380.ms,
                              delay: (40 * i).ms,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: 10),
                      ],
                      if (r.formulas.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...r.formulas.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formulaLabel(f.key),
                                    style: V2Text.small().copyWith(color: V2Colors.fgSubtle),
                                  ),
                                ),
                                Text(
                                  showPrices
                                      ? f.value.toStringAsFixed(0)
                                      : CalculatorPricePrivacy.masked,
                                  style: V2Text.bodyEmph().copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          if (total > 0 || (hasLines && !showPrices)) ...[
            const SizedBox(height: 20),
            Container(height: 1, color: V2Colors.border.withValues(alpha: 0.65)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Total', style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: Text(
                    CalculatorPricePrivacy.formatOrDash(total),
                    key: ValueKey('total-$showPrices-$total'),
                    style: V2FontStyles.display(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                      color: V2Colors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (!showPrices)
            _PrimaryCta(
              label: 'Login / Sign up to see price',
              loading: false,
              enabled: true,
              onTap: _goLoginForPrices,
            )
          else ...[
            _PrimaryCta(
              label: 'Save quotation',
              loading: _saving,
              enabled: hasLines && !_saving && !_ordering,
              onTap: _saveQuotation,
            ),
            const SizedBox(height: 10),
            _SecondaryCta(
              label: 'Order now',
              loading: _ordering,
              enabled: hasLines && !_saving && !_ordering,
              onTap: _orderNow,
            ),
          ],
          const SizedBox(height: 14),
          Text(
            showPrices
                ? 'Indicative pricing from live catalog. Final quote may vary.'
                : 'Prices stay private until you sign in — then totals unlock instantly.',
            textAlign: TextAlign.center,
            style: V2Text.micro().copyWith(color: V2Colors.fgFaint),
          ),
        ],
      ),
    );
  }

  Widget _mobilePayDock(BuildContext context) {
    if (_step != _CalcWizardStep.rates) {
      return _mobileWizardNavDock(context);
    }

    final total = _estimatedTotal;
    final showPrices = _signedIn;
    final hasLines = (_result?.suggestedLines.isNotEmpty ?? false);
    final itemCount = _result?.suggestedLines.length ?? 0;
    final busy = _saving || _ordering;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: const Color(0xFF1D1D1F),
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: hasLines ? () => _openMobileEstimateSheet(context) : null,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                showPrices ? 'Estimate' : 'Prices locked',
                                style: V2Text.micro().copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (hasLines) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasLines || total > 0
                                ? CalculatorPricePrivacy.formatOrDash(total)
                                : '—',
                            style: V2FontStyles.display(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              color: Colors.white,
                            ),
                          ),
                          if (hasLines)
                            Text(
                              '$itemCount item${itemCount == 1 ? '' : 's'} · tap for details',
                              style: V2Text.micro().copyWith(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!showPrices)
                      FilledButton(
                        onPressed: _goLoginForPrices,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1D1D1F),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'See price',
                          style: V2Text.bodyEmph().copyWith(
                            color: const Color(0xFF1D1D1F),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showPrices && hasLines) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : _saveQuotation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.4),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save quotation',
                                style: V2Text.bodyEmph().copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : _orderNow,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1D1D1F),
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.35),
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _ordering
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1D1D1F),
                                ),
                              )
                            : Text(
                                'Order now',
                                style: V2Text.bodyEmph().copyWith(
                                  color: const Color(0xFF1D1D1F),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _goWizardBack,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.75),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('← Back to products'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileWizardNavDock(BuildContext context) {
    final canNext = _step == _CalcWizardStep.specs
        ? _canGoToProducts
        : true;
    final nextLabel =
        _step == _CalcWizardStep.specs ? 'Continue' : 'See rates';
    final hint = _step == _CalcWizardStep.specs
        ? (_canGoToProducts
            ? 'Specs look good'
            : 'Finish the questions')
        : (_pickableProductCount > 0
            ? '$_pickableProductCount group${_pickableProductCount == 1 ? '' : 's'} ready'
            : 'Review picks, then rates');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: kIsWeb ? 0 : 18, sigmaY: kIsWeb ? 0 : 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1F).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_step != _CalcWizardStep.specs)
                    IconButton(
                      onPressed: _goWizardBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        hint,
                        key: ValueKey(hint),
                        style: V2Text.micro().copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                  _CalcInkButton(
                    label: nextLabel,
                    trailing: Icons.arrow_forward_rounded,
                    light: true,
                    enabled: canNext && !_evaluating,
                    loading: _evaluating && _step == _CalcWizardStep.specs,
                    onTap: () => _goWizardNext(),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 320.ms)
          .slideY(begin: 0.12, end: 0, duration: 380.ms, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _openMobileEstimateSheet(BuildContext context) async {
    final r = _result;
    if (r == null || r.suggestedLines.isEmpty) return;
    final showPrices = _signedIn;
    final total = _estimatedTotal;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D1D6),
                      borderRadius: BorderRadius.circular(980),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'Your estimate',
                          style: V2FontStyles.display(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: V2Colors.ink,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        Text(
                          showPrices
                              ? 'One product per group from your specs. Switch cards under each group.'
                              : 'Products are ready. Sign in to unlock live pricing.',
                          style: V2Text.small().copyWith(
                            color: V2Colors.fgSubtle,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final line in r.suggestedLines) ...[
                          _EstimateLine(line: line, showPrices: showPrices),
                          const SizedBox(height: 8),
                        ],
                        if (r.formulas.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...r.formulas.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formulaLabel(f.key),
                                      style: V2Text.small().copyWith(
                                        color: V2Colors.fgSubtle,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    showPrices
                                        ? f.value.toStringAsFixed(0)
                                        : CalculatorPricePrivacy.masked,
                                    style: V2Text.bodyEmph().copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Total',
                                style: V2Text.bodyEmph().copyWith(fontSize: 16),
                              ),
                              const Spacer(),
                              Text(
                                CalculatorPricePrivacy.formatOrDash(total),
                                style: V2FontStyles.display(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                  color: V2Colors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (!showPrices)
                          _PrimaryCta(
                            label: 'Login / Sign up to see price',
                            loading: false,
                            enabled: true,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _goLoginForPrices();
                            },
                          )
                        else ...[
                          _PrimaryCta(
                            label: 'Save quotation',
                            loading: _saving,
                            enabled: !_saving && !_ordering,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _saveQuotation();
                            },
                          ),
                          const SizedBox(height: 10),
                          _SecondaryCta(
                            label: 'Order now',
                            loading: _ordering,
                            enabled: !_saving && !_ordering,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _orderNow();
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          showPrices
                              ? 'Indicative pricing from live catalog. Final quote may vary.'
                              : 'Prices stay private until you sign in — then totals unlock instantly.',
                          textAlign: TextAlign.center,
                          style: V2Text.micro().copyWith(color: V2Colors.fgFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formulaLabel(String key) {
    return switch (key) {
      'bnc_qty' => 'BNC connectors',
      'dc_connector_qty' => 'DC connectors',
      'cat6_qty' => 'Cat6 cable (m)',
      'rj45_qty' => 'RJ45 connectors',
      _ => key.replaceAll('_', ' '),
    };
  }
}

class _WizardStepDot extends StatelessWidget {
  const _WizardStepDot({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
    required this.compact,
    this.onTap,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = active || done ? V2Colors.ink : V2Colors.fgFaint;
    final bg = active
        ? const Color(0xFF1D1D1F)
        : done
            ? const Color(0xFFE8E8ED)
            : Colors.white;
    final fg = active ? Colors.white : ink;
    final size = compact ? 28.0 : 34.0;
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: active ? 1.08 : 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: active || done
                    ? Colors.transparent
                    : V2Colors.border.withValues(alpha: 0.9),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: done && !active
                  ? Icon(
                      Icons.check_rounded,
                      key: const ValueKey('check'),
                      size: compact ? 14 : 16,
                      color: ink,
                    )
                  : Text(
                      '$index',
                      key: ValueKey('n-$index-$active'),
                      style: V2Text.micro().copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: compact ? 5 : 7),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: V2Text.micro().copyWith(
            color: ink,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: compact ? 11 : 12,
          ),
          child: Text(label),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: child,
      ),
    );
  }
}

class _CalcInkButton extends StatefulWidget {
  const _CalcInkButton({
    required this.label,
    required this.onTap,
    this.trailing,
    this.enabled = true,
    this.loading = false,
    this.light = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? trailing;
  final bool enabled;
  final bool loading;
  final bool light;

  @override
  State<_CalcInkButton> createState() => _CalcInkButtonState();
}

class _CalcInkButtonState extends State<_CalcInkButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.loading;
    final bg = widget.light
        ? Colors.white
        : (enabled ? const Color(0xFF1D1D1F) : V2Colors.border);
    final fg = widget.light
        ? const Color(0xFF1D1D1F)
        : (enabled ? Colors.white : V2Colors.fgFaint);
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: enabled || widget.loading ? 1 : 0.55,
          duration: const Duration(milliseconds: 180),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled && !widget.light
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: widget.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: V2Text.bodyEmph().copyWith(
                          color: fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (widget.trailing != null) ...[
                        const SizedBox(width: 6),
                        Icon(widget.trailing, size: 16, color: fg),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CalcGhostButton extends StatefulWidget {
  const _CalcGhostButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_CalcGhostButton> createState() => _CalcGhostButtonState();
}

class _CalcGhostButtonState extends State<_CalcGhostButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF5F5F7) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: V2Colors.ink),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: V2Text.bodyEmph().copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: V2Colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft mesh background — Apple product page energy without noise.
class _CalcAmbientMesh extends StatelessWidget {
  const _CalcAmbientMesh();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFFF5F5F7), child: SizedBox.expand()),
          Positioned(
            top: -120,
            left: MediaQuery.sizeOf(context).width * 0.2,
            child: _orb(420, const Color(0xFF7EB6FF).withValues(alpha: 0.22)),
          ),
          Positioned(
            top: 180,
            right: -80,
            child: _orb(340, V2Colors.plasma.withValues(alpha: 0.12)),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _orb(280, V2Colors.ember.withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.highlight = false});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withValues(alpha: kIsWeb
            ? (highlight ? 0.96 : 0.92)
            : (highlight ? 0.90 : 0.74)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: highlight ? 0.08 : 0.045),
            blurRadius: highlight ? 48 : 36,
            offset: Offset(0, highlight ? 20 : 14),
          ),
        ],
      ),
      child: child,
    );
    // BackdropFilter is very expensive on Safari / Flutter web — skip blur there.
    if (kIsWeb) {
      return ClipRRect(borderRadius: BorderRadius.circular(32), child: card);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: card,
      ),
    );
  }
}

/// Keeps estimate card in view on desktop while config scrolls.
class Sticky extends StatelessWidget {
  const Sticky({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _FamilyChipRow extends StatelessWidget {
  const _FamilyChipRow({
    required this.families,
    required this.selectedId,
    required this.onSelect,
  });

  final List<CalculatorFamily> families;
  final String? selectedId;
  final ValueChanged<CalculatorFamily> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: families.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = families[i];
          final selected = f.id == selectedId;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(f),
              borderRadius: BorderRadius.circular(980),
              splashFactory: NoSplash.splashFactory,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? V2Colors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(980),
                  border: Border.all(
                    color: selected
                        ? V2Colors.ink
                        : V2Colors.border.withValues(alpha: 0.8),
                  ),
                ),
                child: Text(
                  f.name,
                  style: V2Text.bodyEmph().copyWith(
                    fontSize: 14,
                    color: selected ? Colors.white : V2Colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SegmentedFamilies extends StatelessWidget {
  const _SegmentedFamilies({
    required this.families,
    required this.selectedId,
    required this.onSelect,
  });

  final List<CalculatorFamily> families;
  final String? selectedId;
  final ValueChanged<CalculatorFamily> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8ED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 420;
          if (!wide) {
            return Column(
              children: [
                for (final f in families)
                  _SegItem(
                    label: f.name,
                    selected: f.id == selectedId,
                    expand: true,
                    onTap: () => onSelect(f),
                  ),
              ],
            );
          }
          return Row(
            children: [
              for (final f in families)
                Expanded(
                  child: _SegItem(
                    label: f.name,
                    selected: f.id == selectedId,
                    expand: true,
                    onTap: () => onSelect(f),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  const _SegItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashFactory: NoSplash.splashFactory,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V2Text.bodyEmph().copyWith(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? V2Colors.ink : V2Colors.fgSubtle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({
    required this.question,
    required this.value,
    required this.onChanged,
    this.controller,
    this.appleMobile = false,
  });

  final CalculatorQuestion question;
  final dynamic value;
  final TextEditingController? controller;
  final ValueChanged<dynamic> onChanged;
  final bool appleMobile;

  @override
  Widget build(BuildContext context) {
    if (question.uiType == 'select' && (question.options?.isNotEmpty ?? false)) {
      if (appleMobile) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.label,
                style: V2Text.small().copyWith(
                  color: V2Colors.fgSubtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < question.options!.length; i++) ...[
                _AppleChoiceRow(
                  label: question.options![i],
                  selected: value?.toString() == question.options![i],
                  onTap: () => onChanged(question.options![i]),
                ),
                if (i < question.options!.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.label, style: V2Text.bodyEmph().copyWith(fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in question.options!)
                _PillOption(
                  label: opt,
                  selected: value?.toString() == opt,
                  onTap: () => onChanged(opt),
                ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: appleMobile ? 10 : 0),
      child: _AppleField(
        label: question.label,
        controller: controller,
        keyboard: question.uiType == 'number' ? TextInputType.number : TextInputType.text,
        flat: appleMobile,
        onChanged: (v) {
          if (question.uiType == 'number') {
            onChanged(int.tryParse(v) ?? double.tryParse(v) ?? 0);
          } else {
            onChanged(v);
          }
        },
      ),
    );
  }
}

class _AppleChoiceRow extends StatelessWidget {
  const _AppleChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? V2Colors.ink : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: V2Text.bodyEmph().copyWith(
                    fontSize: 15,
                    color: selected ? Colors.white : V2Colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20,
                color: selected ? Colors.white : V2Colors.fgFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _PillOption extends StatelessWidget {
  const _PillOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(980),
        splashFactory: NoSplash.splashFactory,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(980),
            color: selected ? V2Colors.ink : Colors.white.withValues(alpha: 0.85),
            border: Border.all(
              color: selected ? V2Colors.ink : V2Colors.border,
            ),
          ),
          child: Text(
            label,
            style: V2Text.bodyEmph().copyWith(
              fontSize: 14,
              color: selected ? Colors.white : V2Colors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleField extends StatefulWidget {
  const _AppleField({
    required this.label,
    required this.onChanged,
    this.controller,
    this.keyboard,
    this.flat = false,
  });

  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboard;
  final ValueChanged<String> onChanged;
  final bool flat;

  @override
  State<_AppleField> createState() => _AppleFieldState();
}

class _AppleFieldState extends State<_AppleField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.flat ? 12 : 16),
        color: widget.flat
            ? const Color(0xFFF2F2F7)
            : Colors.white.withValues(alpha: 0.9),
        border: widget.flat
            ? null
            : Border.all(
                color: _focused ? V2Colors.ink.withValues(alpha: 0.35) : V2Colors.border,
                width: _focused ? 1.4 : 1,
              ),
        boxShadow: (!widget.flat && _focused)
            ? [
                BoxShadow(
                  color: V2Colors.plasma.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        keyboardType: widget.keyboard,
        textInputAction: TextInputAction.done,
        onChanged: widget.onChanged,
        onTap: () => setState(() => _focused = true),
        onEditingComplete: _dismissKeyboard,
        onSubmitted: (_) => _dismissKeyboard(),
        onTapOutside: (_) => _dismissKeyboard(),
        style: V2FontStyles.inter(fontSize: 16, fontWeight: FontWeight.w500, color: V2Colors.ink),
        cursorColor: V2Colors.ink,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: V2Text.small().copyWith(
            color: _focused ? V2Colors.ink : V2Colors.fgSubtle,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.flat ? 14 : 18,
            vertical: widget.flat ? 14 : 18,
          ),
        ),
      ),
    );
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_focused && mounted) setState(() => _focused = false);
  }
}
class _GroupProductSuggestions extends StatefulWidget {
  const _GroupProductSuggestions({
    required this.matchLine,
    required this.evaluating,
    required this.onPick,
    this.title = 'Suggested for this group',
    this.compact = false,
  });

  final CalculatorSuggestedLine? matchLine;
  final bool evaluating;
  final void Function(CalculatorSuggestedLine line, CalculatorProductOption opt) onPick;
  final String title;
  final bool compact;

  @override
  State<_GroupProductSuggestions> createState() => _GroupProductSuggestionsState();
}

class _GroupProductSuggestionsState extends State<_GroupProductSuggestions> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchLine = widget.matchLine;
    final options = matchLine?.alternatives ?? const <CalculatorProductOption>[];
    final selectedId = matchLine?.productId;
    final compact = widget.compact;
    // Room for card + shadow + top badge — never clip the top.
    final listHeight = compact ? 236.0 : 268.0;

    return AnimatedSize(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: options.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(
                top: compact ? 10 : 8,
                bottom: compact ? 6 : 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact)
                    Container(height: 1, color: V2Colors.border.withValues(alpha: 0.55)),
                  SizedBox(height: compact ? 8 : 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: V2Text.small().copyWith(
                            color: V2Colors.fgSubtle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.evaluating)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          '${options.length} option${options.length == 1 ? '' : 's'}',
                          style: V2Text.micro().copyWith(color: V2Colors.fgFaint),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    compact
                        ? 'Swipe to browse · tap card to select'
                        : (CalculatorPricePrivacy.canSeePrices
                            ? 'Best match first · tap another to switch'
                            : 'Prices unlock after login · tap to select'),
                    style: V2Text.micro().copyWith(color: V2Colors.fgSubtle, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  // Mobile: vertical selectable rows (no clipped carousel).
                  if (compact)
                    Column(
                      children: [
                        for (var i = 0; i < options.length; i++) ...[
                          _SuggestedProductRow(
                            option: options[i],
                            selected: options[i].productId == selectedId,
                            isBestValue: i == 0,
                            onTap: () {
                              if (matchLine == null) return;
                              widget.onPick(matchLine, options[i]);
                            },
                            onQuickView: () {
                              showCalculatorSuggestedQuickView(
                                context,
                                option: options[i],
                                onSelect: () {
                                  if (matchLine == null) return;
                                  widget.onPick(matchLine, options[i]);
                                },
                              );
                            },
                          ),
                          if (i < options.length - 1) const SizedBox(height: 10),
                        ],
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (options.length > 2) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 88),
                            child: _SuggestScrollArrow(
                              icon: Icons.chevron_left_rounded,
                              onTap: () {
                                if (!_scroll.hasClients) return;
                                _scroll.animateTo(
                                  (_scroll.offset - 200).clamp(
                                    0.0,
                                    _scroll.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: SizedBox(
                            height: listHeight,
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                scrollbars: true,
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                  PointerDeviceKind.stylus,
                                },
                              ),
                              child: Listener(
                                onPointerSignal: (event) {
                                  if (event is! PointerScrollEvent) return;
                                  if (!_scroll.hasClients) return;
                                  final delta = event.scrollDelta.dy != 0
                                      ? event.scrollDelta.dy
                                      : event.scrollDelta.dx;
                                  final next = (_scroll.offset + delta).clamp(
                                    0.0,
                                    _scroll.position.maxScrollExtent,
                                  );
                                  _scroll.jumpTo(next);
                                },
                                child: ListView.separated(
                                  controller: _scroll,
                                  scrollDirection: Axis.horizontal,
                                  primary: false,
                                  clipBehavior: Clip.none,
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(4, 10, 8, 16),
                                  itemCount: options.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                                  itemBuilder: (ctx, i) {
                                    final opt = options[i];
                                    return _SuggestedProductCard(
                                      option: opt,
                                      selected: opt.productId == selectedId,
                                      isBestValue: i == 0,
                                      index: i,
                                      onTap: () {
                                        if (matchLine == null) return;
                                        widget.onPick(matchLine, opt);
                                      },
                                      onQuickView: () {
                                        showCalculatorSuggestedQuickView(
                                          context,
                                          option: opt,
                                          onSelect: () {
                                            if (matchLine == null) return;
                                            widget.onPick(matchLine, opt);
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (options.length > 2) ...[
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 88),
                            child: _SuggestScrollArrow(
                              icon: Icons.chevron_right_rounded,
                              onTap: () {
                                if (!_scroll.hasClients) return;
                                _scroll.animateTo(
                                  (_scroll.offset + 200).clamp(
                                    0.0,
                                    _scroll.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _SuggestScrollArrow extends StatelessWidget {
  const _SuggestScrollArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F0F2),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: V2Colors.ink),
        ),
      ),
    );
  }
}

/// Desktop / tablet horizontal product card — no lift (avoids top clip).
class _SuggestedProductCard extends StatefulWidget {
  const _SuggestedProductCard({
    required this.option,
    required this.selected,
    required this.isBestValue,
    required this.index,
    required this.onTap,
    required this.onQuickView,
  });

  final CalculatorProductOption option;
  final bool selected;
  final bool isBestValue;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onQuickView;

  @override
  State<_SuggestedProductCard> createState() => _SuggestedProductCardState();
}

class _SuggestedProductCardState extends State<_SuggestedProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final opt = widget.option;
    final selected = widget.selected;
    final hasImage = (opt.imageUrl ?? '').trim().isNotEmpty;
    final active = selected || _hover;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: active ? 1.02 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.white,
          elevation: active ? 6 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              width: selected ? 2 : 1,
              color: selected
                  ? V2Colors.ink
                  : V2Colors.border.withValues(alpha: _hover ? 0.9 : 0.55),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: SizedBox(
              width: 164,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 132,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: const Color(0xFFF5F5F7),
                            child: hasImage
                                ? Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Image.network(
                                      opt.imageUrl!.trim(),
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          color: V2Colors.fgFaint,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      color: V2Colors.fgFaint,
                                      size: 28,
                                    ),
                                  ),
                          ),
                        ),
                        if (widget.isBestValue)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: _CardChip(
                              label: 'Best',
                              filled: true,
                            ),
                          ),
                        if (selected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: V2Colors.ink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.95),
                            elevation: 1,
                            shadowColor: Colors.black26,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: widget.onQuickView,
                              child: const SizedBox(
                                width: 34,
                                height: 34,
                                child: Icon(
                                  Icons.visibility_outlined,
                                  size: 17,
                                  color: V2Colors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: V2Text.bodyEmph().copyWith(
                            fontSize: 13,
                            height: 1.25,
                            color: V2Colors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CalculatorPricePrivacy.format(opt.unitPrice),
                          style: V2Text.small().copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected ? V2Colors.ink : V2Colors.fgSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 320.ms, delay: (40 * widget.index).ms);
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({required this.label, this.filled = false});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? V2Colors.ink : Colors.white,
        borderRadius: BorderRadius.circular(980),
      ),
      child: Text(
        label,
        style: V2Text.micro().copyWith(
          color: filled ? Colors.white : V2Colors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Mobile Apple-style product row — full width, no top clip.
class _SuggestedProductRow extends StatelessWidget {
  const _SuggestedProductRow({
    required this.option,
    required this.selected,
    required this.isBestValue,
    required this.onTap,
    required this.onQuickView,
  });

  final CalculatorProductOption option;
  final bool selected;
  final bool isBestValue;
  final VoidCallback onTap;
  final VoidCallback onQuickView;

  @override
  Widget build(BuildContext context) {
    final hasImage = (option.imageUrl ?? '').trim().isNotEmpty;

    return Material(
      color: Colors.white,
      elevation: selected ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          width: selected ? 1.8 : 1,
          color: selected
              ? V2Colors.ink
              : V2Colors.border.withValues(alpha: 0.65),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.network(
                          option.imageUrl!.trim(),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.image_outlined,
                            color: V2Colors.fgFaint,
                          ),
                        ),
                      )
                    : const Icon(Icons.inventory_2_outlined, color: V2Colors.fgFaint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBestValue) ...[
                      Text(
                        'BEST MATCH',
                        style: V2Text.micro().copyWith(
                          color: V2Colors.fgSubtle,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      option.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: V2Text.bodyEmph().copyWith(
                        fontSize: 14,
                        height: 1.25,
                        color: V2Colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CalculatorPricePrivacy.format(option.unitPrice),
                      style: V2Text.small().copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? V2Colors.ink : V2Colors.fgSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onQuickView,
                tooltip: 'Quick view',
                icon: const Icon(Icons.visibility_outlined, size: 20),
                color: V2Colors.ink,
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: selected ? V2Colors.ink : V2Colors.fgFaint,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstimateLine extends StatelessWidget {
  const _EstimateLine({required this.line, required this.showPrices});
  final CalculatorSuggestedLine line;
  final bool showPrices;

  @override
  Widget build(BuildContext context) {
    final price = line.unitPrice;
    final fromAttrs = line.selectionKey != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFF5F5F7),
        border: Border.all(color: V2Colors.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          if ((line.alternatives.isNotEmpty) &&
              (line.alternatives
                      .where((a) => a.productId == line.productId)
                      .firstOrNull
                      ?.imageUrl ??
                  '')
                  .isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                line.alternatives
                    .firstWhere((a) => a.productId == line.productId)
                    .imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 48, height: 48),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.label, style: V2Text.bodyEmph().copyWith(fontSize: 14)),
                if ((line.sku ?? '').isNotEmpty)
                  Text(line.sku!, style: V2Text.micro().copyWith(color: V2Colors.fgFaint)),
                if ((line.matchGroupName ?? '').isNotEmpty)
                  Text(
                    line.matchGroupName!,
                    style: V2Text.micro().copyWith(color: V2Colors.fgSubtle),
                  )
                else if (fromAttrs)
                  Text(
                    'From your specs',
                    style: V2Text.micro().copyWith(color: V2Colors.fgSubtle),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (price != null) ...[
                Text(
                  showPrices ? formatINR(price) : CalculatorPricePrivacy.masked,
                  style: V2Text.micro().copyWith(color: V2Colors.fgSubtle),
                ),
                const SizedBox(height: 2),
                Text(
                  '× ${line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 1)}',
                  style: V2Text.small().copyWith(
                    fontWeight: FontWeight.w600,
                    color: V2Colors.fgSubtle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showPrices
                      ? formatINR(price * line.qty)
                      : CalculatorPricePrivacy.masked,
                  style: V2Text.bodyEmph().copyWith(fontSize: 14),
                ),
              ] else
                Text(
                  '× ${line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 1)}',
                  style: V2Text.bodyEmph(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryCta extends StatefulWidget {
  const _PrimaryCta({
    required this.label,
    required this.onTap,
    required this.enabled,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  @override
  State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _hover && widget.enabled ? 1.015 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: widget.enabled ? 1 : 0.45,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(980),
                color: V2Colors.ink,
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.label,
                        style: V2FontStyles.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryCta extends StatefulWidget {
  const _SecondaryCta({
    required this.label,
    required this.onTap,
    required this.enabled,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  @override
  State<_SecondaryCta> createState() => _SecondaryCtaState();
}

class _SecondaryCtaState extends State<_SecondaryCta> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _hover && widget.enabled ? 1.01 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: widget.enabled ? 1 : 0.45,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(980),
                color: Colors.white,
                border: Border.all(color: V2Colors.ink.withValues(alpha: 0.18)),
              ),
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: V2Colors.ink),
                      )
                    : Text(
                        widget.label,
                        style: V2FontStyles.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: V2Colors.ink,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}