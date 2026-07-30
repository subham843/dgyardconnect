// Morphing Search Bar — animated saffron pill with gradient border morph.

import 'package:flutter/material.dart';
import '../../v2/v2_font_styles.dart';

import '../v2_colors.dart';
import '../v2_tokens.dart';

double _morphLerp(double a, double b, double t) => a + (b - a) * t;

Color _morphColor(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

class V2MorphSearchBar extends StatefulWidget {
  const V2MorphSearchBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.compact = false,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool compact;

  @override
  State<V2MorphSearchBar> createState() => _V2MorphSearchBarState();
}

class _V2MorphSearchBarState extends State<V2MorphSearchBar>
    with TickerProviderStateMixin {
  final _focusNode = FocusNode();
  bool _hover = false;
  bool _btnHover = false;

  late final AnimationController _morphCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _morph;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);

    _morphCtrl = AnimationController(vsync: this, duration: V2.dMed);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);

    _morph = CurvedAnimation(parent: _morphCtrl, curve: V2.eOut);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _morphCtrl.forward();
    } else if (!_hover) {
      _morphCtrl.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _morphCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  bool get _active => _hover || _focusNode.hasFocus;

  void _setHover(bool v) {
    if (_hover == v) return;
    setState(() => _hover = v);
    if (v || _focusNode.hasFocus) {
      _morphCtrl.forward();
    } else {
      _morphCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.compact ? 36.0 : 40.0;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: AnimatedBuilder(
          animation: Listenable.merge([_morph, _pulse]),
          builder: (context, _) {
            final t = _morph.value;
            final radius = _morphLerp(22, 28, t);
            final lift = _morphLerp(0, -2, t);
            final scale = _morphLerp(1, 1.02, t);
            final glowAlpha = _morphLerp(0.08, 0.28, t);
            final borderPad = _morphLerp(1.6, 2.4, t);
            final gradTurn = _morphLerp(0, 0.25, t) + _pulse.value * 0.08;

            return Transform.translate(
              offset: Offset(0, lift),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius + 4),
                    boxShadow: [
                      BoxShadow(
                        color: V2Colors.premiumOrange.withValues(alpha: glowAlpha),
                        blurRadius: _morphLerp(8, 22, t),
                        spreadRadius: _morphLerp(0, 1, t),
                        offset: Offset(0, _morphLerp(2, 6, t)),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: EdgeInsets.all(borderPad),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius + 2),
                      gradient: LinearGradient(
                        begin: Alignment(-1 + gradTurn, -1),
                        end: Alignment(1 - gradTurn, 1),
                        colors: [
                          _morphColor(const Color(0xFFFDE68A), V2Colors.premiumOrange, t),
                          V2Colors.premiumOrange,
                          _morphColor(
                            V2Colors.premiumOrangeDeep,
                            const Color(0xFFFBBF24),
                            _pulse.value * 0.3,
                          ),
                        ],
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _morphColor(const Color(0xFFFFFFFF), const Color(0xFFFFFBF5), t),
                        borderRadius: BorderRadius.circular(radius),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(widget.compact ? 12 : 14, 0, 5, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _MorphSearchIcon(active: _active, t: t, compact: widget.compact),
                            SizedBox(width: widget.compact ? 8 : 10),
                            Expanded(child: _buildField(h)),
                            const SizedBox(width: 6),
                            _MorphGoButton(
                              t: t,
                              hover: _btnHover,
                              compact: widget.compact,
                              onHover: (v) => setState(() => _btnHover = v),
                              onTap: widget.onSubmit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildField(double h) {
    return SizedBox(
      height: h,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onSubmitted: (_) => widget.onSubmit(),
        textAlignVertical: TextAlignVertical.center,
        cursorColor: V2Colors.premiumOrange,
        cursorWidth: 2,
        style: V2FontStyles.inter(
          fontSize: widget.compact ? 12.5 : 13.5,
          fontWeight: FontWeight.w500,
          color: V2Colors.inkSaaS,
        ),
        decoration: InputDecoration(
          hintText: widget.compact
              ? 'Search products…'
              : 'Search CCTV, Computers & more…',
          hintStyle: V2FontStyles.inter(
            fontSize: widget.compact ? 12 : 13,
            color: const Color(0xFF57534E),
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
      ),
    );
  }
}

class _MorphSearchIcon extends StatelessWidget {
  const _MorphSearchIcon({
    required this.active,
    required this.t,
    required this.compact,
  });

  final bool active;
  final double t;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 30.0;
    final iconSize = compact ? 15.0 : 16.0;

    return Transform.rotate(
      angle: _morphLerp(0, -0.12, t),
      child: AnimatedContainer(
        duration: V2.dFast,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? [V2Colors.premiumOrange, V2Colors.premiumOrangeDeep]
                : [
                    V2Colors.premiumOrange.withValues(alpha: 0.15),
                    V2Colors.premiumOrange.withValues(alpha: 0.08),
                  ],
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: V2Colors.premiumOrange.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.search_rounded,
          size: iconSize,
          color: active ? Colors.white : V2Colors.premiumOrangeDeep,
        ),
      ),
    );
  }
}

class _MorphGoButton extends StatelessWidget {
  const _MorphGoButton({
    required this.t,
    required this.hover,
    required this.compact,
    required this.onHover,
    required this.onTap,
  });

  final double t;
  final bool hover;
  final bool compact;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 28.0 : 30.0;
    final w = _morphLerp(h, h + 18, hover ? 1 : t * 0.6);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: V2.dFast,
          curve: V2.eOut,
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(h / 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: hover
                  ? [V2Colors.premiumOrangeDeep, const Color(0xFFB45309)]
                  : [V2Colors.premiumOrange, V2Colors.premiumOrangeDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: V2Colors.premiumOrange.withValues(alpha: hover ? 0.5 : 0.32),
                blurRadius: hover ? 12 : 8,
                offset: Offset(0, hover ? 4 : 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (w > h + 4)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    'Go',
                    style: V2FontStyles.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(_morphLerp(0, 2, t), 0),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: h * 0.48,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
