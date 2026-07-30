import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../web_public/pages/shop/widgets/store_atoms.dart';
import '../../web_public/v2/v2_colors.dart';
import '../../web_public/v2/v2_font_styles.dart';
import '../../web_public/v2/v2_text.dart';
import '../data/quotation_repository.dart';
import '../domain/calculator_models.dart';
import '../services/quotation_brand_context.dart';
import '../services/quotation_order_helper.dart';
import '../services/quotation_pdf_service.dart';

/// Compact glass popup — all fields + actions visible without scrolling.
Future<void> showQuotationSavePopup({
  required BuildContext context,
  required CalculatorResult result,
  required Future<String?> Function({
    String? customerName,
    String? customerAddress,
    String? customerPhone,
  }) onSave,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 480),
    pageBuilder: (ctx, anim, secondary) {
      return QuotationSavePopup(result: result, onSave: onSave);
    },
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class QuotationSavePopup extends StatefulWidget {
  const QuotationSavePopup({
    super.key,
    required this.result,
    required this.onSave,
  });

  final CalculatorResult result;
  final Future<String?> Function({
    String? customerName,
    String? customerAddress,
    String? customerPhone,
  }) onSave;

  @override
  State<QuotationSavePopup> createState() => _QuotationSavePopupState();
}

class _QuotationSavePopupState extends State<QuotationSavePopup>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _orderHelper = QuotationOrderHelper();

  bool _saving = false;
  bool _pdfBusy = false;
  bool _ordering = false;
  bool _savedToast = false;
  bool _toastOpaque = false;
  String? _quotationId;
  List<QuotationLine>? _savedLines;
  String? _error;
  Timer? _toastTimer;
  late final AnimationController _pulseCtrl;

  double get _total {
    var t = 0.0;
    for (final l in widget.result.suggestedLines) {
      t += (l.unitPrice ?? 0) * l.qty;
    }
    return t;
  }

  int get _itemCount => widget.result.suggestedLines.length;

  bool get _saved => _quotationId != null;

  String get _shortRef {
    final id = _quotationId ?? '';
    if (id.length > 8) return id.substring(0, 8).toUpperCase();
    return id.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    // Prefetch PDF fonts/logo + brand so Print opens fast.
    QuotationPdfService.warmUp();
    QuotationBrandContext.resolve(context);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _pulseCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  QuotationPreparedFor get _preparedFor => QuotationPreparedFor(
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );

  void _flashSavedToast() {
    _toastTimer?.cancel();
    setState(() {
      _savedToast = true;
      _toastOpaque = true;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _toastOpaque = false);
      _toastTimer = Timer(const Duration(milliseconds: 360), () {
        if (mounted) setState(() => _savedToast = false);
      });
    });
  }

  Future<bool> _save({bool silent = false}) async {
    if (_saved) return true;
    if (_saving) return false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final prepared = _preparedFor;
      final id = await widget.onSave(
        customerName: prepared.name,
        customerAddress: prepared.address,
        customerPhone: prepared.phone,
      );
      if (!mounted) return false;
      if (id == null) throw StateError('Could not save quotation');
      // For PDF path, use local lines immediately (skip extra DB round-trip).
      final lines = silent
          ? _linesFromResult()
          : await QuotationRepository().listLines(id);
      setState(() {
        _quotationId = id;
        _savedLines = lines;
        _saving = false;
      });
      if (!silent) _flashSavedToast();
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _error = '$e';
      });
      return false;
    }
  }

  List<QuotationLine> _linesFromResult() {
    final out = <QuotationLine>[];
    var i = 0;
    for (final l in widget.result.suggestedLines) {
      final unit = l.unitPrice ?? 0;
      out.add(
        QuotationLine(
          id: 'local-${i++}',
          label: l.label,
          qty: l.qty,
          unitPrice: unit,
          lineTotal: unit * l.qty,
          productId: l.productId,
          sku: l.sku,
        ),
      );
    }
    for (final f in widget.result.formulas) {
      out.add(
        QuotationLine(
          id: 'local-${i++}',
          label: '${f.key}: ${f.value.toStringAsFixed(0)}',
          qty: f.value,
          unitPrice: 0,
          lineTotal: 0,
        ),
      );
    }
    return out;
  }

  Future<void> _printPdf() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      // Warm assets + save (if needed) in parallel — brand is non-blocking.
      final warm = QuotationPdfService.warmUp();
      final saveOk = _saved ? Future.value(true) : _save(silent: true);
      await Future.wait([warm, saveOk]);
      if (!mounted) return;
      if (!_saved && _quotationId == null) return;

      final brand = QuotationBrandContext.resolveFast(context);
      final lines = _savedLines ?? _linesFromResult();
      await QuotationPdfService.shareQuotation(
        _quotationId!,
        lines,
        brand: brand,
        preparedFor: _preparedFor,
        totalAmount: _total,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _orderNow() async {
    if (_ordering) return;
    setState(() => _ordering = true);
    try {
      final added = await _orderHelper.addSuggestedLinesToCart(widget.result.suggestedLines);
      if (!mounted) return;
      setState(() => _ordering = false);
      if (added == 0) {
        setState(() => _error = 'Products unavailable right now.');
        return;
      }
      Navigator.of(context).pop();
      if (mounted) context.go(RouteNames.publicCart);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ordering = false;
        _error = '$e';
      });
    }
  }

  void _viewAll() {
    Navigator.of(context).pop();
    context.push(RouteNames.calculatorQuotations);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width >= 560 ? 520.0 : size.width.clamp(340.0, 520.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -28,
                  left: 48,
                  right: 48,
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, _) {
                      final t = 0.14 + (_pulseCtrl.value * 0.1);
                      return Container(
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(80),
                          boxShadow: [
                            BoxShadow(
                              color: V2Colors.ember.withValues(alpha: t),
                              blurRadius: 70,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: V2Colors.plasma.withValues(alpha: t * 0.5),
                              blurRadius: 50,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.92),
                            const Color(0xFFFFF8F2).withValues(alpha: 0.88),
                            const Color(0xFFF3F0FF).withValues(alpha: 0.84),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.78),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 48,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.95),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 20, 22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _header(),
                                const SizedBox(height: 16),
                                _totalChip(),
                                const SizedBox(height: 18),
                                _preparedForFields(),
                                if (_error != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    _error!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: V2Text.small().copyWith(color: Colors.red.shade700),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                _actions(),
                              ],
                            ),
                          ),
                          if (_savedToast) _savedToastOverlay(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              colors: [V2Colors.ember, V2Colors.plasma],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: V2Colors.ember.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.request_quote_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save quotation',
                style: V2FontStyles.inter(fontSize: 19, fontWeight: FontWeight.w800, color: V2Colors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                'Add customer details, then save or print',
                style: V2Text.small().copyWith(color: V2Colors.fgSubtle),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white.withValues(alpha: 0.6),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(Icons.close_rounded, size: 20, color: V2Colors.fgSubtle),
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalChip() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.72),
                const Color(0xFFFFF1E8).withValues(alpha: 0.55),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: V2Colors.ember.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED TOTAL',
                      style: V2Text.micro().copyWith(
                        color: V2Colors.fgSubtle,
                        fontSize: 11,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _total),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        formatINR(value),
                        style: V2FontStyles.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: V2Colors.ink,
                          letterSpacing: -1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(980),
                      color: V2Colors.ember.withValues(alpha: 0.12),
                      border: Border.all(color: V2Colors.ember.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      '$_itemCount items',
                      style: V2Text.small().copyWith(
                        color: V2Colors.ember,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_saved && _shortRef.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'QT-$_shortRef',
                      style: V2Text.small().copyWith(
                        color: V2Colors.plasma,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preparedForFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PREPARED FOR',
          style: V2Text.micro().copyWith(
            color: V2Colors.fgSubtle,
            fontSize: 11,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GlassField(
                controller: _nameCtrl,
                hint: 'Name',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlassField(
                controller: _phoneCtrl,
                hint: 'Mobile number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GlassField(
          controller: _addressCtrl,
          hint: 'Address',
          icon: Icons.location_on_outlined,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _actions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: _saved ? 'Saved' : 'Save to account',
                loading: _saving,
                filled: true,
                gradient: _saved
                    ? const [V2Colors.aurora, Color(0xFF2DD4BF)]
                    : const [V2Colors.ember, Color(0xFFFF8A4C)],
                icon: _saved ? Icons.check_rounded : Icons.bookmark_add_outlined,
                onTap: () {
                  if (!_saved && !_saving) _save();
                },
                enabled: !_saving,
                lockedLook: _saved,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                label: 'Print / Save PDF',
                loading: _pdfBusy,
                filled: true,
                gradient: const [V2Colors.navy, V2Colors.plasma],
                icon: Icons.picture_as_pdf_outlined,
                onTap: _printPdf,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Order now',
                loading: _ordering,
                filled: false,
                icon: Icons.shopping_bag_outlined,
                onTap: _orderNow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                label: 'View all',
                filled: false,
                icon: Icons.folder_open_outlined,
                onTap: _viewAll,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _savedToastOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _toastOpaque ? 1 : 0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
            child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                color: Colors.white.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutBack,
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Colors.white.withValues(alpha: 0.94),
                      border: Border.all(color: V2Colors.aurora.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: V2Colors.aurora.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [V2Colors.aurora, V2Colors.plasma],
                            ),
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Quotation saved',
                          style: V2FontStyles.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: V2Colors.ink,
                          ),
                        ),
                        if (_shortRef.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'QT-$_shortRef',
                            style: V2Text.small().copyWith(
                              color: V2Colors.plasma,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w600, color: V2Colors.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: V2Text.small().copyWith(color: V2Colors.fgFaint),
            prefixIcon: Icon(icon, size: 20, color: V2Colors.fgSubtle),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 48),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.62),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: V2Colors.ember, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.label,
    required this.onTap,
    required this.filled,
    this.loading = false,
    this.gradient,
    this.icon,
    this.enabled = true,
    this.lockedLook = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool loading;
  final bool enabled;
  final bool lockedLook;
  final List<Color>? gradient;
  final IconData? icon;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;
    final showGrad = widget.filled && widget.gradient != null && (active || widget.lockedLook);

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(980),
            gradient: showGrad ? LinearGradient(colors: widget.gradient!) : null,
            color: widget.filled
                ? (showGrad ? null : V2Colors.border.withValues(alpha: 0.45))
                : Colors.white.withValues(alpha: 0.62),
            border: widget.filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.2),
            boxShadow: showGrad
                ? [
                    BoxShadow(
                      color: (widget.gradient?.first ?? V2Colors.ember).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.filled ? Colors.white : V2Colors.ink,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 18,
                          color: widget.filled ? Colors.white : V2Colors.ink,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: V2FontStyles.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.filled ? Colors.white : V2Colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
