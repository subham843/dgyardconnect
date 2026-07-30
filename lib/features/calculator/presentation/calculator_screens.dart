import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../customer/account/customer_account_shell.dart';
import '../data/calculator_repository.dart';
import '../data/quotation_repository.dart';
import '../domain/calculator_engine.dart';
import '../domain/calculator_models.dart';
import '../services/quotation_brand_context.dart';
import '../services/quotation_order_helper.dart';
import '../services/quotation_pdf_service.dart';
import '../../web_public/pages/shop/widgets/store_atoms.dart';
import '../../web_public/v2/v2_animate_export.dart';
import '../../web_public/v2/v2_colors.dart';
import '../../web_public/v2/v2_font_styles.dart';
import '../../web_public/v2/v2_text.dart';

class CalculatorHomeScreen extends StatefulWidget {
  const CalculatorHomeScreen({super.key});

  @override
  State<CalculatorHomeScreen> createState() => _CalculatorHomeScreenState();
}

class _CalculatorHomeScreenState extends State<CalculatorHomeScreen> {
  final _repo = CalculatorRepository();
  List<CalculatorFamily> _families = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _families = await _repo.listFamilies();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CCTV Calculator'),
        actions: [
          IconButton(icon: const Icon(Icons.request_quote_outlined), onPressed: () => context.push(RouteNames.calculatorQuotations)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _families.length,
              itemBuilder: (_, i) {
                final f = _families[i];
                return ListTile(
                  title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(f.description ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final templates = await _repo.listTemplates(familyId: f.id, publishedOnly: true);
                    if (!context.mounted) return;
                    if (templates.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No published template')));
                      return;
                    }
                    context.push(RouteNames.calculatorTemplate(templates.first.id));
                  },
                );
              },
            ),
    );
  }
}

class CalculatorTemplateScreen extends StatefulWidget {
  const CalculatorTemplateScreen({super.key, required this.templateId});

  final String templateId;

  @override
  State<CalculatorTemplateScreen> createState() => _CalculatorTemplateScreenState();
}

class _CalculatorTemplateScreenState extends State<CalculatorTemplateScreen> {
  final _repo = CalculatorRepository();
  final _engine = CalculatorEngine();
  final _quotationRepo = QuotationRepository();
  List<CalculatorQuestion> _questions = [];
  List<CalculatorRule> _rules = [];
  final _answers = <String, dynamic>{};
  CalculatorResult? _result;
  bool _loading = true;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _questions = await _repo.listQuestions(widget.templateId);
    _rules = await _repo.listRules(widget.templateId);
    for (final q in _questions) {
      _answers.putIfAbsent(q.questionKey, () => q.uiType == 'number' ? 0 : '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _evaluate() async {
    setState(() => _running = true);
    _result = await _engine.evaluate(questions: _questions, rules: _rules, answers: _answers);
    if (mounted) setState(() => _running = false);
  }

  Future<void> _saveQuotation() async {
    if (_result == null) return;
    final sessionId = await _repo.createSession(templateId: widget.templateId, answers: _answers, result: {'ok': true});
    final qid = await _quotationRepo.createFromCalculatorResult(
      sessionId: sessionId,
      templateId: widget.templateId,
      result: _result!,
    );
    if (!mounted) return;
    if (qid != null) {
      context.push(RouteNames.calculatorQuotationDetail(qid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final q in _questions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: q.uiType == 'select' && (q.options?.isNotEmpty ?? false)
                        ? DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: q.label, border: const OutlineInputBorder()),
                            items: [for (final o in q.options!) DropdownMenuItem(value: o, child: Text(o))],
                            onChanged: (v) => setState(() => _answers[q.questionKey] = v),
                          )
                        : TextFormField(
                            decoration: InputDecoration(labelText: q.label, border: const OutlineInputBorder()),
                            keyboardType: q.uiType == 'number' ? TextInputType.number : TextInputType.text,
                            onChanged: (v) => _answers[q.questionKey] = q.uiType == 'number' ? (int.tryParse(v) ?? double.tryParse(v) ?? 0) : v,
                          ),
                  ),
                FilledButton(
                  onPressed: _running ? null : _evaluate,
                  child: _running ? const CircularProgressIndicator() : const Text('Calculate'),
                ),
                if (r != null) ...[
                  const SizedBox(height: 16),
                  const Text('Suggestions', style: TextStyle(fontWeight: FontWeight.w800)),
                  for (final line in r.suggestedLines)
                    ListTile(title: Text(line.label), trailing: Text('x${line.qty}')),
                  const Text('Quantities', style: TextStyle(fontWeight: FontWeight.w800)),
                  for (final f in r.formulas) ListTile(title: Text(f.key), trailing: Text(f.value.toStringAsFixed(0))),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _saveQuotation, child: const Text('Save quotation')),
                ],
              ],
            ),
    );
  }
}

