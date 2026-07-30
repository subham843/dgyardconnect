import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Soft Apple-like tokens for Calculator admin pages.
abstract final class CalcAdminUi {
  static const ink = Color(0xFF1D1D1F);
  static const subtle = Color(0xFF6E6E73);
  static const faint = Color(0xFF8E8E93);
  static const softBg = Color(0xFFF5F5F7);
  static const card = Colors.white;
  static const border = Color(0xFFE5E5EA);
  static const accent = Color(0xFF0071E3);

  static TextStyle get largeTitle => const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ink,
        height: 1.15,
      );

  static TextStyle get sectionTitle => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: ink,
      );

  static TextStyle get body => const TextStyle(
        fontSize: 14,
        height: 1.4,
        color: subtle,
      );

  static BoxDecoration get cardDeco => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      );

  static BoxDecoration get softCardDeco => BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.85)),
      );
}

extension CalcAdminAnimateX on Widget {
  Widget calcPageEnter({int delayMs = 0}) => animate()
      .fadeIn(duration: 380.ms, delay: delayMs.ms, curve: Curves.easeOutCubic)
      .slideY(
        begin: 0.03,
        end: 0,
        duration: 420.ms,
        delay: delayMs.ms,
        curve: Curves.easeOutCubic,
      );

  Widget calcStagger(int index) => calcPageEnter(delayMs: 40 * index);
}

/// Empty state when no family is selected.
class CalcAdminPickFamilyEmpty extends StatelessWidget {
  const CalcAdminPickFamilyEmpty({
    super.key,
    required this.onChooseFamily,
    this.message = 'Choose a family to continue',
    this.families = const [],
    this.onSelectFamily,
  });

  final VoidCallback onChooseFamily;
  final String message;
  final List<CalculatorFamilyLite> families;
  final ValueChanged<String>? onSelectFamily;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: CalcAdminUi.softBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                size: 32,
                color: CalcAdminUi.subtle,
              ),
            ),
            const SizedBox(height: 20),
            Text(message, style: CalcAdminUi.sectionTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              families.isNotEmpty
                  ? 'Pick a family below, or open Families to create one.'
                  : 'Open Families, select one, then come back here.',
              style: CalcAdminUi.body,
              textAlign: TextAlign.center,
            ),
            if (families.isNotEmpty && onSelectFamily != null) ...[
              const SizedBox(height: 16),
              CalcAdminFamilySwitcher(
                families: families,
                selectedId: null,
                onSelect: onSelectFamily!,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: CalcAdminUi.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onChooseFamily,
              child: const Text('Go to Families'),
            ),
          ],
        ),
      ),
    ).calcPageEnter();
  }
}

/// Compact family switcher chip row for Options / Rules headers.
class CalcAdminFamilySwitcher extends StatelessWidget {
  const CalcAdminFamilySwitcher({
    super.key,
    required this.families,
    required this.selectedId,
    required this.onSelect,
  });

  final List<CalculatorFamilyLite> families;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (families.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in families) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.name),
                selected: f.id == selectedId,
                selectedColor: CalcAdminUi.ink,
                labelStyle: TextStyle(
                  color: f.id == selectedId ? Colors.white : CalcAdminUi.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                onSelected: (_) => onSelect(f.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CalculatorFamilyLite {
  const CalculatorFamilyLite({required this.id, required this.name});
  final String id;
  final String name;
}
