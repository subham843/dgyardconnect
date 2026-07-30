import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Aadhaar number input with slot animation: _ _ _ _ - _ _ _ _ - _ _ _ _
/// Same style as phone number input on login screen.
class AadhaarSlotsInput extends StatefulWidget {
  const AadhaarSlotsInput({
    super.key,
    required this.controller,
    this.validator,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;

  @override
  State<AadhaarSlotsInput> createState() => _AadhaarSlotsInputState();
}

class _AadhaarSlotsInputState extends State<AadhaarSlotsInput> {
  final _focusNode = FocusNode();
  static const int _digitCount = 12;
  static const double _gap = 6.0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aadhaar number',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Opacity(
                  opacity: 0,
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: _digitCount,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_digitCount),
                    ],
                    validator: widget.validator,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    final text = widget.controller.text.replaceAll(RegExp(r'\D'), '').padRight(_digitCount).substring(0, _digitCount);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ...List.generate(4, (i) => _buildSlot(text.length > i ? text[i] : ' ', i)),
                        _buildDash(),
                        ...List.generate(4, (i) => _buildSlot(text.length > i + 4 ? text[i + 4] : ' ', i + 4)),
                        _buildDash(),
                        ...List.generate(4, (i) => _buildSlot(text.length > i + 8 ? text[i + 8] : ' ', i + 8)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDash() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Text(
            '–',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(String char, int index) {
    final isFilled = char != ' ';
    return Padding(
      padding: EdgeInsets.only(right: index < 11 ? _gap : 0),
      child: _AadhaarDigitSlot(
        key: ValueKey('aadhaar-$index-$char'),
        digit: isFilled ? char : 'X',
        isFilled: isFilled,
      ),
    );
  }
}

class _AadhaarDigitSlot extends StatefulWidget {
  const _AadhaarDigitSlot({
    super.key,
    required this.digit,
    required this.isFilled,
  });

  final String digit;
  final bool isFilled;

  @override
  State<_AadhaarDigitSlot> createState() => _AadhaarDigitSlotState();
}

class _AadhaarDigitSlotState extends State<_AadhaarDigitSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    if (widget.isFilled) _controller.forward();
  }

  @override
  void didUpdateWidget(_AadhaarDigitSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFilled && !oldWidget.isFilled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 28,
          height: 44,
          child: Center(
            child: widget.isFilled
                ? ScaleTransition(
                    scale: _scale,
                    child: FadeTransition(
                      opacity: _opacity,
                      child: Text(
                        widget.digit,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  )
                : Text(
                    'X',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