/// Embedded panel for technician dashboard (replaces stub).
class CalculatorPanel extends StatelessWidget {
  const CalculatorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('CCTV & security calculator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('HD CCTV, IP CCTV, hybrid systems — dynamic BOM and quotations.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push(RouteNames.calculatorHome),
            icon: const Icon(Icons.calculate_rounded),
            label: const Text('Open calculator'),
          ),
        ],
      ),
    );
  }
}

class CalculatorQuotationsScreen extends StatefulWidget {
  const CalculatorQuotationsScreen({super.key});

  @override
  State<CalculatorQuotationsScreen> createState() => _CalculatorQuotationsScreenState();
}

class _CalculatorQuotationsScreenState extends State<CalculatorQuotationsScreen> {
  final _repo = QuotationRepository();
  List<Quotation> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await _repo.listMyQuotations();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _shortRef(String id) =>
      id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return CustomerAccountShell(
      activeTab: CustomerAccountTab.calculator,
      backFallback: RouteNames.accountHome,
      title: 'Saved quotations',
      subtitle: 'Download PDF, order again, or open in calculator',
      actions: [
        TextButton(
          onPressed: () => context.go(RouteNames.publicCalculatorList),
          child: const Text('New quote'),
        ),
      ],
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : _items.isEmpty
              ? AccountEmptyState(
                  icon: Icons.request_quote_outlined,
                  title: 'No saved quotations yet',
                  message: 'Build an estimate in the price calculator and save it here.',
                  actionLabel: 'Open calculator',
                  onAction: () => context.go(RouteNames.publicCalculatorList),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final q = _items[i];
                      return _QuotationCard(
                        ref: 'QT-${_shortRef(q.id)}',
                        meta: [
                          if (q.preparedFor.displayLabel != null) q.preparedFor.displayLabel!,
                          if (q.createdAt != null) _fmtDate(q.createdAt),
                          q.status,
                        ].join(' · '),
                        total: formatINR(q.totalAmount),
                        onTap: () => context.push(RouteNames.calculatorQuotationDetail(q.id)),
                      ).animate(delay: (40 * i).ms).fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0);
                    },
                  ),
                ),
    );
  }
}

class _QuotationCard extends StatefulWidget {
  const _QuotationCard({
    required this.ref,
    required this.meta,
    required this.total,
    required this.onTap,
  });

  final String ref;
  final String meta;
  final String total;
  final VoidCallback onTap;

  @override
  State<_QuotationCard> createState() => _QuotationCardState();
}

class _QuotationCardState extends State<_QuotationCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.01 : 1,
          duration: const Duration(milliseconds: 180),
          child: AccountGlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: V2Colors.ember.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.request_quote_rounded, color: V2Colors.ember),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.ref, style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(widget.meta, style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                    ],
                  ),
                ),
                Text(widget.total, style: V2FontStyles.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: V2Colors.fgFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CalculatorQuotationDetailScreen extends StatefulWidget {
  const CalculatorQuotationDetailScreen({super.key, required this.quotationId});

  final String quotationId;

  @override
  State<CalculatorQuotationDetailScreen> createState() => _CalculatorQuotationDetailScreenState();
}

class _CalculatorQuotationDetailScreenState extends State<CalculatorQuotationDetailScreen> {
  final _repo = QuotationRepository();
  final _orderHelper = QuotationOrderHelper();
  Quotation? _quotation;
  List<QuotationLine> _lines = [];
  bool _loading = true;
  bool _pdfBusy = false;
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getById(widget.quotationId),
        _repo.listLines(widget.quotationId),
      ]);
      _quotation = results[0] as Quotation?;
      _lines = results[1] as List<QuotationLine>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_pdfBusy || _lines.isEmpty) return;
    setState(() => _pdfBusy = true);
    try {
      await QuotationPdfService.warmUp();
      final brand = QuotationBrandContext.resolveFast(context);
      await QuotationPdfService.shareQuotation(
        widget.quotationId,
        _lines,
        brand: brand,
        preparedFor: _quotation?.preparedFor,
        totalAmount: _quotation?.totalAmount,
        createdAt: _quotation?.createdAt,
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PDF failed'),
          content: Text('$e'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _orderNow() async {
    if (_ordering) return;
    final productLines = _lines.where((l) => (l.productId ?? '').isNotEmpty).toList();
    if (productLines.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nothing to order'),
          content: const Text('This quotation has no catalog products to add to cart.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    setState(() => _ordering = true);
    try {
      final added = await _orderHelper.addQuotationLinesToCart(productLines);
      if (!mounted) return;
      setState(() => _ordering = false);
      if (added == 0) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Could not add products'),
            content: const Text('Products from this quotation are unavailable right now.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
        return;
      }
      final goCart = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Added to cart'),
          content: Text('$added product${added == 1 ? '' : 's'} added. Continue to cart to place your order?'),
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

  String _shortRef(String id) =>
      id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final total = _quotation?.totalAmount ?? _lines.fold<double>(0, (s, l) => s + l.lineTotal);
    final productLines = _lines.where((l) => l.unitPrice > 0 || (l.productId ?? '').isNotEmpty).toList();
    final otherLines = _lines.where((l) => l.unitPrice <= 0 && (l.productId == null || l.productId!.isEmpty)).toList();

    return CustomerAccountShell(
      activeTab: CustomerAccountTab.calculator,
      backFallback: RouteNames.calculatorQuotations,
      title: _quotation != null ? 'QT-${_shortRef(_quotation!.id)}' : 'Quotation',
      subtitle: 'Review line items, download PDF, or order',
      actions: [
        IconButton(
          tooltip: 'Download PDF',
          onPressed: _pdfBusy || _loading ? null : _downloadPdf,
          icon: _pdfBusy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined),
        ),
      ],
      stickyBottom: _loading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pdfBusy ? null : _downloadPdf,
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Print PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: V2Colors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _ordering ? null : _orderNow,
                        style: FilledButton.styleFrom(
                          backgroundColor: V2Colors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980)),
                        ),
                        child: _ordering
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Order now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      child: _loading
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccountGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated total', style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                      const SizedBox(height: 6),
                      Text(formatINR(total), style: V2FontStyles.inter(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      if (_quotation?.preparedFor.hasAny == true) ...[
                        const SizedBox(height: 12),
                        Text('Prepared for', style: V2Text.micro().copyWith(color: V2Colors.fgFaint, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        if ((_quotation!.customerName ?? '').trim().isNotEmpty)
                          Text(_quotation!.customerName!.trim(), style: V2FontStyles.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                        if ((_quotation!.customerAddress ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_quotation!.customerAddress!.trim(), style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                        ],
                        if ((_quotation!.customerPhone ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_quotation!.customerPhone!.trim(), style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                        ],
                      ],
                    ],
                  ),
                ).animate().fadeIn(duration: 360.ms).slideY(begin: 0.06, end: 0),
                const SizedBox(height: 14),
                AccountGlassCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Line items', style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      for (final l in productLines.isNotEmpty ? productLines : _lines) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.label, style: V2FontStyles.inter(fontWeight: FontWeight.w600, height: 1.3)),
                                    if ((l.sku ?? '').isNotEmpty)
                                      Text('SKU ${l.sku}', style: V2Text.micro().copyWith(color: V2Colors.fgFaint)),
                                    Text(
                                      'Qty ${l.qty.toStringAsFixed(l.qty == l.qty.roundToDouble() ? 0 : 1)}'
                                      '${l.unitPrice > 0 ? ' × ${formatINR(l.unitPrice)}' : ''}',
                                      style: V2Text.micro().copyWith(color: V2Colors.fgSubtle),
                                    ),
                                  ],
                                ),
                              ),
                              Text(l.lineTotal > 0 ? formatINR(l.lineTotal) : '—', style: V2FontStyles.inter(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
                      ],
                      if (otherLines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Calculated quantities', style: V2Text.small().copyWith(fontWeight: FontWeight.w700, color: V2Colors.fgSubtle)),
                        for (final l in otherLines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(l.label, style: V2Text.small().copyWith(color: V2Colors.fgMuted)),
                          ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05, end: 0),
              ],
            ),
    );
  }
}
